import 'package:flutter/material.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/calculator_amount_field.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';

/// Bottom sheet for adjusting a payment method's balance.
///
/// Shows current balance, accepts actual balance input, and creates
/// an adjustment transaction for the difference.
class BalanceAdjustmentSheet extends StatefulWidget {
  final String paymentMethodId;
  final String paymentMethodName;
  final int currentBalance;

  const BalanceAdjustmentSheet({
    super.key,
    required this.paymentMethodId,
    required this.paymentMethodName,
    required this.currentBalance,
  });

  /// Shows the bottom sheet and returns true if an adjustment was made.
  static Future<bool?> show(
    BuildContext context, {
    required String paymentMethodId,
    required String paymentMethodName,
    required int currentBalance,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BalanceAdjustmentSheet(
        paymentMethodId: paymentMethodId,
        paymentMethodName: paymentMethodName,
        currentBalance: currentBalance,
      ),
    );
  }

  @override
  State<BalanceAdjustmentSheet> createState() => _BalanceAdjustmentSheetState();
}

class _BalanceAdjustmentSheetState extends State<BalanceAdjustmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  int? _actualBalance;
  bool _isSubmitting = false;

  int get _diff => (_actualBalance ?? widget.currentBalance) - widget.currentBalance;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onTextChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final parsed = CurrencyFormatter.parse(_amountController.text);
    if (parsed != _actualBalance) {
      setState(() => _actualBalance = parsed);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_diff == 0) return;

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    getIt<TransactionBloc>().add(CreateTransaction(
      type: _diff > 0 ? 'INCOME' : 'EXPENSE',
      amount: _diff.abs(),
      description: '잔액 수정',
      transactionDate: dateStr,
      paymentMethodId: widget.paymentMethodId,
    ));

    // Refresh related blocs
    getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
    getIt<DashboardBloc>().add(LoadDashboard(year: now.year, month: now.month));

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              '잔액 수정',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.paymentMethodName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),

            // Current balance (read-only)
            Text(
              '현재 잔액',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${CurrencyFormatter.format(widget.currentBalance)}원',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // Actual balance input
            CalculatorAmountField(
              controller: _amountController,
              onAmountChanged: (val) => setState(() => _actualBalance = val),
              decoration: const InputDecoration(
                labelText: '실제 잔액',
                hintText: '실제 잔액을 입력하세요',
                suffixText: '원',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '금액을 입력하세요';
                final parsed = CurrencyFormatter.parse(value);
                if (parsed == null) return '올바른 금액을 입력하세요';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Diff preview
            if (_actualBalance != null && _diff != 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _diff > 0
                      ? Colors.blue.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _diff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 18,
                      color: _diff > 0 ? Colors.blue.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _diff > 0
                          ? '+${CurrencyFormatter.format(_diff)}원 수입 거래 생성'
                          : '-${CurrencyFormatter.format(_diff.abs())}원 지출 거래 생성',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _diff > 0 ? Colors.blue.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            if (_actualBalance != null && _diff == 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '현재 잔액과 동일합니다',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting || _actualBalance == null || _diff == 0
                    ? null
                    : _submit,
                child: const Text('조정'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
