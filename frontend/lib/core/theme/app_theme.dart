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
        // ⚠ 여백·반지름은 여기서 정하지 않는다. 하드코딩(`16/12`)이면 폭에 반응하지
        // 않아 `MaterialApp.theme` 자리의 고정 px 가 전 화면 기본값이 된다
        // (2026-08-20 실측: `contentPadding` 16/12 · `radius` 12/16 이 그랬다).
        // 채우는 곳은 [responsive] 한 곳이다.
        cardTheme: const CardThemeData(elevation: 0),
      );

  // ───────────────────────────────────────────────────────────────────────────
  // 폭 반응 (2026-08-18)
  // ───────────────────────────────────────────────────────────────────────────

  /// Material 슬롯별 `(ref, min, max)`. `ref` 는 M3 기본값이라 1440px 에서는
  /// 종전과 같아 보이고, **좁아질수록만 줄어든다**(회귀 표면적 최소화).
  ///
  /// ★`body*`/`label*` 은 `min == ref` — 작은 화면에서 본문을 줄이지 않는다.
  /// 모바일 개선은 큰 글자·아이콘·크롬·밀도에서 온다(`domains/12-ui-scaling.md` ★5).
  /// Material 슬롯별 `(ref, min, max)`.
  ///
  /// ★기준점은 **자산 탭**이다(2026-08-19 사용자 검증: "자산 내 글자 크기가 딱 적절하다").
  /// `BbDensity` 의 타일 폰트가 유일하게 폭에 반응하던 체계였고 사용자가 그 값을
  /// 승인했으므로, 그 3단 값을 **연속 곡선이 지나가도록** ref/min/max 를 역산했다.
  ///
  /// 역산 근거 — `size = clamp(min, ref × (W/1440)^0.25, max)` 에서
  /// `(360/1440)^0.25 = 0.7071` · `(768/1440)^0.25 = 0.8409` · `(960/1440)^0.25 = 0.9036`:
  ///
  ///   자산 title  14 / 15 / 16  → ref 17.8 · min 14 · max 16
  ///   자산 metric 13 / 14 / 15  → ref 16.7 · min 13 · max 15
  ///   자산 chip   10 / 11 / 12  → ref 13.4 · min 10 · max 12
  ///   자산 hdrL   11 / 12 / 12  → ref 13.3 · min 11 · max 12
  ///   자산 hdrV   15 / 17 / 19  → ref 21.1 · min 15 · max 19
  ///                              (21.0 이면 960px 에서 18.98 로 상한에 0.02 미달)
  ///
  /// `ref > max` 는 의도된 것이다 — 기준 폭(1440)에서 이미 상한에 닿아 있다는 뜻이고,
  /// 그래야 좁은 쪽 곡선이 자산 값을 지나간다. 정합은 `responsive_sweep_test.dart`
  /// 의 "자산 탭 값과 일치" 테스트가 고정한다.
  ///
  /// ⚠ 이전 판(Material 기본값을 ref, body 는 min == ref)은 **1440px 아래에서 본문이
  /// 통째로 상수**였다 — 폭에 반응하지 않았고 자산 탭보다 2px 컸다. 그게 사용자가
  /// 지적한 "거래/분석/더보기가 크다" 의 실체다.
  static const Map<String, ({double ref, double min, double max})> _slots = {
    'displayLarge': (ref: 60, min: 34, max: 52),
    'displayMedium': (ref: 48, min: 28, max: 42),
    'displaySmall': (ref: 38, min: 24, max: 34),
    'headlineLarge': (ref: 34, min: 21, max: 30),
    'headlineMedium': (ref: 29, min: 19, max: 26),
    'headlineSmall': (ref: 25, min: 17, max: 22),
    'titleLarge': (ref: 21.1, min: 15, max: 19), // 자산 hdrV
    'titleMedium': (ref: 17.8, min: 14, max: 16), // 자산 title
    'titleSmall': (ref: 16.7, min: 13, max: 15), // 자산 metric
    'bodyLarge': (ref: 17.8, min: 14, max: 16), // 자산 title — 목록 행 제목
    'bodyMedium': (ref: 16.7, min: 13, max: 15), // 자산 metric — 본문 기본
    'bodySmall': (ref: 13.3, min: 11, max: 12), // 자산 hdrL — 메타·보조
    'labelLarge': (ref: 16.7, min: 13, max: 15),
    'labelMedium': (ref: 13.3, min: 11, max: 12),
    'labelSmall': (ref: 13.4, min: 10, max: 12), // 자산 chip
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
  ///
  /// ★2026-08-20: 3단 계단(`<600` / `<960` / else)을 **연속 보간**으로 바꿨다.
  /// `VisualDensity` 는 `double` 을 받으므로 계단일 이유가 없었고, 계단은 그 자체로
  /// 경쟁 축이다(같은 폭에서 밀도만 점프). `-2`(≤390) → `0`(≥960) 선형.
  ///
  /// 국소 `visualDensity: VisualDensity.compact` override 는 전건 제거했다(17곳) —
  /// 그것이 이 단일 소스와 경쟁하던 경로다(`tool/audit_ui_consistency.py` 클래스 D).
  static VisualDensity _densityFor(double width) {
    const from = 390.0;
    final t = ((width - from) / (kBbContentMaxWidth - from)).clamp(0.0, 1.0);
    final v = -2 + 2 * t;
    return VisualDensity(horizontal: v, vertical: v);
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
      displayLarge:
          t.displayLarge?.copyWith(fontSize: _slot('displayLarge', width)),
      displayMedium:
          t.displayMedium?.copyWith(fontSize: _slot('displayMedium', width)),
      displaySmall:
          t.displaySmall?.copyWith(fontSize: _slot('displaySmall', width)),
      headlineLarge:
          t.headlineLarge?.copyWith(fontSize: _slot('headlineLarge', width)),
      headlineMedium:
          t.headlineMedium?.copyWith(fontSize: _slot('headlineMedium', width)),
      headlineSmall:
          t.headlineSmall?.copyWith(fontSize: _slot('headlineSmall', width)),
      titleLarge: t.titleLarge?.copyWith(fontSize: _slot('titleLarge', width)),
      titleMedium:
          t.titleMedium?.copyWith(fontSize: _slot('titleMedium', width)),
      titleSmall: t.titleSmall?.copyWith(fontSize: _slot('titleSmall', width)),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: _slot('bodyLarge', width)),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: _slot('bodyMedium', width)),
      bodySmall: t.bodySmall?.copyWith(fontSize: _slot('bodySmall', width)),
      labelLarge: t.labelLarge?.copyWith(fontSize: _slot('labelLarge', width)),
      labelMedium:
          t.labelMedium?.copyWith(fontSize: _slot('labelMedium', width)),
      labelSmall: t.labelSmall?.copyWith(fontSize: _slot('labelSmall', width)),
    );

    // 여백·반지름의 **전역 통로**. 폰트는 `TextTheme` 이 전역이라 토큰 수정만으로 전 화면에
    // 퍼졌지만 여백에는 그 통로가 없었다 — 2026-08-20 실측: `BbSpace` 를 쓰는 `lib` 파일이
    // **3개**뿐이고 리터럴은 1,699건이었다. 그래서 컴포넌트 테마를 곡선으로 채운다.
    final space = BbSpace.forWidth(width);
    final radiusSm = BorderRadius.circular(space.md);
    final radiusMd = BorderRadius.circular(space.lg);

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text,
      visualDensity: _densityFor(width),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(borderRadius: radiusMd),
        contentPadding: space.symmetric(
          h: BbSpaceToken.xl,
          v: BbSpaceToken.lg,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
        margin: space.symmetric(h: BbSpaceToken.md, v: BbSpaceToken.sm),
      ),
      dividerTheme: base.dividerTheme.copyWith(space: space.lg),
      dialogTheme: base.dialogTheme.copyWith(
        insetPadding: space.symmetric(h: BbSpaceToken.xl, v: BbSpaceToken.xxl),
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(space.xl)),
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        contentPadding: space.symmetric(h: BbSpaceToken.xl),
        minVerticalPadding: space.sm,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
        labelPadding: space.symmetric(h: BbSpaceToken.lg),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: space.symmetric(h: BbSpaceToken.xl, v: BbSpaceToken.md),
          shape: RoundedRectangleBorder(borderRadius: radiusSm),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: space.symmetric(h: BbSpaceToken.xl, v: BbSpaceToken.md),
          shape: RoundedRectangleBorder(borderRadius: radiusSm),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: space.symmetric(h: BbSpaceToken.xl, v: BbSpaceToken.md),
          shape: RoundedRectangleBorder(borderRadius: radiusSm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: space.symmetric(h: BbSpaceToken.lg, v: BbSpaceToken.md),
          shape: RoundedRectangleBorder(borderRadius: radiusSm),
        ),
      ),
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
      navigationBarTheme: base.navigationBarTheme.copyWith(
        height: BbBox.forWidth(width).navBar,
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
    );
  }
}
