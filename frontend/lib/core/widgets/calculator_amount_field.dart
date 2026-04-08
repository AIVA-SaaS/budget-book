import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';

/// A TextFormField for amount input that supports simple arithmetic (+/-).
///
/// When the user types `+` or `-`, it switches to expression mode,
/// showing a preview of the evaluated result below the field.
/// On focus loss or pressing `=`, the expression is evaluated
/// and the result replaces the input.
class CalculatorAmountField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration? decoration;
  final String? Function(String?)? validator;
  final ValueChanged<int>? onAmountChanged;
  final String? helperText;

  const CalculatorAmountField({
    super.key,
    required this.controller,
    this.decoration,
    this.validator,
    this.onAmountChanged,
    this.helperText,
  });

  @override
  State<CalculatorAmountField> createState() => _CalculatorAmountFieldState();
}

class _CalculatorAmountFieldState extends State<CalculatorAmountField> {
  final FocusNode _focusNode = FocusNode();
  bool _isExpressionMode = false;
  int? _previewResult;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isExpressionMode) {
      _evaluateAndReplace();
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final hasOperator = text.contains('+') || text.contains('-');

    // Detect if this is entering expression mode (has operator beyond just digits+commas)
    // But the first character '-' does not count (negative number, though we don't support negative)
    final cleanText = text.replaceAll(',', '');
    final isExpression = hasOperator && cleanText.length > 1 &&
        RegExp(r'\d[+\-]').hasMatch(cleanText);

    if (isExpression != _isExpressionMode) {
      setState(() {
        _isExpressionMode = isExpression;
      });
    }

    if (isExpression) {
      final result = evaluateExpression(cleanText);
      if (result != _previewResult) {
        setState(() => _previewResult = result);
      }
    } else {
      if (_previewResult != null) {
        setState(() => _previewResult = null);
      }
    }
  }

  void _evaluateAndReplace() {
    final text = widget.controller.text.replaceAll(',', '');
    final result = evaluateExpression(text);
    if (result != null && result > 0) {
      final formatted = CurrencyFormatter.format(result);
      widget.controller.text = formatted;
      widget.controller.selection =
          TextSelection.collapsed(offset: formatted.length);
      widget.onAmountChanged?.call(result);
    } else if (result != null && result <= 0) {
      // Negative or zero result: set to empty so validation catches it
      widget.controller.text = '';
    }
    setState(() {
      _isExpressionMode = false;
      _previewResult = null;
    });
  }

  /// Evaluates a simple arithmetic expression with + and -.
  /// Input should have commas already stripped.
  /// e.g. "50000+3000-500" → 52500
  static int? evaluateExpression(String expr) {
    if (expr.isEmpty) return null;

    // Split by + and - while keeping the operators
    final tokens = <String>[];
    var current = '';
    for (var i = 0; i < expr.length; i++) {
      final ch = expr[i];
      if ((ch == '+' || ch == '-') && i > 0) {
        tokens.add(current);
        current = ch; // start new token with operator
      } else {
        current += ch;
      }
    }
    if (current.isNotEmpty) tokens.add(current);

    var sum = 0;
    for (final token in tokens) {
      final val = int.tryParse(token);
      if (val == null) return null;
      sum += val;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final baseDecoration = widget.decoration ?? const InputDecoration();

    // Build helper text: show preview when in expression mode, otherwise original helper
    String? helperText;
    if (_isExpressionMode && _previewResult != null) {
      final prefix = _previewResult! <= 0 ? '' : '= ';
      helperText =
          '$prefix${CurrencyFormatter.format(_previewResult!)}원';
    } else {
      helperText = widget.helperText;
    }

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: baseDecoration.copyWith(
        helperText: helperText != null && helperText.isNotEmpty
            ? helperText
            : null,
        helperStyle: _isExpressionMode
            ? TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              )
            : null,
        suffixIcon: widget.controller.text.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isExpressionMode)
                    IconButton(
                      icon: Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: '계산',
                      onPressed: _evaluateAndReplace,
                    ),
                  GestureDetector(
                    onLongPress: () {
                      widget.controller.clear();
                    },
                    child: IconButton(
                      icon: const Icon(Icons.backspace_outlined, size: 20),
                      tooltip: '지우기 (길게 누르면 전체 삭제)',
                      onPressed: () {
                        final text = widget.controller.text;
                        if (text.isNotEmpty) {
                          // Remove last character, then reformat if needed
                          final newText = text.substring(0, text.length - 1);
                          if (!_isExpressionMode) {
                            // In normal mode, strip commas, remove last digit, reformat
                            final digits =
                                newText.replaceAll(RegExp(r'[^\d]'), '');
                            if (digits.isEmpty) {
                              widget.controller.text = '';
                            } else {
                              final num = int.tryParse(digits);
                              if (num != null) {
                                final formatted = CurrencyFormatter.format(num);
                                widget.controller.text = formatted;
                                widget.controller.selection =
                                    TextSelection.collapsed(
                                        offset: formatted.length);
                              }
                            }
                          } else {
                            widget.controller.text = newText;
                            widget.controller.selection =
                                TextSelection.collapsed(
                                    offset: newText.length);
                          }
                        }
                      },
                    ),
                  ),
                ],
              )
            : null,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [_CalculatorInputFormatter()],
      validator: widget.validator,
    );
  }
}

/// Input formatter that allows digits, commas, +, and -.
/// In normal mode (no operators), it formats with commas.
/// In expression mode (has operators), it allows raw input with operators.
class _CalculatorInputFormatter extends TextInputFormatter {
  static const _numberFormat = CurrencyFormatter.format;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final text = newValue.text;

    // Only allow digits, commas, +, -
    final cleaned = text.replaceAll(RegExp(r'[^\d,+\-]'), '');
    if (cleaned != text) {
      return TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }

    // Check if expression mode (has + or - after a digit)
    final noCommas = text.replaceAll(',', '');
    final isExpression =
        noCommas.length > 1 && RegExp(r'\d[+\-]').hasMatch(noCommas);

    if (isExpression) {
      // In expression mode: format each numeric segment with commas
      // e.g. "50000+3000" → "50,000+3,000"
      final formatted = _formatExpression(noCommas);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    // Normal mode: standard comma formatting
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(digits);
    if (number == null) return oldValue;

    final formatted = _numberFormat(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Formats an expression like "50000+3000-500" → "50,000+3,000-500"
  static String _formatExpression(String expr) {
    final buffer = StringBuffer();
    var currentNum = '';

    for (var i = 0; i < expr.length; i++) {
      final ch = expr[i];
      if ((ch == '+' || ch == '-') && i > 0) {
        // Format the accumulated number
        final num = int.tryParse(currentNum);
        if (num != null) {
          buffer.write(_numberFormat(num));
        } else {
          buffer.write(currentNum);
        }
        buffer.write(ch);
        currentNum = '';
      } else {
        currentNum += ch;
      }
    }

    // Format the last number segment
    if (currentNum.isNotEmpty) {
      final num = int.tryParse(currentNum);
      if (num != null) {
        buffer.write(_numberFormat(num));
      } else {
        buffer.write(currentNum);
      }
    }

    return buffer.toString();
  }
}
