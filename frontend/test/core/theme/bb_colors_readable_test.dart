import 'package:budget_book/core/theme/bb_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `readable()` is the single correction point for user-picked category /
/// pocket colors (plan §4 D5). It may only clamp HSL lightness — hue and
/// saturation must survive, or the user sees a color they did not choose.
void main() {
  group('readable()', () {
    test('lifts a too-dark user color in dark mode', () {
      const veryDark = Color(0xFF10221B); // L ≈ 0.10
      final fixed = BbColors.readableIn(veryDark, Brightness.dark);
      expect(HSLColor.fromColor(fixed).lightness, greaterThanOrEqualTo(0.55));
    });

    test('darkens a too-light user color in light mode', () {
      const veryLight = Color(0xFFEAFBF5); // L ≈ 0.95
      final fixed = BbColors.readableIn(veryLight, Brightness.light);
      expect(HSLColor.fromColor(fixed).lightness, lessThanOrEqualTo(0.55));
    });

    test('preserves hue and saturation while clamping', () {
      const userColor = Color(0xFF1A237E); // deep indigo
      final source = HSLColor.fromColor(userColor);
      final fixed = HSLColor.fromColor(
        BbColors.readableIn(userColor, Brightness.dark),
      );
      expect(fixed.hue, closeTo(source.hue, 1.0));
      expect(fixed.saturation, closeTo(source.saturation, 0.02));
    });

    test('leaves an already-legible color untouched', () {
      const midTone = Color(0xFF7C3AED); // L ≈ 0.58
      expect(
        BbColors.readableIn(midTone, Brightness.dark),
        same(midTone),
        reason: 'no clamp needed, so the exact instance is returned',
      );
    });

    test('instance form follows the extension brightness', () {
      const dim = Color(0xFF102A43);
      expect(
        BbColors.dark.readable(dim),
        BbColors.readableIn(dim, Brightness.dark),
      );
      expect(
        BbColors.light.readable(dim),
        BbColors.readableIn(dim, Brightness.light),
      );
    });
  });

  group('hueDistance()', () {
    test('wraps around the color wheel', () {
      expect(
        BbColors.hueDistance(const Color(0xFFFF0000), const Color(0xFFFF0000)),
        closeTo(0, 0.01),
      );
      // 350° vs 10° is 20° apart, not 340°.
      final a = HSLColor.fromAHSL(1, 350, 1, 0.5).toColor();
      final b = HSLColor.fromAHSL(1, 10, 1, 0.5).toColor();
      expect(BbColors.hueDistance(a, b), closeTo(20, 1.0));
    });
  });

  group('paymentType()', () {
    test('gives every known type its own color', () {
      final colors = ['CASH', 'BANK', 'DEBIT', 'CREDIT']
          .map(BbColors.light.paymentType)
          .toSet();
      expect(colors.length, 4);
    });

    test('falls back for unknown types', () {
      expect(BbColors.light.paymentType('WHATEVER'), BbColors.light.paymentOther);
    });
  });

  group('ThemeExtension plumbing', () {
    test('lerp interpolates both endpoints', () {
      final mid = BbColors.light.lerp(BbColors.dark, 0.5);
      expect(mid.income.color, Color.lerp(
        BbColors.light.income.color,
        BbColors.dark.income.color,
        0.5,
      ));
      expect(BbColors.light.lerp(BbColors.dark, 0.0).brightness, Brightness.light);
      expect(BbColors.light.lerp(BbColors.dark, 1.0).brightness, Brightness.dark);
    });

    test('copyWith replaces only what is given', () {
      final changed = BbColors.light.copyWith(brand: const Color(0xFF123456));
      expect(changed.brand, const Color(0xFF123456));
      expect(changed.income.color, BbColors.light.income.color);
    });
  });
}
