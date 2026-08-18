/// UI 크기 토큰 — 타이포([BbType]) · 공간([BbSpace]).
///
/// 규칙 정본은 `~/.claude/domains/12-ui-scaling.md` (전 앱 공통). 원본 구현은
/// calynda `fe/lib/ui/shared/themes/ui_scale.dart` 이고 **계산식을 동일하게** 간다 —
/// 같은 곡선을 두 앱이 공유해야 "다른 앱에도 기본"이 성립한다.
///
/// 왜 이 파일이 있나 (2026-08-18 실측):
/// `app_theme.dart` 에 `TextTheme`·`visualDensity`·`IconTheme` 이 **없었다**. 앱 전체가
/// Material 기본 타이포 한 벌로 320px 폰부터 웹까지 똑같이 그렸다 = 폭에 대한 반응 0.
/// 크기 리터럴은 1,458건(fontSize 115 · EdgeInsets 446 · SizedBox 747 · radius 150).
///
/// ★처방의 핵심은 "px 를 % 로 치환"이 아니라 **clamp 를 비율이 아니라 가독 기준(px)에
/// 거는 것**이다. `scale >= 0.9` 처럼 비율에 하한을 걸면 하한에 닿는 순간 **전 축이 통째로
/// 굳는다**(calynda 실측: 320~1024px 전 구간 0.900 붙박이 = 폭 3.2배에 반응 0).
/// 역할마다 하한에 닿는 폭이 다르면 어느 한 지점에서 전체가 멈추지 않는다.
///
/// ★층 의존: **폰트 → 여백 → 밀도 역산** 순서로만 이관한다. 기준 폰트가 고정된 자리에서
/// 여백을 `0.5em` 으로 바꾸면 고정 px 와 **완전히 같다** — 이름만 바뀌고 거동은 그대로다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 유효 콘텐츠 폭 — 단일 소스
// ─────────────────────────────────────────────────────────────────────────────

/// 이 앱이 콘텐츠를 그리는 실제 최대 폭. `app.dart` 가 웹에서 본문을 이 폭으로
/// 감싼다(`BoxConstraints(maxWidth: 960)`).
///
/// ★이것이 [BbScaleScope] 가 필요한 이유다 — 2560px 화면에서도 본문은 960px 다.
/// `MediaQuery` 로 판정하면 960px 칼럼 안에서 "2560px 데스크톱" 크기로 그린다
/// (calynda 실측: 최악이 모바일이 아니라 화면은 넓고 컨테이너는 좁은 지점이었다).
const double kBbContentMaxWidth = 960;

/// 타이포 기준 폭 — 이 폭에서 `ref` 가 그대로 나온다.
const double kBbTypeReferenceWidth = 1440;

/// 폭비의 로그 압축 지수(4제곱근).
///
/// 1440 → 2560 에서 1.155배, 1440 → 360 에서 0.707배. `sqrt`(0.5)보다 완만해
/// 큰 화면에서 글자만 비대해지지 않는다.
const double kBbTypeExponent = 0.25;

/// 유효 폭을 나르는 스코프. `app.dart` 의 `LayoutBuilder` 가 심는다.
///
/// 없으면 [BbType.of] 는 `MediaQuery` 로 폴백한다(위젯 테스트·다이얼로그 등
/// 스코프 밖 경로). 폴백은 **정상 경로가 아니다** — 화면 폭이 곧 콘텐츠 폭인
/// 자리에서만 맞다.
class BbScaleScope extends InheritedWidget {
  const BbScaleScope({
    super.key,
    required this.width,
    required super.child,
  });

  /// 이 서브트리가 실제로 쓸 수 있는 폭.
  final double width;

  static double? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BbScaleScope>()
      ?.width;

  @override
  bool updateShouldNotify(BbScaleScope oldWidget) => oldWidget.width != width;
}

// ─────────────────────────────────────────────────────────────────────────────
// 타이포 토큰
// ─────────────────────────────────────────────────────────────────────────────

/// 폰트 역할. 위젯은 숫자가 아니라 이 역할로 크기를 말한다.
enum BbTextRole { display, title, section, body, label, caption }

/// 역할별 기준값. `ref` 는 1440px 에서의 크기이고 `min`/`max` 는 **가독 기준 px**
/// 이다(비율이 아니다 — 이게 현행 결함의 직접 처방).
///
/// `ref` 는 Material 3 기본값에 맞췄다 — 1440px 웹에서 지금과 같아 보이고,
/// 좁아질수록만 줄어든다(회귀 표면적 최소화).
///
/// ★`body`/`label`/`caption` 은 `min == ref` 다 — **작은 화면에서 본문 글자를 줄이지
/// 않는다**. 좁은 화면의 적응은 구조(L0)·컨테이너 역산(L1)·크롬 축소가 맡는다.
/// 귀결: 1440px 아래에서 본문 타이포는 상수다. 체감이 다르면 레버는 `min` 하향 하나뿐.
const Map<BbTextRole, ({double ref, double min, double max})> kBbTextSpec = {
  BbTextRole.display: (ref: 24, min: 19, max: 28), // headlineSmall
  BbTextRole.title: (ref: 22, min: 18, max: 26), // titleLarge
  BbTextRole.section: (ref: 16, min: 15, max: 19), // titleMedium
  BbTextRole.body: (ref: 14, min: 14, max: 17), // bodyMedium
  BbTextRole.label: (ref: 12, min: 12, max: 14), // bodySmall
  BbTextRole.caption: (ref: 11, min: 11, max: 13), // labelSmall
};

/// 아이콘 크기 역할.
///
/// 왜 별도 사다리인가: 아이콘은 **글자와 나란히** 놓이므로 고정 px 로 두면 폰트가
/// 반응할 때 혼자 안 움직여 어긋난다. 그렇다고 텍스트 역할을 그대로 쓰면 현행
/// 분포(20:66곳 · 18:64곳 · 16:47곳 · 14:27곳)가 텍스트 사다리에 억지로 눌린다.
enum BbIconRole {
  /// 본문 옆 인라인 아이콘.
  sm,

  /// 버튼·액션·크롬 아이콘(Material 기본 24 를 대체한다).
  md,

  /// 강조 아이콘.
  lg,
}

const Map<BbIconRole, ({double ref, double min, double max})> kBbIconSpec = {
  BbIconRole.sm: (ref: 18, min: 15, max: 21),
  BbIconRole.md: (ref: 24, min: 19, max: 27),
  BbIconRole.lg: (ref: 32, min: 26, max: 36),
};

/// 역할 토큰 → 크기. CSS `clamp()` 의 등가물이다.
///
/// ```
/// size(role, W) = clamp( min, ref × (W / 1440)^0.25, max )
/// ```
@immutable
class BbType {
  const BbType._(this.width);

  /// 이 서브트리의 유효 폭 기준. [BbScaleScope] 가 있으면 그 값을, 없으면
  /// `MediaQuery` 폭을 쓴다.
  factory BbType.of(BuildContext context) => BbType._(
        BbScaleScope.maybeOf(context) ?? MediaQuery.sizeOf(context).width,
      );

  /// **컨테이너 폭** 기준. 분할 뷰·그리드 셀·패널처럼 화면은 넓은데 자기 폭은
  /// 좁은 자리에서 쓴다.
  factory BbType.forWidth(double width) => BbType._(width);

  /// 이 토큰이 기준으로 삼는 폭.
  final double width;

  /// 역할의 폰트 크기(px). `textScaler` 는 곱하지 않는다 — `Text` 가 렌더 시점에
  /// 적용하므로 여기서 곱하면 **두 번 곱해진다**.
  double size(BbTextRole role) => _clamped(kBbTextSpec[role]!);

  /// 아이콘 크기(px) — 텍스트와 **같은 곡선**을 탄다.
  double icon(BbIconRole role) => _clamped(kBbIconSpec[role]!);

  double _clamped(({double ref, double min, double max}) spec) {
    final raw = spec.ref *
        math.pow(width / kBbTypeReferenceWidth, kBbTypeExponent).toDouble();
    return raw.clamp(spec.min, spec.max);
  }

  /// 역할의 `TextStyle`. ★호출부가 `fontSize:` 를 적을 이유 자체를 없앤다
  /// (리터럴이 다시 새려면 이 API 를 우회해야 하고 그건
  /// `tool/check_ui_scaling.py` 가 잡는다).
  TextStyle style(
    BbTextRole role, {
    Color? color,
    FontWeight? weight,
    TextDecoration? decoration,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontSize: size(role),
        color: color,
        fontWeight: weight,
        decoration: decoration,
        height: height,
        letterSpacing: letterSpacing,
      );

  double get display => size(BbTextRole.display);
  double get title => size(BbTextRole.title);
  double get section => size(BbTextRole.section);
  double get body => size(BbTextRole.body);
  double get label => size(BbTextRole.label);
  double get caption => size(BbTextRole.caption);

  // ── 크롬 높이 ──────────────────────────────────────────────────────────
  //
  // 프레임워크 기본값(AppBar 56 · Tab icon+text 72 · NavigationBar 80)은 중첩되면
  // 모바일에서 콘텐츠를 밀어낸다. 분석 탭은 icon+text TabBar 가 2단이라 그것만
  // 144dp 였다(2026-08-18 실측).

  /// 탭 한 줄 높이. **아이콘을 가로 배치**하는 전제의 값이다 —
  /// `Tab(icon:, text:)` 는 세로 배치라 SDK 가 72 를 강제한다(`tabs.dart:205`).
  double get tabHeight => width < 600 ? 44 : 48;

  /// 하단 네비 높이. ⚠ `NavigationBar` 는 `SizedBox` 하드 박스라 과하게 낮추면
  /// 오버플로한다 — 스윕 테스트가 배율 1.6 까지 검사한다.
  double get navBarHeight => width < 600 ? 66 : 80;

  double get iconSm => icon(BbIconRole.sm);
  double get iconMd => icon(BbIconRole.md);
  double get iconLg => icon(BbIconRole.lg);

  @override
  bool operator ==(Object other) => other is BbType && other.width == width;

  @override
  int get hashCode => width.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────
// 공간 토큰
// ─────────────────────────────────────────────────────────────────────────────

/// 여백·간격 역할.
enum BbSpaceToken { xs, sm, md, lg, xl, xxl }

/// 기준값(1440px · 배율 1.0).
const Map<BbSpaceToken, double> kBbSpaceBase = {
  BbSpaceToken.xs: 4,
  BbSpaceToken.sm: 6,
  BbSpaceToken.md: 8,
  BbSpaceToken.lg: 12,
  BbSpaceToken.xl: 16,
  BbSpaceToken.xxl: 24,
};

/// 폰트↔여백 결합 지수 — **부분 결합 = 제곱근**(calynda 2026-08-14 사용자 결정).
///
/// 글자가 2배가 되면 여백은 1.41배. **계수 조정 레버는 여기 하나뿐이다** —
/// "빽빽하다"면 0.6~0.7 로, "허전하다"면 0.35~0.4 로 바꾸면 전 화면에 반영된다.
const double kBbSpaceCouplingExponent = 0.5;

/// 결합 기준 본문 폰트(이 값에서 계수가 1.0).
const double kBbSpaceReferenceBody = 14;

/// 여백 토큰 — **폰트 비율의 제곱근**으로 결합한다.
///
/// ```
/// space(token)  = base[token] × sqrt( effectiveBody / 14 )
/// effectiveBody = textScaler.scale( body(W) )
/// ```
///
/// `textScaler`(접근성 확대)를 **분자에 포함**한다 → 배율을 올리면 여백도 따라
/// 커진다. 넣지 않으면 글자만 커지고 숨 쉴 공간은 그대로라 빽빽해진다.
///
/// ★`EdgeInsets` 를 직접 만들 수 있는 경로를 노출하지 않는다.
@immutable
class BbSpace {
  const BbSpace._(this.factor);

  factory BbSpace.of(BuildContext context) => BbSpace.forWidth(
        BbScaleScope.maybeOf(context) ?? MediaQuery.sizeOf(context).width,
        scaler: MediaQuery.textScalerOf(context),
      );

  /// 컨테이너 폭 기준. [scaler] 를 주지 않으면 배율 1.0.
  factory BbSpace.forWidth(double width, {TextScaler? scaler}) {
    final body = BbType.forWidth(width).body;
    final effective = (scaler ?? TextScaler.noScaling).scale(body);
    return BbSpace._(
      math
          .pow(effective / kBbSpaceReferenceBody, kBbSpaceCouplingExponent)
          .toDouble(),
    );
  }

  /// 기준값에 곱해지는 계수.
  final double factor;

  double value(BbSpaceToken token) => kBbSpaceBase[token]! * factor;

  double get xs => value(BbSpaceToken.xs);
  double get sm => value(BbSpaceToken.sm);
  double get md => value(BbSpaceToken.md);
  double get lg => value(BbSpaceToken.lg);
  double get xl => value(BbSpaceToken.xl);
  double get xxl => value(BbSpaceToken.xxl);

  EdgeInsets all(BbSpaceToken token) => EdgeInsets.all(value(token));

  EdgeInsets symmetric({BbSpaceToken? h, BbSpaceToken? v}) =>
      EdgeInsets.symmetric(
        horizontal: h == null ? 0 : value(h),
        vertical: v == null ? 0 : value(v),
      );

  EdgeInsets only({
    BbSpaceToken? left,
    BbSpaceToken? top,
    BbSpaceToken? right,
    BbSpaceToken? bottom,
  }) =>
      EdgeInsets.only(
        left: left == null ? 0 : value(left),
        top: top == null ? 0 : value(top),
        right: right == null ? 0 : value(right),
        bottom: bottom == null ? 0 : value(bottom),
      );

  /// 가로 간격.
  Widget gapH(BbSpaceToken token) => SizedBox(width: value(token));

  /// 세로 간격.
  Widget gapV(BbSpaceToken token) => SizedBox(height: value(token));

  /// 반지름도 같은 계수를 탄다. **hairline(0.5/1.0)은 결합하지 않는다**(L4).
  BorderRadius radius(BbSpaceToken token) =>
      BorderRadius.circular(value(token));

  @override
  bool operator ==(Object other) => other is BbSpace && other.factor == factor;

  @override
  int get hashCode => factor.hashCode;
}

/// `context.bbType.body` · `context.bbSpace.md`
extension BbScaleContext on BuildContext {
  BbType get bbType => BbType.of(this);
  BbSpace get bbSpace => BbSpace.of(this);
}
