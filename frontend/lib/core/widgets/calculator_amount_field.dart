import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';

/// A TextFormField for amount input that supports arithmetic (+ - * /) with
/// parentheses, and a calculator popup for mobile (where number-only keyboards
/// block operators).
///
/// 회차 1 (2026-05-06):
///   - 0원 회귀 fix: `5-5=0` 이 비워지지 않고 `0` 으로 표시됨. 음수만 거부.
///   - 괄호 지원: shunting-yard 기반 evaluator, `(1+2)*3` 가능.
///   - 모바일 계산기 popup: suffixIcon 의 [Icons.calculate] 클릭 → 버튼 그리드 dialog.
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
    final cleanText = text.replaceAll(',', '');
    final isExpression = _looksLikeExpression(cleanText);

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
    // 회차 1 (2026-05-06) — 0원 회귀 fix: 0 은 정상 결과로 간주, 음수만 비움.
    if (result != null && result >= 0) {
      final formatted = CurrencyFormatter.format(result);
      widget.controller.text = formatted;
      widget.controller.selection =
          TextSelection.collapsed(offset: formatted.length);
      widget.onAmountChanged?.call(result);
    } else if (result != null && result < 0) {
      widget.controller.text = '';
    }
    setState(() {
      _isExpressionMode = false;
      _previewResult = null;
    });
  }

  /// True if the cleaned input looks like an expression that should be
  /// evaluated (contains an operator after a digit, or has parentheses).
  static bool _looksLikeExpression(String cleanText) {
    if (cleanText.length <= 1) return false;
    if (cleanText.contains('(') || cleanText.contains(')')) return true;
    return RegExp(r'\d[+\-*/]').hasMatch(cleanText);
  }

  /// Evaluates an arithmetic expression with `+ - * /` and parentheses using a
  /// shunting-yard algorithm. Input should have commas already stripped.
  /// Returns null on syntax errors or division-by-zero.
  ///
  /// Examples:
  ///   `(1+2)*3` → 9
  ///   `((1+2)*3)/9` → 1
  ///   `1+(2*(3+4))` → 15
  ///   `5-5` → 0  (회차 1 fix — 이전 evaluator 도 0 반환했으나 caller 가 비웠음)
  static int? evaluateExpression(String expr) {
    if (expr.isEmpty) return null;
    if (expr.length > 100) return null;

    // Tokenize.
    final tokens = <String>[];
    var current = StringBuffer();
    for (var i = 0; i < expr.length; i++) {
      final ch = expr[i];
      if (RegExp(r'[0-9.]').hasMatch(ch)) {
        current.write(ch);
      } else if ('+-*/()'.contains(ch)) {
        if (current.isNotEmpty) {
          tokens.add(current.toString());
          current = StringBuffer();
        }
        tokens.add(ch);
      } else {
        return null;
      }
    }
    if (current.isNotEmpty) tokens.add(current.toString());
    if (tokens.isEmpty) return null;

    // Convert infix → postfix (shunting-yard).
    final output = <String>[];
    final ops = <String>[];
    const precedence = {'+': 1, '-': 1, '*': 2, '/': 2};
    for (final t in tokens) {
      if (precedence.containsKey(t)) {
        while (ops.isNotEmpty &&
            ops.last != '(' &&
            (precedence[ops.last] ?? 0) >= precedence[t]!) {
          output.add(ops.removeLast());
        }
        ops.add(t);
      } else if (t == '(') {
        ops.add(t);
      } else if (t == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          output.add(ops.removeLast());
        }
        if (ops.isEmpty) return null; // unbalanced
        ops.removeLast(); // pop '('
      } else {
        final n = double.tryParse(t);
        if (n == null) return null;
        output.add(t);
      }
    }
    while (ops.isNotEmpty) {
      final op = ops.removeLast();
      if (op == '(' || op == ')') return null; // unbalanced
      output.add(op);
    }

    // Evaluate postfix.
    final stack = <double>[];
    for (final t in output) {
      if (precedence.containsKey(t)) {
        if (stack.length < 2) return null;
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (t) {
          case '+': stack.add(a + b); break;
          case '-': stack.add(a - b); break;
          case '*': stack.add(a * b); break;
          case '/':
            if (b == 0) return null;
            stack.add(a / b);
            break;
        }
      } else {
        final n = double.tryParse(t);
        if (n == null) return null;
        stack.add(n);
      }
    }
    if (stack.length != 1) return null;
    return stack.first.round();
  }

  Future<void> _openCalculatorPopup() async {
    final initial = widget.controller.text.replaceAll(',', '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _CalculatorPopup(initialExpression: initial),
    );
    if (result == null || !mounted) return;
    final value = evaluateExpression(result);
    if (value != null && value >= 0) {
      final formatted = CurrencyFormatter.format(value);
      widget.controller.text = formatted;
      widget.controller.selection =
          TextSelection.collapsed(offset: formatted.length);
      widget.onAmountChanged?.call(value);
      setState(() {
        _isExpressionMode = false;
        _previewResult = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseDecoration = widget.decoration ?? const InputDecoration();

    String? helperText;
    if (_isExpressionMode && _previewResult != null) {
      helperText =
          '= ${CurrencyFormatter.format(_previewResult!)}원';
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
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // V61 (2026-05-06) — 모바일 계산기 popup. 항상 노출 (PC 도 사용 가능).
            IconButton(
              icon: const Icon(Icons.calculate_outlined, size: 22),
              tooltip: '계산기',
              onPressed: _openCalculatorPopup,
              visualDensity: VisualDensity.compact,
            ),
            if (widget.controller.text.isNotEmpty) ...[
              if (_isExpressionMode)
                IconButton(
                  icon: Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: '계산',
                  onPressed: _evaluateAndReplace,
                  visualDensity: VisualDensity.compact,
                ),
              GestureDetector(
                onLongPress: () {
                  widget.controller.clear();
                },
                child: IconButton(
                  icon: const Icon(Icons.backspace_outlined, size: 20),
                  tooltip: '지우기 (길게 누르면 전체 삭제)',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final text = widget.controller.text;
                    if (text.isNotEmpty) {
                      final newText = text.substring(0, text.length - 1);
                      if (!_isExpressionMode) {
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
                            TextSelection.collapsed(offset: newText.length);
                      }
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [_CalculatorInputFormatter()],
      validator: widget.validator,
    );
  }
}

/// Modal calculator popup with button grid. Supports digits, parentheses, and
/// `+ - * /`. On `=`, returns the current expression to caller.
class _CalculatorPopup extends StatefulWidget {
  final String initialExpression;
  const _CalculatorPopup({required this.initialExpression});

  @override
  State<_CalculatorPopup> createState() => _CalculatorPopupState();
}

class _CalculatorPopupState extends State<_CalculatorPopup> {
  late String _expr;
  int? _preview;

  @override
  void initState() {
    super.initState();
    _expr = widget.initialExpression;
    _recomputePreview();
  }

  void _recomputePreview() {
    if (_expr.isEmpty) {
      _preview = null;
      return;
    }
    _preview = _CalculatorAmountFieldState.evaluateExpression(_expr);
  }

  void _append(String s) {
    setState(() {
      _expr = _expr + s;
      _recomputePreview();
    });
  }

  void _backspace() {
    if (_expr.isEmpty) return;
    setState(() {
      _expr = _expr.substring(0, _expr.length - 1);
      _recomputePreview();
    });
  }

  void _clear() {
    setState(() {
      _expr = '';
      _preview = null;
    });
  }

  void _equals() {
    if (_preview == null) return;
    if (_preview! < 0) return;
    Navigator.of(context).pop(_preview!.toString());
  }

  String _formatExpressionForDisplay(String expr) {
    if (expr.isEmpty) return '0';
    final buffer = StringBuffer();
    var currentNum = '';
    for (var i = 0; i < expr.length; i++) {
      final ch = expr[i];
      if ('+-*/()'.contains(ch)) {
        if (currentNum.isNotEmpty) {
          final n = int.tryParse(currentNum);
          buffer.write(n != null ? CurrencyFormatter.format(n) : currentNum);
          currentNum = '';
        }
        buffer.write(ch);
      } else {
        currentNum += ch;
      }
    }
    if (currentNum.isNotEmpty) {
      final n = int.tryParse(currentNum);
      buffer.write(n != null ? CurrencyFormatter.format(n) : currentNum);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewText = _preview == null
        ? '—'
        : '= ${CurrencyFormatter.format(_preview!)}원';

    return AlertDialog(
      title: const Text('계산기'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatExpressionForDisplay(_expr),
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    previewText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _preview == null
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildButtonGrid(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _preview != null && _preview! >= 0 ? _equals : null,
          child: const Text('확인'),
        ),
      ],
    );
  }

  Widget _buildButtonGrid() {
    final rows = <List<_BtnSpec>>[
      [
        _BtnSpec('C', _clear, _BtnKind.danger),
        _BtnSpec('(', () => _append('('), _BtnKind.op),
        _BtnSpec(')', () => _append(')'), _BtnKind.op),
        _BtnSpec('⌫', _backspace, _BtnKind.op),
      ],
      [
        _BtnSpec('7', () => _append('7'), _BtnKind.digit),
        _BtnSpec('8', () => _append('8'), _BtnKind.digit),
        _BtnSpec('9', () => _append('9'), _BtnKind.digit),
        _BtnSpec('÷', () => _append('/'), _BtnKind.op),
      ],
      [
        _BtnSpec('4', () => _append('4'), _BtnKind.digit),
        _BtnSpec('5', () => _append('5'), _BtnKind.digit),
        _BtnSpec('6', () => _append('6'), _BtnKind.digit),
        _BtnSpec('×', () => _append('*'), _BtnKind.op),
      ],
      [
        _BtnSpec('1', () => _append('1'), _BtnKind.digit),
        _BtnSpec('2', () => _append('2'), _BtnKind.digit),
        _BtnSpec('3', () => _append('3'), _BtnKind.digit),
        _BtnSpec('−', () => _append('-'), _BtnKind.op),
      ],
      [
        _BtnSpec('0', () => _append('0'), _BtnKind.digit),
        _BtnSpec('00', () => _append('00'), _BtnKind.digit),
        _BtnSpec('=', _equals, _BtnKind.equals),
        _BtnSpec('+', () => _append('+'), _BtnKind.op),
      ],
    ];

    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: row
                    .map((b) => Expanded(child: _buildButton(b)))
                    .toList(),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildButton(_BtnSpec spec) {
    final theme = Theme.of(context);
    Color bg;
    Color fg;
    switch (spec.kind) {
      case _BtnKind.digit:
        bg = theme.colorScheme.surfaceContainerHighest;
        fg = theme.colorScheme.onSurface;
        break;
      case _BtnKind.op:
        bg = theme.colorScheme.secondaryContainer;
        fg = theme.colorScheme.onSecondaryContainer;
        break;
      case _BtnKind.equals:
        bg = theme.colorScheme.primary;
        fg = theme.colorScheme.onPrimary;
        break;
      case _BtnKind.danger:
        bg = theme.colorScheme.errorContainer;
        fg = theme.colorScheme.onErrorContainer;
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        height: 48,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: spec.onTap,
            child: Center(
              child: Text(
                spec.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Public accessor for the evaluator — for unit tests.
///
/// The evaluator itself lives as a static method on the private state class.
/// This proxy keeps the State private while exposing the algorithm for tests.
class CalculatorAmountFieldEvaluator {
  CalculatorAmountFieldEvaluator._();

  /// Evaluates an arithmetic expression with `+ - * /` and parentheses.
  /// Returns `null` on syntax error or division-by-zero.
  static int? evaluate(String expr) =>
      _CalculatorAmountFieldState.evaluateExpression(expr);
}

enum _BtnKind { digit, op, equals, danger }

class _BtnSpec {
  final String label;
  final VoidCallback onTap;
  final _BtnKind kind;
  _BtnSpec(this.label, this.onTap, this.kind);
}

/// Input formatter that allows digits, commas, +, -, *, /, ( and ).
/// In normal mode (no operators / parens), it formats with commas.
/// In expression mode, it formats each numeric segment with commas.
class _CalculatorInputFormatter extends TextInputFormatter {
  static const _numberFormat = CurrencyFormatter.format;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final text = newValue.text;

    // Allow digits, commas, +, -, *, /, ( and ).
    final cleaned = text.replaceAll(RegExp(r'[^\d,+\-*/()]'), '');
    if (cleaned != text) {
      return TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }

    final noCommas = text.replaceAll(',', '');
    final isExpression = _CalculatorAmountFieldState._looksLikeExpression(noCommas);

    if (isExpression) {
      final formatted = _formatExpression(noCommas);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    // Normal mode: standard comma formatting.
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

  /// Formats an expression like `(50000+3000)*2` → `(50,000+3,000)*2`.
  static String _formatExpression(String expr) {
    final buffer = StringBuffer();
    var currentNum = '';
    for (var i = 0; i < expr.length; i++) {
      final ch = expr[i];
      if ('+-*/()'.contains(ch)) {
        if (currentNum.isNotEmpty) {
          final n = int.tryParse(currentNum);
          buffer.write(n != null ? _numberFormat(n) : currentNum);
          currentNum = '';
        }
        buffer.write(ch);
      } else {
        currentNum += ch;
      }
    }
    if (currentNum.isNotEmpty) {
      final n = int.tryParse(currentNum);
      buffer.write(n != null ? _numberFormat(n) : currentNum);
    }
    return buffer.toString();
  }
}
