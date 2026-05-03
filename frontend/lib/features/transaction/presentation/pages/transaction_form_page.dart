import 'dart:async';

import 'package:flutter/material.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/utils/dialog_helpers.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/core/services/couple_prefs.dart';
import 'package:flutter/services.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/calculator_amount_field.dart';
import 'package:budget_book/core/widgets/amount_input_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/core/widgets/category_group_selector_sheet.dart';
import 'package:budget_book/features/transaction/domain/adjustment_submission.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/core/utils/payment_method_helpers.dart';
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
import 'package:budget_book/features/transaction/domain/entities/transaction.dart'
    as tx_entity;
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';
import 'package:budget_book/features/ai/data/datasources/ai_remote_datasource.dart';
import 'package:budget_book/features/ai/domain/entities/ai_classify_result.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_state.dart';

class TransactionFormPage extends StatefulWidget {
  /// If editing, pass the transaction ID (from URL path parameter).
  /// The page will load the transaction data from the BLoC/repository.
  final String? transactionId;

  /// Optional initial transaction type ('EXPENSE' or 'INCOME').
  /// Used when navigating from dashboard quick actions.
  final String? initialType;

  /// Pre-fill fields from an existing transaction (for copy).
  /// Date defaults to today; all other fields are copied.
  /// 배치 4 D-4 (2026-04-26): state.extra 사용은 deprecated — 웹 새로고침 시 유실.
  /// 신규 진입은 copyFromId (query param) 권장. 본 필드는 기존 호환을 위해 유지.
  final tx_entity.Transaction? copyFrom;

  /// 배치 4 D-4: copy-from transaction 의 id (query param 으로 전달).
  /// 새로고침 시에도 URL 에서 보존되어 prefill 가능.
  final String? copyFromId;

  /// Optional initial date for the transaction.
  /// Used when navigating from a date header in the transaction list.
  final DateTime? initialDate;

  /// Optional initial payment method ID.
  /// Used when adding a transaction from a filtered payment method view.
  final String? initialPaymentMethodId;

  /// Optional initial tab: 'expense' (0), 'income' (1), 'transfer' (2).
  /// Determines which tab is shown on page load.
  final String? initialTab;

  const TransactionFormPage({
    super.key,
    this.transactionId,
    this.initialType,
    this.copyFrom,
    this.copyFromId,
    this.initialDate,
    this.initialPaymentMethodId,
    this.initialTab,
  });

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  String _amountHint = '';
  late final TextEditingController _descriptionController;
  late final TextEditingController _memoController;
  late String _selectedType;
  String? _selectedCategoryId;
  String? _selectedCategoryDisplayName;

  /// 회차 4 — 잔액 조정 모드 방향 (true=증가/+, false=감소/-).
  /// _isAdjustmentSelected 일 때만 의미 있음.
  bool _adjustmentIsIncrease = true;

  bool get _isAdjustmentSelected =>
      _selectedType == 'ADJUSTMENT' ||
      _selectedCategoryId == kAdjustmentSentinel;
  String? _selectedPaymentMethodId;
  String? _selectedPocketId;
  late DateTime _selectedDate;
  bool _isLoadingTransaction = false;
  bool _isSubmitting = false;
  bool _continueMode = false;
  bool _keepSameItems = false;
  String? _categoryError;
  String? _paymentMethodError;

  // Suggestion state
  List<SuggestionGroup> _suggestions = [];
  SuggestionGroup? _expandedSuggestion;
  bool _suppressSuggestions = false;
  Timer? _debounceTimer;

  // AI classification state
  AiClassifyResult? _aiResult;
  bool _aiLoading = false;
  Timer? _aiDebounceTimer;

  /// 회차 5 — _onSubmit 후 spinner 무한 회귀 방지용 timeout 가드.
  Timer? _submitTimeoutTimer;

  // FocusNodes for keyboard navigation on selector fields
  final FocusNode _categoryFocusNode = FocusNode();
  final FocusNode _paymentMethodFocusNode = FocusNode();
  final FocusNode _pocketFocusNode = FocusNode();

  // Tab controller for expense/income/transfer tabs
  late final TabController _tabController;

  // Transfer form fields (used when tab index == 2)
  // 회차 12 P5 (2026-05-03) — 공통 controllers (_amountController/_descriptionController/_memoController)
  // 사용으로 통일. _transfer*Controller 별도 controllers 제거.
  // 사용자 요구: 수입/지출/예산/이체 탭 전환 시 공통 항목 (금액/설명/메모) 유지.
  final _transferFormKey = GlobalKey<FormState>();
  String? _transferSourcePaymentMethodId;
  String? _transferDestinationPaymentMethodId;
  late DateTime _transferDate;
  bool _isTransferSubmitting = false;
  int _swapCounter = 0;

  bool get isEditing => widget.transactionId != null;

  int _resolveInitialTabIndex() {
    // When editing, determine tab from transaction type (no transfer tab for edit)
    if (isEditing) {
      if (widget.initialType == 'INCOME') return 1;
      return 0;
    }
    // From initialTab query parameter
    switch (widget.initialTab) {
      case 'income':
        return 1;
      case 'transfer':
        return 2;
      case 'expense':
      default:
        // Also check initialType for backward compatibility
        if (widget.initialType == 'INCOME') return 1;
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize tab controller (hide transfer tab when editing)
    final initialIndex = _resolveInitialTabIndex();
    _tabController = TabController(
      length: isEditing ? 2 : 3,
      vsync: this,
      initialIndex: isEditing ? initialIndex.clamp(0, 1) : initialIndex,
    );
    _tabController.addListener(_onTabChanged);

    _amountController = TextEditingController();
    _amountController.addListener(_updateAmountHint);
    _descriptionController = TextEditingController();
    _descriptionController.addListener(_onDescriptionChanged);
    _memoController = TextEditingController();
    _selectedType = (initialIndex == 1 || widget.initialType == 'INCOME')
        ? 'INCOME'
        : 'EXPENSE';
    _selectedDate = widget.initialDate ?? DateTime.now();

    // 회차 12 P5 — transfer 별도 controllers 제거. 공통 controller 사용.
    _transferDate = widget.initialDate ?? DateTime.now();

    if (isEditing) {
      _isLoadingTransaction = true;
      _loadTransaction();
    } else if (widget.copyFrom != null) {
      _prefillFromTransaction(widget.copyFrom!);
    } else if (widget.copyFromId != null) {
      // 배치 4 D-4: query param 으로 전달된 copy-from id → API 로 fetch 후 prefill.
      // 새로고침 시에도 URL 에서 보존되어 정상 동작.
      _isLoadingTransaction = true;
      _loadCopyFromTransaction(widget.copyFromId!);
    } else {
      _loadDefaultPaymentMethod();
    }
  }

  void _prefillFromTransaction(tx_entity.Transaction src) {
    _descriptionController.text = src.description;
    _memoController.text = src.memo ?? '';
    _selectedType = src.type;
    _selectedCategoryId = src.category?.id;
    _selectedCategoryDisplayName = src.category?.displayName;
    _selectedPaymentMethodId = src.paymentMethodId;
    _selectedPocketId = src.pocketId;
    // 회차 4 — ADJUSTMENT 거래 prefill: sentinel 카테고리 + 부호로 방향 추정.
    if (src.type == 'ADJUSTMENT') {
      _selectedCategoryId = kAdjustmentSentinel;
      _selectedCategoryDisplayName = '잔액 조정';
      _adjustmentIsIncrease = src.amount >= 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // ADJUSTMENT 는 form 에 절대값 표시 (방향은 radio 로). 그 외는 그대로.
        final displayAmount =
            src.type == 'ADJUSTMENT' ? src.amount.abs() : src.amount;
        _amountController.text = CurrencyFormatter.format(displayAmount);
      }
    });
  }

  Future<void> _loadCopyFromTransaction(String id) async {
    try {
      final repo = context.read<TransactionBloc>().transactionRepository;
      final result = await repo.getTransaction(id);
      result.fold(
        (failure) {
          if (mounted) {
            setState(() => _isLoadingTransaction = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('복사할 거래를 불러올 수 없습니다: ${failure.message}'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        (transaction) {
          if (mounted) {
            setState(() => _isLoadingTransaction = false);
            _prefillFromTransaction(transaction);
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isLoadingTransaction = false);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        if (_tabController.index == 0) {
          _selectedType = 'EXPENSE';
          _selectedCategoryId = null;
          _selectedCategoryDisplayName = null;
        } else if (_tabController.index == 1) {
          _selectedType = 'INCOME';
          _selectedCategoryId = null;
          _selectedCategoryDisplayName = null;
        }
        // Tab 2 (transfer) doesn't change _selectedType
      });
    }
  }

  String? _coupleId;

  Future<void> _loadDefaultPaymentMethod() async {
    // If initial payment method is specified (e.g., from filtered view), use it
    if (widget.initialPaymentMethodId != null && _selectedPaymentMethodId == null) {
      setState(() => _selectedPaymentMethodId = widget.initialPaymentMethodId);
      return;
    }

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
    try {
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
            // 회차 5 회귀 fix — _prefillFromTransaction 단일 진입점 사용.
            // 이전: raw amount 직접 set + ADJUSTMENT 분기 누락 → 감소(-1) 거래
            // 수정 시 controller 에 "-1" 표시 + 라디오 부호 충돌로 수정 불가.
            setState(() {
              _isLoadingTransaction = false;
              _selectedDate = DateTime.parse(transaction.transactionDate);
              _prefillFromTransaction(transaction);
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTransaction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('거래 로드 실패: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _onDescriptionChanged() {
    // Skip if programmatically set (e.g., from suggestion apply)
    if (_suppressSuggestions) return;

    final text = _descriptionController.text.trim();
    _debounceTimer?.cancel();
    _aiDebounceTimer?.cancel();
    if (text.length < 2) {
      if (_suggestions.isNotEmpty || _expandedSuggestion != null) {
        setState(() {
          _suggestions = [];
          _expandedSuggestion = null;
        });
      }
      if (_aiResult != null || _aiLoading) {
        setState(() {
          _aiResult = null;
          _aiLoading = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(text);
    });
    _aiDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchAiClassification(text);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final repo = context.read<TransactionBloc>().transactionRepository;
    final result = await repo.getSuggestions(query);
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _suggestions = [];
        _expandedSuggestion = null;
      }),
      (data) => setState(() {
        _suggestions = data;
        // expand 보존 — 사용자가 chip expand 한 뒤 fetch 재발화 시
        // 같은 description 가 응답에 있으면 expand 유지, 없으면 null.
        // (SuggestionGroup 는 description 기준 Equatable)
        if (_expandedSuggestion != null &&
            !data.contains(_expandedSuggestion)) {
          _expandedSuggestion = null;
        }
      }),
    );
  }

  void _applySuggestionPattern(SuggestionGroup group, SuggestionPattern? pattern) {
    _suppressSuggestions = true;
    _debounceTimer?.cancel();
    setState(() {
      _descriptionController.text = group.description;
      _descriptionController.selection =
          TextSelection.collapsed(offset: group.description.length);
      if (pattern != null) {
        _selectedCategoryId = pattern.categoryId;
        _selectedCategoryDisplayName = pattern.categoryName;
        _selectedPaymentMethodId = pattern.paymentMethodId;
      }
      _suggestions = [];
      _expandedSuggestion = null;
    });
    // Re-enable after listener fires
    Future.microtask(() => _suppressSuggestions = false);
  }

  Future<void> _fetchAiClassification(String description) async {
    if (!mounted) return;
    setState(() => _aiLoading = true);
    try {
      final datasource = getIt<AiRemoteDataSource>();
      final results = await datasource.classify(description, _selectedType);
      if (!mounted) return;
      setState(() {
        _aiResult = results.isNotEmpty ? results.first : null;
        _aiLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiResult = null;
        _aiLoading = false;
      });
    }
  }

  void _applyAiCategory(AiClassifyResult result) {
    setState(() {
      _selectedCategoryId = result.categoryId;
      _selectedCategoryDisplayName = result.categoryName;
      _aiResult = null;
    });
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
    _aiDebounceTimer?.cancel();
    _submitTimeoutTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _descriptionController.removeListener(_onDescriptionChanged);
    _amountController.removeListener(_updateAmountHint);
    _amountController.dispose();
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

    // BlocListeners are placed outside the TabBarView/Scaffold body
    // to prevent them from being rebuilt (and missing state changes)
    // when setState is called (e.g., _isTransferSubmitting toggling).
    return MultiBlocListener(
      listeners: [
        BlocListener<TransactionBloc, TransactionState>(
          listener: (context, state) {
            // Only react when user actually submitted the form.
            // Without this guard, any TransactionLoaded change (e.g., LoadMore
            // from the list page behind) would trigger premature navigation.
            if (!_isSubmitting) return;
            if (state is TransactionLoaded) {
              _submitTimeoutTimer?.cancel();
              _isSubmitting = false;
              // 회차 12 P2 Phase A — 거래 등록 후 dashboard reload 시 사용자가 보던
              // month 유지 (MonthCubit). 이전: now 강제로 다른 월 보던 사용자에게
              // 현재월 dashboard 가 표시되어 sync 깨짐.
              final monthState = getIt<MonthCubit>().state;
              getIt<DashboardBloc>().add(LoadDashboard(year: monthState.year, month: monthState.month));
              getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
              if (_continueMode) {
                _resetFormForContinue();
              } else if (isEditing) {
                // After editing, go directly to transactions list
                // to avoid stale edit page in browser history
                context.go('/transactions?year=${state.year}&month=${state.month}');
              } else {
                context.pop();
              }
            } else if (state is TransactionError) {
              _submitTimeoutTimer?.cancel();
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
        ),
        BlocListener<TransferBloc, TransferState>(
          listener: (context, state) {
            debugPrint('[TransferForm] BlocListener state=$state, submitting=$_isTransferSubmitting');
            if (!_isTransferSubmitting) return;
            if (state is TransferLoaded) {
              if (state.operationError != null) {
                setState(() => _isTransferSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.operationError!),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              } else {
                setState(() => _isTransferSubmitting = false);
                final dashState = getIt<DashboardBloc>().state;
                final year = dashState is DashboardLoaded ? dashState.year : DateTime.now().year;
                final month = dashState is DashboardLoaded ? dashState.month : DateTime.now().month;
                getIt<DashboardBloc>().add(LoadDashboard(year: year, month: month));
                getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이체가 등록되었습니다')),
                );
                context.pop();
              }
            } else if (state is TransferError) {
              setState(() => _isTransferSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? '거래 수정' : '거래 추가'),
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _isSubmitting ? null : () => _confirmDelete(context),
              ),
          ],
          bottom: isEditing
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            _selectedType == 'INCOME'
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: _selectedType == 'INCOME'
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedType == 'INCOME' ? '수입' : '지출'} (유형 수정 불가)',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.arrow_downward), text: '지출'),
                    Tab(icon: Icon(Icons.arrow_upward), text: '수입'),
                    Tab(icon: Icon(Icons.swap_horiz), text: '이체'),
                  ],
                ),
        ),
        body: isEditing
            ? _buildTransactionFormBody(context)
            : TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Expense form
                  _buildTransactionFormBody(context),
                  // Tab 1: Income form
                  _buildTransactionFormBody(context),
                  // Tab 2: Transfer form (embedded)
                  _buildTransferFormBody(context),
                ],
              ),
      ),
    );
  }

  Widget _buildTransactionFormBody(BuildContext context) {
    // BlocListener is now in the top-level MultiBlocListener in build()
    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  // Date picker
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(0),
                    child: _buildDatePicker(context),
                  ),
                  const SizedBox(height: 16),
                  // Amount
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: CalculatorAmountField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: '금액',
                        suffixText: '원',
                        prefixIcon: Icon(Icons.payments),
                      ),
                      helperText: _amountHint.isNotEmpty ? _amountHint : null,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '금액을 입력하세요';
                        }
                        final amount = CurrencyFormatter.parse(value);
                        if (amount == null || amount < 0) {
                          return '금액을 입력하세요';
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
                  // Suggestion chips (rich - with category/payment method patterns)
                  if (_suggestions.isNotEmpty)
                    _buildSuggestionArea(context),
                  // AI classification recommendation
                  if (_aiResult != null && _selectedCategoryId != _aiResult!.categoryId)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: ActionChip(
                        avatar: const Icon(Icons.auto_awesome, size: 16),
                        label: Text('AI 추천: ${_aiResult!.categoryName}'),
                        onPressed: () => _applyAiCategory(_aiResult!),
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
                  // 회차 4 — ADJUSTMENT 모드 banner + 증가/감소 radio.
                  if (_isAdjustmentSelected) ...[
                    const SizedBox(height: 12),
                    _buildAdjustmentBanner(context),
                  ],
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
    );
  }

  // ----- Embedded Transfer Form (Tab 2) -----

  Future<void> _selectTransferDate() async {
    final picked = await showCalendarPickerDialog(
      context: context,
      initialDate: _transferDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked != null) {
      setState(() => _transferDate = picked);
    }
  }

  void _submitTransfer() {
    if (!_transferFormKey.currentState!.validate()) return;
    if (_transferSourcePaymentMethodId == null ||
        _transferDestinationPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출금/입금 결제수단을 모두 선택해주세요')),
      );
      return;
    }
    if (_transferSourcePaymentMethodId == _transferDestinationPaymentMethodId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출금/입금 결제수단이 같을 수 없습니다')),
      );
      return;
    }

    // Block CREDIT to CREDIT transfers
    final pmState = getIt<PaymentMethodBloc>().state;
    if (pmState is PaymentMethodLoaded) {
      final source = pmState.activePaymentMethods
          .where((pm) => pm.id == _transferSourcePaymentMethodId)
          .firstOrNull;
      final dest = pmState.activePaymentMethods
          .where((pm) => pm.id == _transferDestinationPaymentMethodId)
          .firstOrNull;
      if (source != null && dest != null && source.isCredit && dest.isCredit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카드 간 이체는 지원하지 않습니다')),
        );
        return;
      }
    }

    // 회차 12 P5 — 공통 controller 사용으로 통일.
    final amount = CurrencyFormatter.parse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('금액을 입력해주세요')),
      );
      return;
    }

    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final memo = _memoController.text.trim().isEmpty
        ? null
        : _memoController.text.trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(_transferDate);

    setState(() => _isTransferSubmitting = true);

    debugPrint('[TransferForm] _submitTransfer: amount=$amount, source=$_transferSourcePaymentMethodId, dest=$_transferDestinationPaymentMethodId, date=$dateStr');
    final bloc = context.read<TransferBloc>();
    bloc.add(CreateTransfer(
      sourcePaymentMethodId: _transferSourcePaymentMethodId!,
      destinationPaymentMethodId: _transferDestinationPaymentMethodId!,
      amount: amount,
      description: description,
      transferDate: dateStr,
      memo: memo,
    ));
  }

  Widget _buildTransferFormBody(BuildContext context) {
    // BlocListener is now in the top-level MultiBlocListener in build()
    return _buildTransferFormContent(context);
  }

  Widget _buildTransferFormContent(BuildContext context) {
    final pmState = getIt<PaymentMethodBloc>().state;
    final methods = pmState is PaymentMethodLoaded
        ? pmState.activePaymentMethods
        : <PaymentMethod>[];

    final selectedDest = methods
        .where((pm) => pm.id == _transferDestinationPaymentMethodId)
        .firstOrNull;
    final selectedSource = methods
        .where((pm) => pm.id == _transferSourcePaymentMethodId)
        .firstOrNull;
    final destIsCredit = selectedDest?.isCredit ?? false;
    final sourceIsCredit = selectedSource?.isCredit ?? false;

    final sourceMethods = destIsCredit
        ? methods.where((pm) => !pm.isCredit).toList()
        : methods;
    final destMethods = methods
        .where((pm) => pm.id != _transferSourcePaymentMethodId)
        .where((pm) => !sourceIsCredit || !pm.isCredit)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _transferFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date (matches expense/income form order)
            InkWell(
              onTap: _selectTransferDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '이체일',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('yyyy년 M월 d일 (E)', 'ko')
                      .format(_transferDate),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Amount — 회차 12 P5: 공통 controller 사용 (수입/지출/이체 간 유지).
            AmountInputField(
              controller: _amountController,
              labelText: '금액',
              filterDigitsOnly: true,
              validator: (value) {
                if (value == null || value.isEmpty) return '금액을 입력하세요';
                final amount = CurrencyFormatter.parse(value);
                if (amount == null || amount <= 0) return '유효한 금액을 입력하세요';
                if (amount > 999999999) {
                  return '최대 999,999,999원까지 입력 가능합니다';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Source payment method
            DropdownButtonFormField<String>(
              key: ValueKey('transfer_source_$_swapCounter'),
              initialValue: _transferSourcePaymentMethodId,
              decoration: const InputDecoration(
                labelText: '출금 결제수단',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              isExpanded: true,
              items: sourceMethods
                  .map((pm) => DropdownMenuItem(
                        value: pm.id,
                        child: Text(pm.name),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _transferSourcePaymentMethodId = value;
                  final newSource =
                      methods.where((pm) => pm.id == value).firstOrNull;
                  if (newSource?.isCredit == true &&
                      selectedDest?.isCredit == true) {
                    _transferDestinationPaymentMethodId = null;
                  }
                });
              },
              validator: (value) =>
                  value == null ? '출금 결제수단을 선택하세요' : null,
            ),
            const SizedBox(height: 8),
            // Swap button
            Center(
              child: IconButton(
                onPressed: () {
                  final wouldSwapSourceBeCredit =
                      selectedDest?.isCredit ?? false;
                  final wouldSwapDestBeCredit =
                      selectedSource?.isCredit ?? false;
                  if (wouldSwapSourceBeCredit && wouldSwapDestBeCredit) return;
                  setState(() {
                    final temp = _transferSourcePaymentMethodId;
                    _transferSourcePaymentMethodId =
                        _transferDestinationPaymentMethodId;
                    _transferDestinationPaymentMethodId = temp;
                    _swapCounter++;
                  });
                },
                icon: const Icon(Icons.swap_vert),
                tooltip: '출금/입금 교환',
              ),
            ),
            const SizedBox(height: 8),
            // Destination payment method
            DropdownButtonFormField<String>(
              key: ValueKey('transfer_dest_$_swapCounter'),
              initialValue: _transferDestinationPaymentMethodId,
              decoration: const InputDecoration(
                labelText: '입금 결제수단',
                prefixIcon: Icon(Icons.account_balance),
              ),
              isExpanded: true,
              items: destMethods
                  .map((pm) => DropdownMenuItem(
                        value: pm.id,
                        child: Text(pm.name),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _transferDestinationPaymentMethodId = value;
                  final newDest =
                      methods.where((pm) => pm.id == value).firstOrNull;
                  if (newDest?.isCredit == true &&
                      selectedSource?.isCredit == true) {
                    _transferSourcePaymentMethodId = null;
                    _swapCounter++;
                  }
                });
              },
              validator: (value) =>
                  value == null ? '입금 결제수단을 선택하세요' : null,
            ),
            const SizedBox(height: 16),
            // Description — 회차 12 P5: 공통 controller 사용
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '내용 (선택)',
                prefixIcon: Icon(Icons.description),
                hintText: '예: ATM 출금',
              ),
              maxLength: 255,
            ),
            const SizedBox(height: 8),
            // Memo — 회차 12 P5: 공통 controller 사용
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            // Submit button
            FilledButton(
              onPressed: _isTransferSubmitting ? null : _submitTransfer,
              child: _isTransferSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionArea(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Suggestion chips (description only)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _suggestions.map((sg) {
              final isExpanded = _expandedSuggestion == sg;
              return ActionChip(
                label: Text(sg.description),
                avatar: isExpanded
                    ? const Icon(Icons.expand_less, size: 18)
                    : null,
                onPressed: () {
                  if (isExpanded) {
                    // Collapse: apply description only (empty pattern)
                    _applySuggestionPattern(sg, null);
                  } else {
                    setState(() => _expandedSuggestion = sg);
                  }
                },
              );
            }).toList(),
          ),
          // Expanded patterns for selected suggestion
          if (_expandedSuggestion != null) ...[
            const SizedBox(height: 8),
            // First option: description only, no pre-fill
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _applySuggestionPattern(_expandedSuggestion!, null),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '내용만 입력 (카테고리·결제수단 직접 선택)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Grouped patterns sorted by count
            ..._expandedSuggestion!.patterns.map((p) {
              final label = [
                p.categoryName,
                p.paymentMethodName,
              ].where((s) => s != null).join(' · ');
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _applySuggestionPattern(_expandedSuggestion!, p),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label.isEmpty ? '미분류' : label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${p.count}회',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
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


  /// 회차 4 — ADJUSTMENT 모드 banner + 증가/감소 ChoiceChip.
  /// 잔액 조정 카테고리 선택 시 노출. 부호는 submit 시 helper 가 처리.
  Widget _buildAdjustmentBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('adjustment-banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: theme.colorScheme.tertiary),
              const SizedBox(width: 6),
              Text(
                '잔액 조정 모드',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '통계 집계 제외 · 잔액 계산 포함',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer
                        .withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  key: const Key('adjustment-direction-increase'),
                  label: const Center(child: Text('증가 (+)')),
                  selected: _adjustmentIsIncrease,
                  onSelected: (_) =>
                      setState(() => _adjustmentIsIncrease = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  key: const Key('adjustment-direction-decrease'),
                  label: const Center(child: Text('감소 (-)')),
                  selected: !_adjustmentIsIncrease,
                  onSelected: (_) =>
                      setState(() => _adjustmentIsIncrease = false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    // 회차 4 — sheet 진입 정책:
    // - 거래 등록 (create) + non-ADJUSTMENT: showAdjustmentOption=true (sentinel 핀 카드)
    // - 거래 수정 (edit) 의 ADJUSTMENT: adjustmentOnly=true (잔액 조정 1개만)
    // - 그 외: 기존 동작.
    final isEditingAdjustment = isEditing && _isAdjustmentSelected;
    final canShowAdjustment = !isEditing;
    // ADJUSTMENT 일 때 categoryType 은 시트 내부 그룹 필터에 영향. EXPENSE 로 fallback.
    final effectiveType =
        _selectedType == 'ADJUSTMENT' ? 'EXPENSE' : _selectedType;

    showDialog(
      context: context,
      builder: (_) => CategoryGroupSelectorSheet(
        selectedCategoryId: _selectedCategoryId,
        categoryType: effectiveType,
        showAdjustmentOption: canShowAdjustment,
        adjustmentOnly: isEditingAdjustment,
        onSelected: (category) {
          _applyCategorySelection(category, null);
        },
        onSelectedWithGroupName: (category, groupName) {
          _applyCategorySelection(category, groupName);
        },
        onDelete: (id) {
          if (_selectedCategoryId == id) {
            setState(() => _selectedCategoryId = null);
          }
        },
      ),
    );
  }

  /// 회차 4 — sentinel 카테고리 선택 처리. 일반 카테고리는 기존 동작.
  void _applyCategorySelection(Category? category, String? groupName) {
    setState(() {
      if (category?.id == kAdjustmentSentinel) {
        // sentinel 선택 → ADJUSTMENT 모드 자동 전환.
        _selectedType = 'ADJUSTMENT';
        _selectedCategoryId = kAdjustmentSentinel;
        _selectedCategoryDisplayName = '잔액 조정';
      } else {
        _selectedCategoryId = category?.id;
        if (category != null && groupName != null && groupName.isNotEmpty) {
          _selectedCategoryDisplayName = '$groupName > ${category.name}';
        } else {
          _selectedCategoryDisplayName = category?.name;
        }
        // ADJUSTMENT → 일반 카테고리 변경 시 type 도 EXPENSE 로 복귀
        // (사용자가 잔액 조정을 취소하고 다른 카테고리로 변경하는 경우).
        if (_selectedType == 'ADJUSTMENT' && category != null) {
          _selectedType = 'EXPENSE';
        }
      }
    });
  }

  void _showPaymentMethodSelectorSheet(BuildContext context, List<PaymentMethod> methods) {
    final pmBloc = context.read<PaymentMethodBloc>();
    showDialog(
      context: context,
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
                  .indexed
                  .map((e) => SelectorItem(
                        id: e.$2.id,
                        label: e.$2.name,
                        leadingIcon: paymentMethodTypeIcon(e.$2.type),
                        leadingColor: paymentMethodTypeColor(e.$2.type),
                        isDeletable: true,
                        displayOrder: e.$1,
                        group: e.$2.type,
                      ))
                  .toList(),
              selectedId: _selectedPaymentMethodId,
              nullLabel: '선택 안 함',
              favoriteType: 'PAYMENT_METHOD',
              reorderRoute: '/asset-management',
              groupLabels: paymentMethodGroupLabels,
              onSelected: (item) {
                setState(() {
                  _selectedPaymentMethodId = item?.id;
                });
              },
              onEdit: (item) {
                final pm = liveMethods.where((m) => m.id == item.id).firstOrNull;
                if (pm != null) {
                  _showEditPaymentMethodSheet(context, pm);
                }
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
    showDialog(
      context: context,
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
        final picked = await showCalendarPickerDialog(
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
          suffixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(formattedDate),
      ),
    );
  }

  void _showEditPaymentMethodSheet(BuildContext context, PaymentMethod pm) {
    final bloc = context.read<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider<PaymentMethodBloc>.value(
        value: bloc,
        child: PaymentMethodFormSheet(
          paymentMethod: pm,
          onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
            bloc.add(UpdatePaymentMethod(
              id: pm.id,
              name: name,
              settlementDay: settlementDay,
              closingDay: closingDay,
              linkedBankId: linkedBankId,
              clearLinkedBank: linkedBankId == null && pm.linkedBankId != null,
            ));
          },
        ),
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
          onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
            bloc.add(CreatePaymentMethod(
              name: name,
              type: type,
              settlementDay: settlementDay,
              closingDay: closingDay,
              linkedBankId: linkedBankId,
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
      _aiResult = null;
      _aiLoading = false;
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
    // ADJUSTMENT (sentinel 카테고리 포함) 는 카테고리 필수 검증 skip.
    // (회차 3 — special_type_picker_branch 정책 + 회차 4 sentinel 포함)
    bool hasPickerError = false;
    if (!_isAdjustmentSelected && _selectedCategoryId == null) {
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
    // 회차 5 — 응답 지연 시 spinner 무한 방지. 15초 후 자동 해제 + 안내.
    _submitTimeoutTimer?.cancel();
    _submitTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || !_isSubmitting) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.'),
          duration: Duration(seconds: 3),
        ),
      );
    });
    final rawAmount = CurrencyFormatter.parse(_amountController.text.trim())!;
    final description = _descriptionController.text.trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final memo =
        _memoController.text.trim().isEmpty ? null : _memoController.text.trim();
    final bloc = context.read<TransactionBloc>();

    // 회차 4 — sentinel/ADJUSTMENT 처리: type/categoryId/amount 변환.
    final submission = AdjustmentSubmission.resolve(
      selectedType: _selectedType,
      selectedCategoryId: _selectedCategoryId,
      rawAmount: rawAmount,
      isIncrease: _adjustmentIsIncrease,
    );
    final amount = submission.amount;
    final resolvedCategoryId = submission.categoryId;

    if (isEditing) {
      bloc.add(UpdateTransaction(
        id: widget.transactionId!,
        amount: amount,
        description: description,
        categoryId: resolvedCategoryId,
        transactionDate: dateStr,
        memo: memo,
        clearMemo: memo == null,
        paymentMethodId: _selectedPaymentMethodId,
        pocketId: _selectedPocketId,
      ));
    } else {
      bloc.add(CreateTransaction(
        type: submission.type,
        amount: amount,
        description: description,
        categoryId: resolvedCategoryId,
        transactionDate: dateStr,
        memo: memo,
        paymentMethodId: _selectedPaymentMethodId,
        pocketId: _selectedPocketId,
      ));
    }
  }
}
