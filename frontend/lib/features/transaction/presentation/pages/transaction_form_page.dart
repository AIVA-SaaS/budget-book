import 'dart:async';

import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/dialog_helpers.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/core/services/couple_prefs.dart';
import 'package:flutter/services.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';
import 'package:budget_book/core/widgets/category_group_selector_sheet.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/payment_method_form_sheet.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/widgets/pocket_form_sheet.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';

class TransactionFormPage extends StatefulWidget {
  /// If editing, pass the transaction ID (from URL path parameter).
  /// The page will load the transaction data from the BLoC/repository.
  final String? transactionId;

  /// Optional initial transaction type ('EXPENSE' or 'INCOME').
  /// Used when navigating from dashboard quick actions.
  final String? initialType;

  /// Optional initial date for the transaction.
  /// Used when navigating from a date header in the transaction list.
  final DateTime? initialDate;

  const TransactionFormPage({
    super.key,
    this.transactionId,
    this.initialType,
    this.initialDate,
  });

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  String _amountHint = '';
  late final TextEditingController _descriptionController;
  late final TextEditingController _memoController;
  late String _selectedType;
  String? _selectedCategoryId;
  String? _selectedCategoryDisplayName;
  String? _selectedPaymentMethodId;
  String? _selectedPocketId;
  late DateTime _selectedDate;
  bool _isLoadingTransaction = false;
  bool _isSubmitting = false;
  bool _continueMode = false;
  bool _keepSameItems = false;
  String? _categoryError;
  String? _paymentMethodError;

  // Suggestion chips state
  List<String> _suggestions = [];
  Timer? _debounceTimer;

  // FocusNodes for keyboard navigation on selector fields
  final FocusNode _categoryFocusNode = FocusNode();
  final FocusNode _paymentMethodFocusNode = FocusNode();
  final FocusNode _pocketFocusNode = FocusNode();

  bool get isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _amountController.addListener(_updateAmountHint);
    _descriptionController = TextEditingController();
    _descriptionController.addListener(_onDescriptionChanged);
    _memoController = TextEditingController();
    _selectedType = (widget.initialType == 'INCOME' || widget.initialType == 'EXPENSE')
        ? widget.initialType!
        : 'EXPENSE';
    _selectedDate = widget.initialDate ?? DateTime.now();

    if (isEditing) {
      _isLoadingTransaction = true;
      // Load the transaction by ID via the bloc
      _loadTransaction();
    } else {
      // Pre-select default payment method for new transactions
      _loadDefaultPaymentMethod();
    }
  }

  String? _coupleId;

  Future<void> _loadDefaultPaymentMethod() async {
    _coupleId ??= _resolveCoupleId();
    if (_coupleId == null) return;

    final defaultId = await CouplePrefs.getString(_coupleId!, 'default_payment_method_id');
    if (defaultId == null || !mounted) return;

    // Validate against current payment methods from server
    final pmBloc = getIt<PaymentMethodBloc>();
    final pmState = pmBloc.state;
    if (pmState is PaymentMethodLoaded) {
      final exists = pmState.paymentMethods.any((pm) => pm.id == defaultId);
      if (exists) {
        setState(() => _selectedPaymentMethodId = defaultId);
      } else {
        // Stale reference — clear it
        await CouplePrefs.remove(_coupleId!, 'default_payment_method_id');
      }
    } else {
      // PM list not loaded yet — set tentatively, will be validated on submit
      setState(() => _selectedPaymentMethodId = defaultId);
    }
  }

  String? _resolveCoupleId() {
    final authState = getIt<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.coupleId;
    }
    return null;
  }

  Future<void> _loadTransaction() async {
    final bloc = context.read<TransactionBloc>();
    final repo = bloc.transactionRepository;
    final result = await repo.getTransaction(widget.transactionId!);
    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _isLoadingTransaction = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('거래를 불러올 수 없습니다: ${failure.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      (transaction) {
        if (mounted) {
          setState(() {
            _isLoadingTransaction = false;
            _amountController.text = CurrencyFormatter.format(transaction.amount);
            _descriptionController.text = transaction.description;
            _memoController.text = transaction.memo ?? '';
            _selectedType = transaction.type;
            _selectedCategoryId = transaction.category?.id;
            _selectedCategoryDisplayName = transaction.category?.displayName;
            _selectedPaymentMethodId = transaction.paymentMethodId;
            _selectedPocketId = transaction.pocketId;
            _selectedDate = DateTime.parse(transaction.transactionDate);
          });
        }
      },
    );
  }

  void _onDescriptionChanged() {
    final text = _descriptionController.text.trim();
    _debounceTimer?.cancel();

    if (text.length < 2) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(text);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final repo = context.read<TransactionBloc>().transactionRepository;
    final result = await repo.getSuggestions(query);
    if (!mounted) return;
    result.fold(
      (_) {
        // On error, silently clear suggestions
        setState(() => _suggestions = []);
      },
      (suggestions) {
        setState(() => _suggestions = suggestions);
      },
    );
  }

  void _updateAmountHint() {
    final parsed = CurrencyFormatter.parse(_amountController.text);
    final hint = (parsed != null && parsed >= 10000)
        ? CurrencyFormatter.toKoreanUnit(parsed)
        : '';
    if (hint != _amountHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _amountHint = hint);
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _amountController.removeListener(_updateAmountHint);
    _amountController.dispose();
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    _memoController.dispose();
    _categoryFocusNode.dispose();
    _paymentMethodFocusNode.dispose();
    _pocketFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTransaction) {
      return Scaffold(
        appBar: AppBar(title: const Text('거래 수정')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '거래 수정' : '거래 추가'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isSubmitting ? null : () => _confirmDelete(context),
            ),
        ],
      ),
      body: BlocListener<TransactionBloc, TransactionState>(
        listener: (context, state) {
          if (state is TransactionLoaded) {
            final now = DateTime.now();
            getIt<DashboardBloc>().add(LoadDashboard(year: now.year, month: now.month));
            if (_continueMode) {
              _resetFormForContinue();
            } else if (isEditing) {
              // After editing, go directly to transactions list
              // to avoid stale edit page in browser history
              context.go('/transactions');
            } else {
              context.pop();
            }
          } else if (state is TransactionError) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Type toggle
                  if (isEditing)
                    ListTile(
                      leading: Icon(
                        _selectedType == 'INCOME'
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color: _selectedType == 'INCOME'
                            ? Colors.green
                            : Colors.red,
                      ),
                      title: Text(
                          _selectedType == 'INCOME' ? '수입' : '지출'),
                      subtitle: const Text('유형은 수정할 수 없습니다'),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    )
                  else
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'EXPENSE',
                          label: Text('지출'),
                          icon: Icon(Icons.arrow_downward),
                        ),
                        ButtonSegment(
                          value: 'INCOME',
                          label: Text('수입'),
                          icon: Icon(Icons.arrow_upward),
                        ),
                      ],
                      selected: {_selectedType},
                      onSelectionChanged: (value) {
                        setState(() {
                          _selectedType = value.first;
                          _selectedCategoryId = null;
                          _selectedCategoryDisplayName = null;
                        });
                      },
                    ),
                  const SizedBox(height: 24),
                  // Date picker
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(0),
                    child: _buildDatePicker(context),
                  ),
                  const SizedBox(height: 16),
                  // Amount
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: '금액',
                        suffixText: '원',
                        prefixIcon: const Icon(Icons.payments),
                        helperText: _amountHint.isNotEmpty ? _amountHint : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '금액을 입력하세요';
                        }
                        final amount = CurrencyFormatter.parse(value);
                        if (amount == null || amount <= 0) {
                          return '0보다 큰 금액을 입력하세요';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Description with suggestion chips
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: '내용',
                        hintText: '예: 점심 식사',
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLength: 255,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '내용을 입력하세요';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _suggestions.map((s) => ActionChip(
                          label: Text(s),
                          onPressed: () {
                            _descriptionController.text = s;
                            _descriptionController.selection =
                                TextSelection.collapsed(offset: s.length);
                            setState(() => _suggestions = []);
                          },
                        )).toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Category picker with keyboard support
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(3),
                    child: _buildKeyboardActivatableField(
                      focusNode: _categoryFocusNode,
                      onActivate: () => _activateCategoryPicker(context),
                      child: _buildCategoryPicker(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Payment method picker with keyboard support
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(4),
                    child: _buildKeyboardActivatableField(
                      focusNode: _paymentMethodFocusNode,
                      onActivate: () => _activatePaymentMethodPicker(context),
                      child: _buildPaymentMethodPicker(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Pocket picker with keyboard support
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(5),
                    child: _buildKeyboardActivatableField(
                      focusNode: _pocketFocusNode,
                      onActivate: () => _activatePocketPicker(context),
                      child: _buildPocketPicker(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Memo
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(6),
                    child: TextFormField(
                      controller: _memoController,
                      decoration: const InputDecoration(
                        labelText: '메모 (선택)',
                        hintText: '추가 메모',
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Continue mode options (new transactions only)
                  if (!isEditing) ...[
                    GestureDetector(
                      onTap: () => setState(() => _keepSameItems = !_keepSameItems),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _keepSameItems,
                              onChanged: (v) => setState(() => _keepSameItems = v ?? false),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '동일 항목 유지 (날짜/카테고리/결제수단)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Submit buttons
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(7),
                    child: isEditing
                        ? FilledButton(
                            onPressed: _isSubmitting ? null : _onSubmit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('수정'),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSubmitting ? null : () {
                                    _continueMode = true;
                                    _onSubmit();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: _isSubmitting && _continueMode
                                      ? const SizedBox(
                                          height: 20, width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('저장 & 계속'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _isSubmitting ? null : () {
                                    _continueMode = false;
                                    _onSubmit();
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: _isSubmitting && !_continueMode
                                      ? const SizedBox(
                                          height: 20, width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('저장'),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps a selector field with Focus + KeyboardListener so that
  /// Enter/Space activates the bottom sheet selector.
  Widget _buildKeyboardActivatableField({
    required FocusNode focusNode,
    required VoidCallback onActivate,
    required Widget child,
  }) {
    return Focus(
      focusNode: focusNode,
      canRequestFocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          onActivate();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          focusNode.requestFocus();
          onActivate();
        },
        child: AbsorbPointer(
          // AbsorbPointer prevents the inner InkWell from capturing tap;
          // the GestureDetector above handles it, allowing focus to be set.
          child: child,
        ),
      ),
    );
  }

  void _activateCategoryPicker(BuildContext context) {
    final catState = context.read<CategoryBloc>().state;
    final categories = catState is CategoryLoaded
        ? (_selectedType == 'INCOME'
            ? catState.incomeCategories
            : catState.expenseCategories)
        : <Category>[];
    setState(() => _categoryError = null);
    _showCategorySelectorSheet(context, categories);
  }

  void _activatePaymentMethodPicker(BuildContext context) {
    final pmState = context.read<PaymentMethodBloc>().state;
    final methods = pmState is PaymentMethodLoaded
        ? pmState.activePaymentMethods
        : <PaymentMethod>[];
    setState(() => _paymentMethodError = null);
    _showPaymentMethodSelectorSheet(context, methods);
  }

  void _activatePocketPicker(BuildContext context) {
    final pocketState = context.read<PocketBloc>().state;
    final pockets = pocketState is PocketLoaded
        ? pocketState.pockets
        : <MoneyPocket>[];
    _showPocketSelectorSheet(context, pockets);
  }

  Widget _buildCategoryPicker(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      builder: (context, catState) {
        final categories = catState is CategoryLoaded
            ? (_selectedType == 'INCOME'
                ? catState.incomeCategories
                : catState.expenseCategories)
            : <Category>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemSelectorField(
              label: '카테고리 *',
              selectedLabel: _selectedCategoryDisplayName ?? (_selectedCategoryId != null ? '(삭제됨)' : null),
              prefixIcon: Icons.category,
              placeholder: '카테고리를 선택하세요',
              onTap: () {
                setState(() => _categoryError = null);
                _showCategorySelectorSheet(context, categories);
              },
            ),
            if (_categoryError != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: Text(
                  _categoryError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentMethodPicker(BuildContext context) {
    return BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
      builder: (context, pmState) {
        final methods = pmState is PaymentMethodLoaded
            ? pmState.activePaymentMethods
            : <PaymentMethod>[];

        final selectedName = _selectedPaymentMethodId != null
            ? methods
                .where((pm) => pm.id == _selectedPaymentMethodId)
                .map((pm) => pm.name)
                .firstOrNull
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemSelectorField(
              label: '결제수단 *',
              selectedLabel: selectedName,
              prefixIcon: Icons.account_balance_wallet,
              placeholder: '결제수단을 선택하세요',
              onTap: () {
                setState(() => _paymentMethodError = null);
                _showPaymentMethodSelectorSheet(context, methods);
              },
            ),
            if (_paymentMethodError != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: Text(
                  _paymentMethodError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPocketPicker(BuildContext context) {
    return BlocBuilder<PocketBloc, PocketState>(
      builder: (context, pocketState) {
        final pockets = pocketState is PocketLoaded
            ? pocketState.pockets
            : <MoneyPocket>[];

        final selectedName = _selectedPocketId != null
            ? pockets
                .where((p) => p.id == _selectedPocketId)
                .map((p) => p.name)
                .firstOrNull
            : null;

        return ItemSelectorField(
          label: '포켓 (선택)',
          selectedLabel: selectedName,
          prefixIcon: Icons.account_balance_wallet,
          placeholder: '포켓 미지정',
          onTap: () => _showPocketSelectorSheet(context, pockets),
        );
      },
    );
  }

  void _showCategorySelectorSheet(BuildContext context, List<Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => CategoryGroupSelectorSheet(
        selectedCategoryId: _selectedCategoryId,
        categoryType: _selectedType,
        onSelected: (category) {
          setState(() {
            _selectedCategoryId = category?.id;
            _selectedCategoryDisplayName = null;
          });
        },
        onSelectedWithGroupName: (category, groupName) {
          setState(() {
            _selectedCategoryId = category?.id;
            if (category != null && groupName != null && groupName.isNotEmpty) {
              _selectedCategoryDisplayName = '$groupName > ${category.name}';
            } else {
              _selectedCategoryDisplayName = category?.name;
            }
          });
        },
        onDelete: (id) {
          if (_selectedCategoryId == id) {
            setState(() => _selectedCategoryId = null);
          }
        },
      ),
    );
  }

  void _showPaymentMethodSelectorSheet(BuildContext context, List<PaymentMethod> methods) {
    final pmBloc = context.read<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider<PaymentMethodBloc>.value(
        value: pmBloc,
        child: BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
          builder: (sheetContext, pmState) {
            final liveMethods = pmState is PaymentMethodLoaded
                ? pmState.activePaymentMethods
                : methods;
            return ItemSelectorSheet(
              title: '결제수단 선택',
              items: liveMethods
                  .map((pm) => SelectorItem(
                        id: pm.id,
                        label: pm.name,
                        leadingIcon: Icons.payment,
                        isDeletable: !pm.isDefault,
                      ))
                  .toList(),
              selectedId: _selectedPaymentMethodId,
              nullLabel: '선택 안 함',
              onSelected: (item) {
                setState(() {
                  _selectedPaymentMethodId = item?.id;
                });
              },
              onDelete: (id) {
                pmBloc.add(DeletePaymentMethod(id));
                if (_selectedPaymentMethodId == id) {
                  setState(() => _selectedPaymentMethodId = null);
                }
              },
              onCreate: () => _showCreatePaymentMethodSheet(context),
              createLabel: '+ 새 결제수단',
            );
          },
        ),
      ),
    );
  }

  void _showPocketSelectorSheet(BuildContext context, List<MoneyPocket> pockets) {
    final pocketBloc = context.read<PocketBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider<PocketBloc>.value(
        value: pocketBloc,
        child: BlocBuilder<PocketBloc, PocketState>(
          builder: (sheetContext, pocketState) {
            final livePockets = pocketState is PocketLoaded
                ? pocketState.pockets
                : pockets;
            return ItemSelectorSheet(
              title: '포켓 선택',
              items: livePockets
                  .map((p) => SelectorItem(
                        id: p.id,
                        label: p.name,
                        leadingIcon: Icons.account_balance_wallet,
                        leadingColor: UIHelpers.parseColor(p.color),
                      ))
                  .toList(),
              selectedId: _selectedPocketId,
              nullLabel: '포켓 미지정',
              onSelected: (item) {
                setState(() {
                  _selectedPocketId = item?.id;
                });
              },
              onDelete: (id) {
                pocketBloc.add(DeletePocket(id));
                if (_selectedPocketId == id) {
                  setState(() => _selectedPocketId = null);
                }
              },
              onCreate: () => _showCreatePocketSheet(context),
              createLabel: '+ 새 포켓',
            );
          },
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030, 12, 31),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '날짜',
          prefixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(formattedDate),
      ),
    );
  }

  Future<void> _showCreatePaymentMethodSheet(BuildContext context) async {
    final bloc = context.read<PaymentMethodBloc>();
    final oldIds = (bloc.state is PaymentMethodLoaded)
        ? (bloc.state as PaymentMethodLoaded)
            .paymentMethods
            .map((pm) => pm.id)
            .toSet()
        : <String>{};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider<PaymentMethodBloc>.value(
        value: bloc,
        child: PaymentMethodFormSheet(
          onSubmit: (name, type, settlementDay, closingDay) {
            bloc.add(CreatePaymentMethod(
              name: name,
              type: type,
              settlementDay: settlementDay,
              closingDay: closingDay,
            ));
          },
        ),
      ),
    );

    if (!mounted) return;
    await _autoSelectNewItem<PaymentMethodBloc, PaymentMethodState>(
      bloc: bloc,
      getIds: (s) => s is PaymentMethodLoaded
          ? s.paymentMethods.map((pm) => pm.id).toSet()
          : <String>{},
      oldIds: oldIds,
      onSelect: (newId) => setState(() {
        _selectedPaymentMethodId = newId;
      }),
    );
  }

  Future<void> _showCreatePocketSheet(BuildContext context) async {
    final bloc = context.read<PocketBloc>();
    final oldIds = (bloc.state is PocketLoaded)
        ? (bloc.state as PocketLoaded).pockets.map((p) => p.id).toSet()
        : <String>{};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PocketFormSheet(
        onSubmit: (name, type, allocatedAmount, icon, color, goalAmount,
            targetDate) {
          bloc.add(CreatePocket(
            name: name,
            type: type,
            allocatedAmount: allocatedAmount,
            icon: icon,
            color: color,
            goalAmount: goalAmount,
            targetDate: targetDate,
          ));
        },
      ),
    );

    if (!mounted) return;
    await _autoSelectNewItem<PocketBloc, PocketState>(
      bloc: bloc,
      getIds: (s) => s is PocketLoaded
          ? s.pockets.map((p) => p.id).toSet()
          : <String>{},
      oldIds: oldIds,
      onSelect: (newId) => setState(() {
        _selectedPocketId = newId;
      }),
    );
  }

  Future<void> _autoSelectNewItem<B extends BlocBase<S>, S>({
    required B bloc,
    required Set<String> Function(S state) getIds,
    required Set<String> oldIds,
    required void Function(String newId) onSelect,
  }) async {
    // Check if already updated
    final currentIds = getIds(bloc.state);
    final diff = currentIds.difference(oldIds);
    if (diff.isNotEmpty) {
      onSelect(diff.first);
      return;
    }

    // Wait for next state with new item
    try {
      await for (final state in bloc.stream.timeout(const Duration(seconds: 10))) {
        final newIds = getIds(state);
        final newDiff = newIds.difference(oldIds);
        if (newDiff.isNotEmpty) {
          if (mounted) onSelect(newDiff.first);
          return;
        }
      }
    } catch (_) {
      // Timeout -- user can manually select
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: '거래 삭제',
    );
    if (confirmed && context.mounted) {
      context.read<TransactionBloc>().add(
            DeleteTransaction(widget.transactionId!),
          );
    }
  }

  void _resetFormForContinue() {
    setState(() {
      _amountController.clear();
      _amountHint = '';
      _descriptionController.clear();
      _memoController.clear();
      _suggestions = [];
      _isSubmitting = false;
      _continueMode = false;
      _categoryError = null;
      _paymentMethodError = null;

      if (!_keepSameItems) {
        _selectedCategoryId = null;
        _selectedCategoryDisplayName = null;
        _selectedPaymentMethodId = null;
        _selectedPocketId = null;
        _loadDefaultPaymentMethod();
      }
      // _selectedDate and _selectedType are always kept
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('저장 완료! 다음 항목을 입력하세요.'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onSubmit() {
    // Validate custom pickers (not part of Form)
    bool hasPickerError = false;
    if (_selectedCategoryId == null) {
      setState(() => _categoryError = '카테고리를 선택하세요');
      hasPickerError = true;
    } else {
      setState(() => _categoryError = null);
    }
    if (_selectedPaymentMethodId == null) {
      setState(() => _paymentMethodError = '결제수단을 선택하세요');
      hasPickerError = true;
    } else {
      setState(() => _paymentMethodError = null);
    }

    if (hasPickerError || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);
    final amount = CurrencyFormatter.parse(_amountController.text.trim())!;
    final description = _descriptionController.text.trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final memo =
        _memoController.text.trim().isEmpty ? null : _memoController.text.trim();
    final bloc = context.read<TransactionBloc>();

    if (isEditing) {
      bloc.add(UpdateTransaction(
        id: widget.transactionId!,
        amount: amount,
        description: description,
        categoryId: _selectedCategoryId,
        transactionDate: dateStr,
        memo: memo,
        clearMemo: memo == null,
        paymentMethodId: _selectedPaymentMethodId,
        pocketId: _selectedPocketId,
      ));
    } else {
      bloc.add(CreateTransaction(
        type: _selectedType,
        amount: amount,
        description: description,
        categoryId: _selectedCategoryId,
        transactionDate: dateStr,
        memo: memo,
        paymentMethodId: _selectedPaymentMethodId,
        pocketId: _selectedPocketId,
      ));
    }
  }
}
