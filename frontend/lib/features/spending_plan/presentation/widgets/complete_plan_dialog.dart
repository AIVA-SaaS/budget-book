import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';
import 'package:budget_book/core/widgets/category_group_selector_sheet.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';
import 'package:budget_book/core/utils/payment_method_helpers.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/payment_method_form_sheet.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart' as tx;
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import '../../../../core/theme/bb_scale.dart';

/// Result from the complete plan dialog.
class CompletePlanResult {
  final int actualAmount;
  final String transactionDate;
  final String description;
  final String? categoryId;
  final String? paymentMethodId;
  /// If set, link to existing transaction instead of creating new one
  final String? linkedTransactionId;

  const CompletePlanResult({
    required this.actualAmount,
    required this.transactionDate,
    required this.description,
    this.categoryId,
    this.paymentMethodId,
    this.linkedTransactionId,
  });
}

/// Shows a dialog to complete a spending plan, optionally creating a transaction.
Future<CompletePlanResult?> showCompletePlanDialog(
  BuildContext context,
  SpendingPlan plan,
) {
  return showDialog<CompletePlanResult>(
    context: context,
    builder: (ctx) => _CompletePlanDialog(plan: plan),
  );
}

class _CompletePlanDialog extends StatefulWidget {
  final SpendingPlan plan;

  const _CompletePlanDialog({required this.plan});

  @override
  State<_CompletePlanDialog> createState() => _CompletePlanDialogState();
}

class _CompletePlanDialogState extends State<_CompletePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late DateTime _transactionDate;
  String? _categoryId;
  String? _categoryDisplayName;
  String? _paymentMethodId;
  bool _linkExisting = false;
  tx.Transaction? _linkedTransaction;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: CurrencyFormatter.format(widget.plan.amount),
    );
    _descriptionController = TextEditingController(
      text: widget.plan.name,
    );
    _transactionDate = widget.plan.targetDate != null
        ? DateTime.tryParse(widget.plan.targetDate!) ?? DateTime.now()
        : DateTime.now();
    _categoryId = widget.plan.categoryId;
    _categoryDisplayName = widget.plan.categoryName;
    _paymentMethodId = widget.plan.paymentMethodId;

    // Ensure categories and payment methods are loaded for selectors
    final cgBloc = getIt<CategoryGroupBloc>();
    if (cgBloc.state is! CategoryGroupLoaded) {
      cgBloc.add(const LoadCategoryGroups());
    }
    final pmBloc = getIt<PaymentMethodBloc>();
    if (pmBloc.state is PaymentMethodInitial) {
      pmBloc.add(const LoadPaymentMethods());
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<PaymentMethod> get _methods {
    final state = getIt<PaymentMethodBloc>().state;
    return state is PaymentMethodLoaded ? state.activePaymentMethods : [];
  }

  List<Category> get _categories {
    final state = getIt<CategoryBloc>().state;
    return state is CategoryLoaded
        ? state.categories.where((c) => c.type == 'EXPENSE').toList()
        : [];
  }

  Future<void> _selectDate() async {
    final picked = await showCalendarPickerDialog(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() => _transactionDate = picked);
    }
  }

  void _submit() {
    if (_linkExisting && _linkedTransaction != null) {
      Navigator.of(context).pop(CompletePlanResult(
        actualAmount: _linkedTransaction!.amount,
        transactionDate: _linkedTransaction!.transactionDate,
        description: _linkedTransaction!.description,
        categoryId: _linkedTransaction!.category?.id,
        paymentMethodId: _linkedTransaction!.paymentMethodId,
        linkedTransactionId: _linkedTransaction!.id,
      ));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final amount = CurrencyFormatter.parse(_amountController.text)!;
    final description = _descriptionController.text.trim();

    Navigator.of(context).pop(CompletePlanResult(
      actualAmount: amount,
      transactionDate: DateFormat('yyyy-MM-dd').format(_transactionDate),
      description: description,
      categoryId: _categoryId,
      paymentMethodId: _paymentMethodId,
    ));
  }

  void _showCategorySelectorSheet() {
    showDialog(
      context: context,
      builder: (_) => CategoryGroupSelectorSheet(
        selectedCategoryId: _categoryId,
        categoryType: 'EXPENSE',
        onSelected: (category) {
          setState(() {
            _categoryId = category?.id;
            _categoryDisplayName = null;
          });
        },
        onSelectedWithGroupName: (category, groupName) {
          setState(() {
            _categoryId = category?.id;
            if (category != null && groupName != null && groupName.isNotEmpty) {
              _categoryDisplayName = '$groupName > ${category.name}';
            } else {
              _categoryDisplayName = category?.name;
            }
          });
        },
        onDelete: (id) {
          if (_categoryId == id) {
            setState(() {
              _categoryId = null;
              _categoryDisplayName = null;
            });
          }
        },
      ),
    );
  }

  void _showPaymentMethodSelectorSheet() {
    final pmBloc = getIt<PaymentMethodBloc>();
    showDialog(
      context: context,
      builder: (_) => BlocProvider<PaymentMethodBloc>.value(
        value: pmBloc,
        child: BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
          builder: (sheetContext, pmState) {
            final liveMethods = pmState is PaymentMethodLoaded
                ? pmState.activePaymentMethods
                : _methods;
            return ItemSelectorSheet(
              title: '결제수단 선택',
              items: liveMethods
                  .indexed
                  .map((e) => SelectorItem(
                        id: e.$2.id,
                        label: e.$2.name,
                        leadingIcon: paymentMethodTypeIcon(e.$2.type),
                        leadingColor: paymentMethodTypeColor(context, e.$2.type),
                        isDeletable: true,
                        displayOrder: e.$1,
                        group: e.$2.type,
                      ))
                  .toList(),
              selectedId: _paymentMethodId,
              nullLabel: '선택 안 함',
              favoriteType: 'PAYMENT_METHOD',
              reorderRoute: '/asset-management',
              groupLabels: paymentMethodGroupLabels,
              onSelected: (item) {
                setState(() {
                  _paymentMethodId = item?.id;
                });
              },
              onEdit: (item) {
                final pm = liveMethods.where((m) => m.id == item.id).firstOrNull;
                if (pm != null) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => BlocProvider<PaymentMethodBloc>.value(
                      value: pmBloc,
                      child: PaymentMethodFormSheet(
                        paymentMethod: pm,
                        onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
                          pmBloc.add(UpdatePaymentMethod(
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
              },
              onDelete: (id) {
                pmBloc.add(DeletePaymentMethod(id));
                if (_paymentMethodId == id) {
                  setState(() => _paymentMethodId = null);
                }
              },
              onCreate: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BlocProvider<PaymentMethodBloc>.value(
                    value: pmBloc,
                    child: PaymentMethodFormSheet(
                      onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
                        pmBloc.add(CreatePaymentMethod(
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
              },
              createLabel: '+ 새 결제수단',
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransactionSelector() {
    final txBloc = getIt<TransactionBloc>();
    final txState = txBloc.state;
    final transactions = txState is TransactionLoaded ? txState.transactions : <tx.Transaction>[];

    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('현재 월의 거래를 먼저 로드해주세요'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_linkedTransaction != null) ...[
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              dense: true,
              leading: Icon(
                _linkedTransaction!.isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                color: _linkedTransaction!.isExpense ? Colors.red : Colors.blue,
                size: context.bbType.iconSm,
              ),
              title: Text(_linkedTransaction!.description, style: TextStyle(fontSize: context.bbType.section)),
              subtitle: Text(
                '${CurrencyFormatter.format(_linkedTransaction!.amount)}원 · ${_linkedTransaction!.transactionDate}',
                style: TextStyle(fontSize: context.bbType.label),
              ),
              trailing: IconButton(
                icon: Icon(Icons.close, size: context.bbType.iconMd),
                onPressed: () => setState(() => _linkedTransaction = null),
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final t = transactions[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    t.isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                    color: t.isExpense ? Colors.red : Colors.blue,
                    size: context.bbType.iconSm,
                  ),
                  title: Text(t.description, style: TextStyle(fontSize: context.bbType.body)),
                  subtitle: Text(
                    '${CurrencyFormatter.format(t.amount)}원 · ${t.transactionDate}',
                    style: TextStyle(fontSize: context.bbType.label),
                  ),
                  onTap: () => setState(() => _linkedTransaction = t),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  String? get _paymentMethodDisplayName {
    if (_paymentMethodId == null) return null;
    return _methods
        .where((pm) => pm.id == _paymentMethodId)
        .map((pm) => pm.name)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('계획 완료'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.plan.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '계획 금액: ${CurrencyFormatter.format(widget.plan.amount)}원',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),

            // Toggle: new transaction vs link existing
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('새 거래 생성')),
                ButtonSegment(value: true, label: Text('기존 거래 연결')),
              ],
              selected: {_linkExisting},
              onSelectionChanged: (set) => setState(() {
                _linkExisting = set.first;
                _linkedTransaction = null;
              }),
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),

            if (_linkExisting) ...[
              // Transaction search/select
              _buildTransactionSelector(),
            ] else ...[

            // Actual amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '실제 사용 금액',
                suffixText: '원',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return '금액을 입력해주세요';
                final amount = CurrencyFormatter.parse(value);
                if (amount == null || amount <= 0) return '유효한 금액을 입력하세요';
                return null;
              },
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '거래 내용',
                hintText: '실제 결제 내용을 입력하세요',
                isDense: true,
              ),
              maxLength: 255,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '거래 내용을 입력해주세요';
                }
                return null;
              },
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),

            // Date picker
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '거래일',
                  prefixIcon: Icon(Icons.calendar_today),
                  isDense: true,
                ),
                child: Text(
                  DateFormat('yyyy년 M월 d일', 'ko').format(_transactionDate),
                ),
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),

            // Payment method selector
            ItemSelectorField(
              label: '결제수단',
              selectedLabel: _paymentMethodDisplayName,
              prefixIcon: Icons.credit_card,
              placeholder: '선택 안 함',
              onTap: _showPaymentMethodSelectorSheet,
            ),
            context.bbSpace.gapV(BbSpaceToken.lg),
            // Category selector
            ItemSelectorField(
              label: '카테고리',
              selectedLabel: _categoryDisplayName ?? (_categoryId != null
                  ? _categories.where((c) => c.id == _categoryId).map((c) => c.name).firstOrNull ?? '(삭제됨)'
                  : null),
              prefixIcon: Icons.category,
              placeholder: '선택 안 함',
              onTap: _showCategorySelectorSheet,
            ),
            ], // end of "새 거래 생성" section
          ],
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('완료'),
        ),
      ],
    );
  }
}
