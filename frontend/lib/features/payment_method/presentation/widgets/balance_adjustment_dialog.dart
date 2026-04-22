import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';

/// "잔액 수정" (balance adjustment) dialog — Phase 22 §2.5.
///
/// Shows current app balance vs. user-entered actual balance, then POSTs a
/// Transaction with `type=ADJUSTMENT` and `amount = actual - current` (signed)
/// so the payment method's balance reconciles without distorting the
/// income/expense statistics.
///
/// - The dialog is concerned only with submission; refreshing state is left
///   to the caller (it typically dispatches `LoadPaymentMethods` and a
///   transaction reload on success).
class BalanceAdjustmentDialog extends StatefulWidget {
  final PaymentMethod paymentMethod;

  /// Fires after a successful submit so the caller can refresh state.
  final VoidCallback? onSuccess;

  const BalanceAdjustmentDialog({
    super.key,
    required this.paymentMethod,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required PaymentMethod paymentMethod,
    VoidCallback? onSuccess,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => BalanceAdjustmentDialog(
        paymentMethod: paymentMethod,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<BalanceAdjustmentDialog> createState() =>
      _BalanceAdjustmentDialogState();
}

class _BalanceAdjustmentDialogState extends State<BalanceAdjustmentDialog> {
  final _actualController = TextEditingController();
  final _memoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  int get _currentBalance => widget.paymentMethod.balance ?? 0;

  int? get _actualBalance {
    final text = _actualController.text.trim();
    if (text.isEmpty) return null;
    // Allow optional leading '-' for negative balances.
    final negative = text.startsWith('-');
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;
    final parsed = int.tryParse(digits);
    if (parsed == null) return null;
    return negative ? -parsed : parsed;
  }

  int? get _delta {
    final actual = _actualBalance;
    if (actual == null) return null;
    return actual - _currentBalance;
  }

  @override
  void dispose() {
    _actualController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final delta = _delta;
    if (delta == null) return;
    if (delta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('차이가 없어 조정이 필요하지 않습니다')),
      );
      return;
    }

    setState(() => _submitting = true);
    final memo = _memoController.text.trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await getIt<ApiClient>().dio.post(
        ApiEndpoints.transactions,
        data: {
          'type': 'ADJUSTMENT',
          'amount': delta,
          'description': '잔액 수정 (${widget.paymentMethod.name})',
          'transactionDate': dateStr,
          'paymentMethodId': widget.paymentMethod.id,
          if (memo.isNotEmpty) 'memo': memo,
          // category is intentionally omitted (nullable for ADJUSTMENT).
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('잔액이 조정되었습니다')),
      );
      widget.onSuccess?.call();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e.response?.data is Map
          ? ((e.response?.data as Map)['message']?.toString() ?? '잔액 조정에 실패했습니다')
          : '잔액 조정에 실패했습니다';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('잔액 조정에 실패했습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final delta = _delta;
    final deltaText = delta == null
        ? '-'
        : (delta >= 0
            ? '+${CurrencyFormatter.format(delta)}원'
            : '-${CurrencyFormatter.format(delta.abs())}원');
    final deltaColor = delta == null
        ? Theme.of(context).colorScheme.onSurface
        : delta > 0
            ? Colors.green.shade700
            : delta < 0
                ? Colors.red.shade700
                : Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      title: Text('잔액 수정 — ${widget.paymentMethod.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoRow(
              label: '현재 잔액',
              valueText: '${CurrencyFormatter.format(_currentBalance)}원',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _actualController,
              decoration: const InputDecoration(
                labelText: '실제 잔액',
                suffixText: '원',
                isDense: true,
                hintText: '예: 120,000 (음수는 "-" 로 시작)',
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                // Allow digits, commas, and a leading '-' for negative balances.
                FilteringTextInputFormatter.allow(RegExp(r'^-?[\d,]*')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '실제 잔액을 입력하세요';
                }
                if (_actualBalance == null) {
                  return '유효한 금액을 입력하세요';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: '조정 금액',
              valueText: deltaText,
              valueColor: deltaColor,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '사유 (선택)',
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              '통계(수입/지출)에는 포함되지 않고, 잔액만 보정합니다.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String valueText;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.valueText,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7),
          ),
        ),
        Text(
          valueText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
