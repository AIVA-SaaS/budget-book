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

/// 잔액 수정 모드.
/// - [recordAsTransaction] 수입/지출 거래로 기록 (통계 포함). 기존 동작.
/// - [adjustOnly] type=ADJUSTMENT 로 기록 (통계 미포함, 잔액만 보정).
enum _AdjustmentMode { recordAsTransaction, adjustOnly }

class _BalanceAdjustmentSheetState extends State<BalanceAdjustmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  int? _actualBalance;
  bool _isSubmitting = false;
  _AdjustmentMode _mode = _AdjustmentMode.recordAsTransaction;

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

    // Mode 에 따라 type 과 amount 결정.
    // - recordAsTransaction: 양수 차이 → INCOME, 음수 → EXPENSE, amount 는 절대값
    // - adjustOnly: ADJUSTMENT, amount 는 부호 포함 (signed)
    final String type;
    final int amount;
    switch (_mode) {
      case _AdjustmentMode.recordAsTransaction:
        type = _diff > 0 ? 'INCOME' : 'EXPENSE';
        amount = _diff.abs();
      case _AdjustmentMode.adjustOnly:
        type = 'ADJUSTMENT';
        amount = _diff;
    }

    getIt<TransactionBloc>().add(CreateTransaction(
      type: type,
      amount: amount,
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

            // Mode toggle — 통계 포함(수입/지출 기록) vs 미포함(잔액만 조정)
            SegmentedButton<_AdjustmentMode>(
              segments: const [
                ButtonSegment(
                  value: _AdjustmentMode.recordAsTransaction,
                  label: Text('수입/지출 기록', style: TextStyle(fontSize: 12)),
                  icon: Icon(Icons.swap_vert, size: 16),
                ),
                ButtonSegment(
                  value: _AdjustmentMode.adjustOnly,
                  label: Text('잔액만 조정', style: TextStyle(fontSize: 12)),
                  icon: Icon(Icons.tune, size: 16),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (values) {
                if (values.isNotEmpty) {
                  setState(() => _mode = values.first);
                }
              },
            ),
            const SizedBox(height: 6),
            Text(
              _mode == _AdjustmentMode.recordAsTransaction
                  ? '월 수입/지출 통계에 반영됩니다.'
                  : '통계에 반영되지 않고 잔액만 보정합니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),

            // Diff preview
            if (_actualBalance != null && _diff != 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _mode == _AdjustmentMode.adjustOnly
                      ? Colors.grey.shade100
                      : (_diff > 0 ? Colors.blue.shade50 : Colors.red.shade50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _mode == _AdjustmentMode.adjustOnly
                          ? Icons.tune
                          : (_diff > 0 ? Icons.arrow_upward : Icons.arrow_downward),
                      size: 18,
                      color: _mode == _AdjustmentMode.adjustOnly
                          ? Colors.grey.shade700
                          : (_diff > 0 ? Colors.blue.shade700 : Colors.red.shade700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _previewText(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _mode == _AdjustmentMode.adjustOnly
                              ? Colors.grey.shade800
                              : (_diff > 0 ? Colors.blue.shade700 : Colors.red.shade700),
                        ),
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

  String _previewText() {
    final abs = CurrencyFormatter.format(_diff.abs());
    if (_mode == _AdjustmentMode.adjustOnly) {
      return _diff > 0
          ? '+$abs원 잔액 조정 (통계 미반영)'
          : '-$abs원 잔액 조정 (통계 미반영)';
    }
    return _diff > 0
        ? '+$abs원 수입 거래 생성'
        : '-$abs원 지출 거래 생성';
  }
}
