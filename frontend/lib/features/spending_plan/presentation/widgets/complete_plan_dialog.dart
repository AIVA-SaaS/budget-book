import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';

/// Result from the complete plan dialog.
class CompletePlanResult {
  final int actualAmount;
  final bool createTransaction;
  final String transactionDate;
  final String? description;
  final String? categoryId;
  final String? paymentMethodId;

  const CompletePlanResult({
    required this.actualAmount,
    required this.createTransaction,
    required this.transactionDate,
    this.description,
    this.categoryId,
    this.paymentMethodId,
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
  late final TextEditingController _amountController;
  late DateTime _transactionDate;
  bool _createTransaction = true;
  String? _categoryId;
  String? _paymentMethodId;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: CurrencyFormatter.format(widget.plan.amount),
    );
    _transactionDate = widget.plan.targetDate != null
        ? DateTime.tryParse(widget.plan.targetDate!) ?? DateTime.now()
        : DateTime.now();
    _categoryId = widget.plan.categoryId;
    _paymentMethodId = widget.plan.paymentMethodId;
  }

  @override
  void dispose() {
    _amountController.dispose();
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
    final amount = CurrencyFormatter.parse(_amountController.text);
    if (amount == null || amount <= 0) return;

    Navigator.of(context).pop(CompletePlanResult(
      actualAmount: amount,
      createTransaction: _createTransaction,
      transactionDate: DateFormat('yyyy-MM-dd').format(_transactionDate),
      description: widget.plan.name,
      categoryId: _categoryId,
      paymentMethodId: _paymentMethodId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('계획 완료'),
      content: SingleChildScrollView(
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
            const SizedBox(height: 16),

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
            ),
            const SizedBox(height: 12),

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
            const SizedBox(height: 12),

            // Create transaction checkbox
            CheckboxListTile(
              value: _createTransaction,
              onChanged: (value) =>
                  setState(() => _createTransaction = value ?? true),
              title: const Text('거래로 자동 등록'),
              subtitle: const Text('지출 거래가 자동 생성됩니다'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),

            if (_createTransaction) ...[
              const SizedBox(height: 8),
              // Payment method
              if (_methods.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethodId,
                  decoration: const InputDecoration(
                    labelText: '결제수단',
                    prefixIcon: Icon(Icons.credit_card),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('선택 안 함'),
                    ),
                    ..._methods.map((pm) => DropdownMenuItem(
                          value: pm.id,
                          child: Text(pm.name),
                        )),
                  ],
                  onChanged: (value) =>
                      setState(() => _paymentMethodId = value),
                ),
              const SizedBox(height: 8),
              // Category
              if (_categories.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: '카테고리',
                    prefixIcon: Icon(Icons.label),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('선택 안 함'),
                    ),
                    ..._categories.map((cat) => DropdownMenuItem(
                          value: cat.id,
                          child: Text(cat.name),
                        )),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
            ],
          ],
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
