import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guard S5 — WCAG contrast is measured, not eyeballed.
///
/// Every semantic token pair must clear 4.5:1 for body text and 3.0:1 for
/// icons/large text, in **both** light and dark. A token that fails here is
/// not adoptable (pre-agreed decision criterion, plan §5 S5).
void main() {
  const bodyMin = 4.5;
  const iconMin = 3.0;

  final cases = <String, ({BbColors bb, ColorScheme scheme})>{
    'light': (bb: BbColors.light, scheme: AppTheme.light.colorScheme),
    'dark': (bb: BbColors.dark, scheme: AppTheme.dark.colorScheme),
  };

  Map<String, BbSwatch> swatches(BbColors bb) => {
        'income': bb.income,
        'expense': bb.expense,
        'transfer': bb.transfer,
        'budget': bb.budget,
        'savings': bb.savings,
        'neutralChip': bb.neutralChip,
        'warnChip': bb.warnChip,
      };

  cases.forEach((mode, c) {
    group('[$mode]', () {
      test('swatch onContainer over container clears body contrast', () {
        swatches(c.bb).forEach((name, swatch) {
          final ratio =
              BbColors.contrastRatio(swatch.onContainer, swatch.container);
          expect(
            ratio,
            greaterThanOrEqualTo(bodyMin),
            reason: '$mode $name onContainer/container = '
                '${ratio.toStringAsFixed(2)}:1 (need $bodyMin)',
          );
        });
      });

      test('swatch color over surface clears body contrast', () {
        swatches(c.bb).forEach((name, swatch) {
          final ratio = BbColors.contrastRatio(swatch.color, c.scheme.surface);
          expect(
            ratio,
            greaterThanOrEqualTo(bodyMin),
            reason: '$mode $name color/surface = '
                '${ratio.toStringAsFixed(2)}:1 (need $bodyMin)',
          );
        });
      });

      test('balance colors clear body contrast over surface', () {
        for (final entry in {
          'positiveBalance': c.bb.positiveBalance,
          'negativeBalance': c.bb.negativeBalance,
        }.entries) {
          final ratio = BbColors.contrastRatio(entry.value, c.scheme.surface);
          expect(
            ratio,
            greaterThanOrEqualTo(bodyMin),
            reason: '$mode ${entry.key} = ${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('payment type colors clear icon contrast over surface', () {
        for (final type in ['CASH', 'BANK', 'DEBIT', 'CREDIT', 'OTHER']) {
          final ratio =
              BbColors.contrastRatio(c.bb.paymentType(type), c.scheme.surface);
          expect(
            ratio,
            greaterThanOrEqualTo(iconMin),
            reason: '$mode paymentType($type) = '
                '${ratio.toStringAsFixed(2)}:1 (need $iconMin)',
          );
        }
      });

      test('brand primary and its foreground clear body contrast', () {
        final ratio =
            BbColors.contrastRatio(c.scheme.onPrimary, c.scheme.primary);
        expect(ratio, greaterThanOrEqualTo(bodyMin),
            reason: '$mode onPrimary/primary = ${ratio.toStringAsFixed(2)}:1');
      });

      // U3 — 수입 블루가 브랜드 틸과 인접하면 안 된다 (plan §3 U3).
      test('income and expense stay away from the brand hue', () {
        expect(
          BbColors.hueDistance(c.bb.income.color, c.bb.brand),
          greaterThanOrEqualTo(40),
          reason: '$mode income hue is too close to brand teal',
        );
        expect(
          BbColors.hueDistance(c.bb.expense.color, c.bb.brand),
          greaterThanOrEqualTo(40),
          reason: '$mode expense hue is too close to brand teal',
        );
      });

      // 지출 레드는 error 상태색과 구분되어야 한다 (plan §3 U3).
      test('expense stays distinguishable from the error color', () {
        expect(
          BbColors.hueDistance(c.bb.expense.color, c.scheme.error),
          greaterThanOrEqualTo(12),
          reason: '$mode expense hue collides with colorScheme.error',
        );
      });
    });
  });

  test('contrast math matches known WCAG reference values', () {
    expect(BbColors.contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(BbColors.contrastRatio(Colors.white, Colors.white), closeTo(1, 0.01));
    // #767676 on white is the canonical 4.54:1 boundary case.
    expect(
      BbColors.contrastRatio(const Color(0xFF767676), Colors.white),
      closeTo(4.54, 0.05),
    );
  });

  test('theme exposes BbColors for both brightnesses', () {
    expect(AppTheme.light.extension<BbColors>(), same(BbColors.light));
    expect(AppTheme.dark.extension<BbColors>(), same(BbColors.dark));
  });
}
