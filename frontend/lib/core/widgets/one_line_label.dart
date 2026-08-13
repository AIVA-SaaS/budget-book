import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A single-line text that shrinks its font size to fit the available width
/// instead of truncating.
///
/// Takes a plain [String] — never a child widget — so callers cannot smuggle
/// in a layout that breaks the one-line contract (guard S1).
///
/// The font size never goes below [minFontSize]; only then does it fall back
/// to an ellipsis. **Amount strings are never abbreviated** (no "만원"
/// shortening) — financial figures must stay exact, so shrinking is the only
/// allowed adaptation.
class OneLineLabel extends StatelessWidget {
  const OneLineLabel(
    this.text, {
    super.key,
    required this.baseFontSize,
    this.minFontSize = defaultMinFontSize,
    this.style,
    this.textAlign,
  });

  final String text;

  /// Preferred font size when the text fits.
  final double baseFontSize;

  /// Hard floor for shrinking. 12sp is the smallest size we consider legible.
  final double minFontSize;

  /// Base style; its `fontSize` is replaced by the fitted size.
  final TextStyle? style;

  final TextAlign? textAlign;

  static const double defaultMinFontSize = 12;

  /// Binary-search iterations used to find the largest fitting size.
  static const int searchIterations = 4;

  @override
  Widget build(BuildContext context) {
    final resolved =
        (style ?? DefaultTextStyle.of(context).style).copyWith(fontSize: baseFontSize);
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = fitFontSize(
          text: text,
          maxWidth: constraints.maxWidth,
          baseFontSize: baseFontSize,
          minFontSize: minFontSize,
          style: resolved,
          textScaler: textScaler,
          textDirection: Directionality.of(context),
        );
        return Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: resolved.copyWith(fontSize: fontSize),
        );
      },
    );
  }

  /// Largest size in `[minFontSize, baseFontSize]` at which [text] fits in
  /// [maxWidth] on one line. Returns [minFontSize] when even that overflows.
  static double fitFontSize({
    required String text,
    required double maxWidth,
    required double baseFontSize,
    required double minFontSize,
    required TextStyle style,
    required TextScaler textScaler,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    if (text.isEmpty || !maxWidth.isFinite || maxWidth <= 0) return baseFontSize;
    final floor = math.min(minFontSize, baseFontSize);

    final key = _cacheKey(text, maxWidth, baseFontSize, floor, style, textScaler);
    final cached = _cache[key];
    if (cached != null) return cached;

    double measure(double size) => _measureWidth(
          text: text,
          style: style.copyWith(fontSize: size),
          textScaler: textScaler,
          textDirection: textDirection,
        );

    double result;
    if (measure(baseFontSize) <= maxWidth) {
      result = baseFontSize;
    } else if (measure(floor) > maxWidth) {
      result = floor;
    } else {
      var low = floor;
      var high = baseFontSize;
      for (var i = 0; i < searchIterations; i++) {
        final mid = (low + high) / 2;
        if (measure(mid) <= maxWidth) {
          low = mid;
        } else {
          high = mid;
        }
      }
      result = low;
    }

    _store(key, result);
    return result;
  }

  /// Width [text] would occupy on one line at [fontSize].
  ///
  /// Used by layouts that must decide between placing two elements side by
  /// side or stacking them ([EntityTileRow] does this for the trailing
  /// amount).
  static double measureWidth({
    required String text,
    required double fontSize,
    required TextStyle style,
    required TextScaler textScaler,
    TextDirection textDirection = TextDirection.ltr,
  }) =>
      _measureWidth(
        text: text,
        style: style.copyWith(fontSize: fontSize),
        textScaler: textScaler,
        textDirection: textDirection,
      );

  static double _measureWidth({
    required String text,
    required TextStyle style,
    required TextScaler textScaler,
    required TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  static String _cacheKey(
    String text,
    double maxWidth,
    double base,
    double floor,
    TextStyle style,
    TextScaler textScaler,
  ) {
    // Width is bucketed to whole pixels: sub-pixel jitter must not thrash
    // the cache during scroll.
    return '$text|${maxWidth.round()}|$base|$floor'
        '|${style.fontFamily}|${style.fontWeight?.value}'
        '|${style.letterSpacing}|${textScaler.scale(100).round()}';
  }

  static final Map<String, double> _cache = <String, double>{};
  static const int _cacheLimit = 512;

  static void _store(String key, double value) {
    if (_cache.length >= _cacheLimit) _cache.clear();
    _cache[key] = value;
  }

  /// Test hook — drops memoized measurements.
  @visibleForTesting
  static void clearCache() => _cache.clear();
}
