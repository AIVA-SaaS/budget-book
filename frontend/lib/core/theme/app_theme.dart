import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:budget_book/core/theme/bb_colors.dart';
import 'package:budget_book/core/theme/bb_scale.dart';

class AppTheme {
  AppTheme._();

  static const _fontFamily = 'NotoSansKR';

  /// Brand teal on light surfaces (also the [ColorScheme] seed).
  static const Color _brandLight = BbColors.brandSeed;

  /// Brand teal lifted for dark surfaces.
  static const Color _brandDark = BbColors.brandDark;

  /// Foreground on [_brandDark].
  static const Color _onBrandDark = Color(0xFF003731);

  /// Foreground on [_brandLight].
  static const Color _onBrandLight = Color(0xFFFFFFFF);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: _brandLight,
    brightness: Brightness.light,
  ).copyWith(primary: _brandLight, onPrimary: _onBrandLight);

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _brandLight,
    brightness: Brightness.dark,
  ).copyWith(primary: _brandDark, onPrimary: _onBrandDark);

  static ThemeData get light => _base(_lightScheme, BbColors.light);

  static ThemeData get dark => _base(_darkScheme, BbColors.dark);

  static ThemeData _base(ColorScheme scheme, BbColors bbColors) => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: scheme,
        extensions: <ThemeExtension<dynamic>>[bbColors],
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

  // ───────────────────────────────────────────────────────────────────────────
  // 폭 반응 (2026-08-18)
  // ───────────────────────────────────────────────────────────────────────────

  /// Material 슬롯별 `(ref, min, max)`. `ref` 는 M3 기본값이라 1440px 에서는
  /// 종전과 같아 보이고, **좁아질수록만 줄어든다**(회귀 표면적 최소화).
  ///
  /// ★`body*`/`label*` 은 `min == ref` — 작은 화면에서 본문을 줄이지 않는다.
  /// 모바일 개선은 큰 글자·아이콘·크롬·밀도에서 온다(`domains/12-ui-scaling.md` ★5).
  static const Map<String, ({double ref, double min, double max})> _slots = {
    'displayLarge': (ref: 57, min: 40, max: 64),
    'displayMedium': (ref: 45, min: 32, max: 52),
    'displaySmall': (ref: 36, min: 27, max: 42),
    'headlineLarge': (ref: 32, min: 24, max: 37),
    'headlineMedium': (ref: 28, min: 22, max: 32),
    'headlineSmall': (ref: 24, min: 19, max: 28),
    'titleLarge': (ref: 22, min: 18, max: 26),
    'titleMedium': (ref: 16, min: 15, max: 19),
    'titleSmall': (ref: 14, min: 13, max: 17),
    'bodyLarge': (ref: 16, min: 16, max: 19),
    'bodyMedium': (ref: 14, min: 14, max: 17),
    'bodySmall': (ref: 12, min: 12, max: 14),
    'labelLarge': (ref: 14, min: 14, max: 17),
    'labelMedium': (ref: 12, min: 12, max: 14),
    'labelSmall': (ref: 11, min: 11, max: 13),
  };

  static double _slot(String name, double width) {
    final spec = _slots[name]!;
    final raw = spec.ref *
        math.pow(width / kBbTypeReferenceWidth, kBbTypeExponent).toDouble();
    return raw.clamp(spec.min, spec.max);
  }

  /// 밀도 — Material 이 소유한 레버다. 버튼·`ListTile`·`IconButton` 의 내부 여백을
  /// 컴포넌트마다 손대지 않고 한 번에 줄인다("버튼 크기가 너무 커" 의 직접 처방).
  ///
  /// 판정은 **유효 콘텐츠 폭**으로 한다 — 화면 폭이 아니다(`bb_scale.dart` 참조).
  static VisualDensity _densityFor(double width) {
    if (width < 600) return const VisualDensity(horizontal: -2, vertical: -2);
    if (width < kBbContentMaxWidth) {
      return const VisualDensity(horizontal: -1, vertical: -1);
    }
    return VisualDensity.standard;
  }

  /// 기존 [light]/[dark] 위에 **유효 폭**에 따른 타이포·아이콘·밀도·크롬을 얹는다.
  ///
  /// `app.dart` 의 `LayoutBuilder` 가 호출한다 — `MaterialApp.theme` 자리에서는
  /// `MediaQuery` 를 못 읽고, 읽더라도 웹에서는 화면 폭(2560)이지 콘텐츠 폭(960)이
  /// 아니라서 틀린다.
  static ThemeData responsive(ThemeData base, double width) {
    final type = BbType.forWidth(width);
    final t = base.textTheme;
    final text = t.copyWith(
      displayLarge: t.displayLarge?.copyWith(fontSize: _slot('displayLarge', width)),
      displayMedium: t.displayMedium?.copyWith(fontSize: _slot('displayMedium', width)),
      displaySmall: t.displaySmall?.copyWith(fontSize: _slot('displaySmall', width)),
      headlineLarge: t.headlineLarge?.copyWith(fontSize: _slot('headlineLarge', width)),
      headlineMedium: t.headlineMedium?.copyWith(fontSize: _slot('headlineMedium', width)),
      headlineSmall: t.headlineSmall?.copyWith(fontSize: _slot('headlineSmall', width)),
      titleLarge: t.titleLarge?.copyWith(fontSize: _slot('titleLarge', width)),
      titleMedium: t.titleMedium?.copyWith(fontSize: _slot('titleMedium', width)),
      titleSmall: t.titleSmall?.copyWith(fontSize: _slot('titleSmall', width)),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: _slot('bodyLarge', width)),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: _slot('bodyMedium', width)),
      bodySmall: t.bodySmall?.copyWith(fontSize: _slot('bodySmall', width)),
      labelLarge: t.labelLarge?.copyWith(fontSize: _slot('labelLarge', width)),
      labelMedium: t.labelMedium?.copyWith(fontSize: _slot('labelMedium', width)),
      labelSmall: t.labelSmall?.copyWith(fontSize: _slot('labelSmall', width)),
    );

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text,
      visualDensity: _densityFor(width),
      iconTheme: base.iconTheme.copyWith(size: type.iconMd),
      primaryIconTheme: base.primaryIconTheme.copyWith(size: type.iconMd),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: type.iconMd,
          // L4 허용 목록: 44 는 터치 타깃 **하한**이지 크기가 아니다.
          minimumSize: const Size(44, 44),
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: text.titleLarge,
        toolbarTextStyle: text.bodyMedium,
        iconTheme: IconThemeData(size: type.iconMd),
        actionsIconTheme: IconThemeData(size: type.iconMd),
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        height: type.navBarHeight,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
        iconTheme: WidgetStatePropertyAll(IconThemeData(size: type.iconSm)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          textStyle: text.labelLarge,
          iconSize: type.iconSm,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(labelStyle: text.labelMedium),
      listTileTheme: base.listTileTheme.copyWith(
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
      ),
    );
  }
}
