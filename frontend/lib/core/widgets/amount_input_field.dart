import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';

/// A reusable amount input field with +/- calculation buttons and a clear button.
///
/// Wraps a [TextFormField] with [CurrencyInputFormatter] and adds suffix icon
/// buttons for adding, subtracting, and clearing the amount.
class AmountInputField extends StatelessWidget {
  /// Controller for the text field. Required.
  final TextEditingController controller;

  /// Label text shown above the field.
  final String labelText;

  /// Optional prefix icon (defaults to [Icons.payments]).
  final IconData prefixIcon;

  /// Optional suffix text (defaults to '원').
  final String suffixText;

  /// Optional helper text shown below the field.
  final String? helperText;

  /// Optional validator for the form field.
  final FormFieldValidator<String>? validator;

  /// Additional input formatters applied before [CurrencyInputFormatter].
  final List<TextInputFormatter>? extraFormatters;

  /// Whether to include [FilteringTextInputFormatter.digitsOnly] before
  /// [CurrencyInputFormatter]. Some fields already use this.
  final bool filterDigitsOnly;

  const AmountInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.prefixIcon = Icons.payments,
    this.suffixText = '원',
    this.helperText,
    this.validator,
    this.extraFormatters,
    this.filterDigitsOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatters = <TextInputFormatter>[
      if (filterDigitsOnly) FilteringTextInputFormatter.digitsOnly,
      ...?extraFormatters,
      CurrencyInputFormatter(),
    ];

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        suffixText: suffixText,
        prefixIcon: Icon(prefixIcon),
        helperText: helperText,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: Icons.add,
              tooltip: '더하기',
              onPressed: () => _showCalculationDialog(context, isAdd: true),
            ),
            _ActionButton(
              icon: Icons.remove,
              tooltip: '빼기',
              onPressed: () => _showCalculationDialog(context, isAdd: false),
            ),
            _ActionButton(
              icon: Icons.close,
              tooltip: '지우기',
              onPressed: _clearAmount,
            ),
          ],
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: formatters,
      validator: validator,
    );
  }

  void _clearAmount() {
    controller.text = '0';
    // Set cursor to end
    controller.selection = const TextSelection.collapsed(offset: 1);
  }

  Future<void> _showCalculationDialog(
    BuildContext context, {
    required bool isAdd,
  }) async {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _AmountCalcDialog(isAdd: isAdd),
    );

    if (result == null || result <= 0) return;

    final current = CurrencyFormatter.parse(controller.text) ?? 0;
    final newAmount = isAdd ? current + result : max(0, current - result);
    controller.text = CurrencyFormatter.format(newAmount);
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
  }
}

/// Small icon button used inside the suffix area.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 16,
      ),
    );
  }
}

/// Dialog for entering an amount to add or subtract.
class _AmountCalcDialog extends StatefulWidget {
  final bool isAdd;

  const _AmountCalcDialog({required this.isAdd});

  @override
  State<_AmountCalcDialog> createState() => _AmountCalcDialogState();
}

class _AmountCalcDialogState extends State<_AmountCalcDialog> {
  final _dialogController = TextEditingController();
  String _hint = '';

  @override
  void initState() {
    super.initState();
    _dialogController.addListener(_updateHint);
  }

  void _updateHint() {
    final parsed = CurrencyFormatter.parse(_dialogController.text);
    final newHint = (parsed != null && parsed >= 10000)
        ? CurrencyFormatter.toKoreanUnit(parsed)
        : '';
    if (newHint != _hint) {
      setState(() => _hint = newHint);
    }
  }

  @override
  void dispose() {
    _dialogController.removeListener(_updateHint);
    _dialogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isAdd ? '금액 더하기' : '금액 빼기';

    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: _dialogController,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [CurrencyInputFormatter()],
        decoration: InputDecoration(
          hintText: '금액 입력',
          suffixText: '원',
          helperText: _hint.isNotEmpty ? _hint : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isAdd ? '더하기' : '빼기'),
        ),
      ],
    );
  }

  void _submit() {
    final amount = CurrencyFormatter.parse(_dialogController.text);
    Navigator.of(context).pop(amount);
  }
}
