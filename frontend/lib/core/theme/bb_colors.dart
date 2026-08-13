import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A semantic color triple: foreground on surface, container background,
/// and foreground on that container.
///
/// Every screen color must come from one of these instead of a raw
/// `Colors.*` palette value, so that light and dark stay paired by
/// construction. See `hardcoded_color_ratchet_test.dart`.
@immutable
class BbSwatch {
  const BbSwatch({
    required this.color,
    required this.container,
    required this.onContainer,
  });

  /// Foreground color when painted directly on the theme surface.
  final Color color;

  /// Chip / badge background.
  final Color container;

  /// Foreground when painted on [container].
  final Color onContainer;

  BbSwatch lerpTo(BbSwatch other, double t) => BbSwatch(
        color: Color.lerp(color, other.color, t)!,
        container: Color.lerp(container, other.container, t)!,
        onContainer: Color.lerp(onContainer, other.onContainer, t)!,
      );
}

/// Budget Book brand + semantic color tokens, injected as a [ThemeExtension].
///
/// Access from widgets via `context.bb` (see [BbColorsContext]).
@immutable
class BbColors extends ThemeExtension<BbColors> {
  const BbColors({
    required this.brightness,
    required this.brand,
    required this.income,
    required this.expense,
    required this.transfer,
    required this.budget,
    required this.savings,
    required this.neutralChip,
    required this.warnChip,
    required this.positiveBalance,
    required this.negativeBalance,
    required this.paymentCash,
    required this.paymentBank,
    required this.paymentDebit,
    required this.paymentCredit,
    required this.paymentOther,
  });

  final Brightness brightness;

  /// Brand teal. The light value is also the [ColorScheme] seed.
  final Color brand;

  final BbSwatch income;
  final BbSwatch expense;
  final BbSwatch transfer;
  final BbSwatch budget;
  final BbSwatch savings;
  final BbSwatch neutralChip;
  final BbSwatch warnChip;

  /// Positive / negative money figures (net worth, balances).
  final Color positiveBalance;
  final Color negativeBalance;

  final Color paymentCash;
  final Color paymentBank;
  final Color paymentDebit;
  final Color paymentCredit;
  final Color paymentOther;

  /// Brand seed used by both light and dark [ColorScheme]s.
  static const Color brandSeed = Color(0xFF0F766E);

  /// Brand color as rendered in dark mode (lifted for contrast).
  static const Color brandDark = Color(0xFF5ED3C4);

  static const BbColors light = BbColors(
    brightness: Brightness.light,
    brand: brandSeed,
    income: BbSwatch(
      color: Color(0xFF2563EB),
      container: Color(0xFFDBEAFE),
      onContainer: Color(0xFF1E40AF),
    ),
    expense: BbSwatch(
      color: Color(0xFFD11440),
      container: Color(0xFFFFE4E6),
      onContainer: Color(0xFF9F1239),
    ),
    transfer: BbSwatch(
      color: Color(0xFF475569),
      container: Color(0xFFE2E8F0),
      onContainer: Color(0xFF1E293B),
    ),
    budget: BbSwatch(
      color: Color(0xFFB45309),
      container: Color(0xFFFEF3C7),
      onContainer: Color(0xFF92400E),
    ),
    savings: BbSwatch(
      color: Color(0xFF7C3AED),
      container: Color(0xFFEDE9FE),
      onContainer: Color(0xFF5B21B6),
    ),
    neutralChip: BbSwatch(
      color: Color(0xFF475569),
      container: Color(0xFFF1F5F9),
      onContainer: Color(0xFF334155),
    ),
    warnChip: BbSwatch(
      color: Color(0xFFB45309),
      container: Color(0xFFFEF3C7),
      onContainer: Color(0xFF92400E),
    ),
    positiveBalance: brandSeed,
    negativeBalance: Color(0xFFD11440),
    paymentCash: Color(0xFF059669),
    paymentBank: Color(0xFF0369A1),
    paymentDebit: Color(0xFF7C3AED),
    paymentCredit: Color(0xFFDB2777),
    paymentOther: Color(0xFF475569),
  );

  static const BbColors dark = BbColors(
    brightness: Brightness.dark,
    brand: brandDark,
    income: BbSwatch(
      color: Color(0xFF60A5FA),
      container: Color(0xFF1E3A8A),
      onContainer: Color(0xFFBFDBFE),
    ),
    expense: BbSwatch(
      color: Color(0xFFFB7185),
      container: Color(0xFF881337),
      onContainer: Color(0xFFFECDD3),
    ),
    transfer: BbSwatch(
      color: Color(0xFF94A3B8),
      container: Color(0xFF334155),
      onContainer: Color(0xFFE2E8F0),
    ),
    budget: BbSwatch(
      color: Color(0xFFFBBF24),
      container: Color(0xFF78350F),
      onContainer: Color(0xFFFDE68A),
    ),
    savings: BbSwatch(
      color: Color(0xFFA78BFA),
      container: Color(0xFF4C1D95),
      onContainer: Color(0xFFDDD6FE),
    ),
    neutralChip: BbSwatch(
      color: Color(0xFF94A3B8),
      container: Color(0xFF1E293B),
      onContainer: Color(0xFFCBD5E1),
    ),
    warnChip: BbSwatch(
      color: Color(0xFFFBBF24),
      container: Color(0xFF78350F),
      onContainer: Color(0xFFFDE68A),
    ),
    positiveBalance: brandDark,
    negativeBalance: Color(0xFFFB7185),
    paymentCash: Color(0xFF34D399),
    paymentBank: Color(0xFF38BDF8),
    paymentDebit: Color(0xFFA78BFA),
    paymentCredit: Color(0xFFF472B6),
    paymentOther: Color(0xFF94A3B8),
  );

  static BbColors of(BuildContext context) =>
      Theme.of(context).extension<BbColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  /// Representative color for a payment method type.
  Color paymentType(String type) => switch (type) {
        'CASH' => paymentCash,
        'BANK' => paymentBank,
        'DEBIT' => paymentDebit,
        'CREDIT' => paymentCredit,
        _ => paymentOther,
      };

  /// Clamp a user-chosen color's HSL lightness so it stays legible on the
  /// current surface. Hue and saturation are preserved so the color still
  /// reads as the one the user picked.
  ///
  /// This is the single correction point for every `UIHelpers.parseColor`
  /// result rendered in the asset tab (guard S6).
  Color readable(Color userColor) => readableIn(userColor, brightness);

  /// Static form of [readable] for callers without a [BbColors] instance.
  static Color readableIn(Color userColor, Brightness brightness) {
    final hsl = HSLColor.fromColor(userColor);
    final lightness = brightness == Brightness.dark
        ? math.max(hsl.lightness, _darkMinLightness)
        : math.min(hsl.lightness, _lightMaxLightness);
    if (lightness == hsl.lightness) return userColor;
    return hsl.withLightness(lightness).toColor();
  }

  static const double _darkMinLightness = 0.55;
  static const double _lightMaxLightness = 0.55;

  // ---------------------------------------------------------------------
  // Contrast / hue math — production code so that the WCAG guard test
  // (S5) measures the same functions the app uses.
  // ---------------------------------------------------------------------

  /// WCAG 2.1 relative luminance of [color] (alpha ignored).
  static double relativeLuminance(Color color) {
    double channel(double value) {
      final c = value / 255.0;
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = channel((color.r * 255).roundToDouble());
    final g = channel((color.g * 255).roundToDouble());
    final b = channel((color.b * 255).roundToDouble());
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// WCAG 2.1 contrast ratio between two opaque colors (1.0 – 21.0).
  static double contrastRatio(Color a, Color b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Shortest distance between two hues on the color wheel, in degrees (0–180).
  static double hueDistance(Color a, Color b) {
    final ha = HSLColor.fromColor(a).hue;
    final hb = HSLColor.fromColor(b).hue;
    final diff = (ha - hb).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  @override
  BbColors copyWith({
    Brightness? brightness,
    Color? brand,
    BbSwatch? income,
    BbSwatch? expense,
    BbSwatch? transfer,
    BbSwatch? budget,
    BbSwatch? savings,
    BbSwatch? neutralChip,
    BbSwatch? warnChip,
    Color? positiveBalance,
    Color? negativeBalance,
    Color? paymentCash,
    Color? paymentBank,
    Color? paymentDebit,
    Color? paymentCredit,
    Color? paymentOther,
  }) {
    return BbColors(
      brightness: brightness ?? this.brightness,
      brand: brand ?? this.brand,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      budget: budget ?? this.budget,
      savings: savings ?? this.savings,
      neutralChip: neutralChip ?? this.neutralChip,
      warnChip: warnChip ?? this.warnChip,
      positiveBalance: positiveBalance ?? this.positiveBalance,
      negativeBalance: negativeBalance ?? this.negativeBalance,
      paymentCash: paymentCash ?? this.paymentCash,
      paymentBank: paymentBank ?? this.paymentBank,
      paymentDebit: paymentDebit ?? this.paymentDebit,
      paymentCredit: paymentCredit ?? this.paymentCredit,
      paymentOther: paymentOther ?? this.paymentOther,
    );
  }

  @override
  BbColors lerp(ThemeExtension<BbColors>? other, double t) {
    if (other is! BbColors) return this;
    return BbColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      brand: Color.lerp(brand, other.brand, t)!,
      income: income.lerpTo(other.income, t),
      expense: expense.lerpTo(other.expense, t),
      transfer: transfer.lerpTo(other.transfer, t),
      budget: budget.lerpTo(other.budget, t),
      savings: savings.lerpTo(other.savings, t),
      neutralChip: neutralChip.lerpTo(other.neutralChip, t),
      warnChip: warnChip.lerpTo(other.warnChip, t),
      positiveBalance: Color.lerp(positiveBalance, other.positiveBalance, t)!,
      negativeBalance: Color.lerp(negativeBalance, other.negativeBalance, t)!,
      paymentCash: Color.lerp(paymentCash, other.paymentCash, t)!,
      paymentBank: Color.lerp(paymentBank, other.paymentBank, t)!,
      paymentDebit: Color.lerp(paymentDebit, other.paymentDebit, t)!,
      paymentCredit: Color.lerp(paymentCredit, other.paymentCredit, t)!,
      paymentOther: Color.lerp(paymentOther, other.paymentOther, t)!,
    );
  }
}

/// `context.bb.income` — the only sanctioned way to read semantic colors.
extension BbColorsContext on BuildContext {
  BbColors get bb => BbColors.of(this);
}
