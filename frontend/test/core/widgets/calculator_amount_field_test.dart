import 'package:budget_book/core/widgets/calculator_amount_field.dart';
import 'package:flutter_test/flutter_test.dart';

/// V61 (2026-05-06) — calculator_amount_field 회귀 fix + 괄호 evaluator 단위 테스트.
///
/// 이전 evaluator 는 left-to-right precedence 만 지원, 괄호 미지원.
/// 또한 `_evaluateAndReplace` 가 `result <= 0` 시 controller 를 비워
/// `5-5` 같은 0 결과 입력이 손실되었음 (회차 1 에서 fix).
void main() {
  int? eval(String s) => CalculatorAmountFieldEvaluator.evaluate(s);

  group('CalculatorAmountFieldEvaluator', () {
    test('basic + - * /', () {
      expect(eval('5+3'), 8);
      expect(eval('10-7'), 3);
      expect(eval('4*5'), 20);
      expect(eval('20/4'), 5);
    });

    test('precedence: * and / before + and -', () {
      expect(eval('1+2*3'), 7);
      expect(eval('10-6/2'), 7);
      expect(eval('2*3+4*5'), 26);
    });

    test('parentheses change precedence', () {
      expect(eval('(1+2)*3'), 9);
      expect(eval('2*(3+4)'), 14);
      expect(eval('(10-2)/4'), 2);
      expect(eval('((1+2)*3)/9'), 1);
      expect(eval('1+(2*(3+4))'), 15);
    });

    test('zero result is supported (회차 1 fix)', () {
      // evaluator 자체는 0 반환 — 이전에도 그러했지만 caller 에서 비웠음.
      expect(eval('5-5'), 0);
      expect(eval('(3-3)*5'), 0);
      expect(eval('0'), 0);
    });

    test('division by zero returns null', () {
      expect(eval('10/0'), null);
    });

    test('unbalanced parentheses returns null', () {
      expect(eval('(1+2'), null);
      expect(eval('1+2)'), null);
      expect(eval('((1+2)'), null);
    });

    test('rounds float results (round half-up via .round())', () {
      expect(eval('10/3'), 3); // 3.333... → 3
      expect(eval('10/4'), 3); // 2.5 → 2 or 3 depending on banker (Dart .round() returns 3)
    });

    test('empty / invalid input returns null', () {
      expect(eval(''), null);
      expect(eval('+'), null);
      expect(eval('abc'), null);
    });

    test('negative result is allowed by evaluator (caller decides reject)', () {
      expect(eval('5-10'), -5);
    });
  });
}
