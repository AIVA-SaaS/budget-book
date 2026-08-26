import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/calculator_amount_field.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import '../../core/theme/bb_scale.dart';

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
  // 회차 1 (2026-05-07) — payment_method_page Dialog 통합 시 메모 기능 이관.
  // 잔액만 조정 모드에서 사유 기록용. recordAsTransaction 모드에서도 옵션 메모.
  final _memoController = TextEditingController();
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
    _memoController.dispose();
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

    final memo = _memoController.text.trim();
    // 회차 1 (2026-05-10) — Z2 race fix.
    // 이전: POST CreateTransaction 과 GET LoadPaymentMethods 가 병렬 발사 + 시트
    // 즉시 pop. GET 이 POST commit 전 도착 시 OLD balance 반환 → 화면 stale.
    // 이제 CreateTransaction 만 dispatch + 시트는 BlocListener<TransactionBloc>
    // 가 TransactionLoaded(success) 수신 후에 reload + pop 처리. 순차 보장.
    getIt<TransactionBloc>().add(CreateTransaction(
      type: type,
      amount: amount,
      description: '잔액 수정',
      transactionDate: dateStr,
      paymentMethodId: widget.paymentMethodId,
      memo: memo.isEmpty ? null : memo,
    ));
  }

  void _onTransactionState(BuildContext context, TransactionState state) {
    if (!_isSubmitting) return;
    if (state is TransactionLoaded && state.operationError != null) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.operationError!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    if (state is TransactionLoaded) {
      // POST 가 commit 된 시점이 보장된 후에 reload 발사.
      getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
      final monthState = getIt<MonthCubit>().state;
      getIt<DashboardBloc>().add(
          LoadDashboard(year: monthState.year, month: monthState.month));
      _isSubmitting = false;
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    if (state is TransactionError) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<TransactionBloc, TransactionState>(
      bloc: getIt<TransactionBloc>(),
      listener: _onTransactionState,
      child: Padding(
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
            context.bbSpace.gapV(BbSpaceToken.xxl),

            // Title
            Text(
              '잔액 수정',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            context.bbSpace.gapV(BbSpaceToken.xs),
            Text(
              widget.paymentMethodName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.xxl),

            // Current balance (read-only)
            Text(
              '현재 잔액',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.xs),
            Text(
              '${CurrencyFormatter.format(widget.currentBalance)}원',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            context.bbSpace.gapV(BbSpaceToken.xxl),

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
            context.bbSpace.gapV(BbSpaceToken.xl),

            // Mode toggle — 통계 포함(수입/지출 기록) vs 미포함(잔액만 조정)
            SegmentedButton<_AdjustmentMode>(
              segments: [
                ButtonSegment(
                  value: _AdjustmentMode.recordAsTransaction,
                  label: Text('수입/지출 기록', style: TextStyle(fontSize: context.bbType.label)),
                  icon: Icon(Icons.swap_vert, size: context.bbType.iconSm),
                ),
                ButtonSegment(
                  value: _AdjustmentMode.adjustOnly,
                  label: Text('잔액만 조정', style: TextStyle(fontSize: context.bbType.label)),
                  icon: Icon(Icons.tune, size: context.bbType.iconSm),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (values) {
                if (values.isNotEmpty) {
                  setState(() => _mode = values.first);
                }
              },
            ),
            context.bbSpace.gapV(BbSpaceToken.md),
            Text(
              _mode == _AdjustmentMode.recordAsTransaction
                  ? '월 수입/지출 통계에 반영됩니다.'
                  : '통계에 반영되지 않고 잔액만 보정합니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),

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
                          fontSize: context.bbType.section,
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
                    Icon(Icons.check_circle, size: context.bbType.iconSm, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '현재 잔액과 동일합니다',
                      style: TextStyle(
                        fontSize: context.bbType.section,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            context.bbSpace.gapV(BbSpaceToken.xl),

            // Memo (optional) — Dialog 통합 시 이관된 메모 입력.
            TextFormField(
              controller: _memoController,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                hintText: '잔액 수정 사유',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.lg),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting || _actualBalance == null || _diff == 0
                    ? null
                    : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('조정'),
              ),
            ),
          ],
        ),
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
