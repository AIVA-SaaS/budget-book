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

/// 타이포의 폭비 압축 지수(4제곱근).
///
/// 1440 → 2560 에서 1.155배, 1440 → 360 에서 0.707배. `sqrt`(0.5)보다 완만해
/// 큰 화면에서 글자만 비대해지지 않는다.
const double kBbTypeExponent = 0.25;

/// 공간의 폭비 압축 지수(제곱근) — **타이포보다 탄성이 크다**.
///
/// ★왜 타이포(0.25)와 다른가 `[측정 2026-08-20]`: 사용자가 승인한 자산 탭의
/// 320→960 스팬은 여백이 `padH 10→16 = 1.60배` 인데 본문 폰트는 `13→15 = 1.15배` 다.
/// 종전 결합식(`space ∝ body^0.5`, 순 폭지수 0.125)의 최대 스팬은 1.15배라
/// **어떤 ref/clamp 로도 승인값을 지나갈 수 없었다**(폭지수 0.125 로 상한 16 을 960 에서
/// 맞추면 390px 에서 14.3dp — 승인값 10). 필요한 지수는 `ln(0.625)/ln(1/3) = 0.428` 이상.
///
/// 즉 "여백은 폰트보다 탄성이 커야 한다"는 도그마가 아니라 승인된 표면의 실측이다.
///
/// ⚠ 지수는 이 둘(0.25 · 0.5)뿐이다. 토큰마다 자기 지수를 갖게 되면 축이 다시 늘어난다.
const double kBbSpaceExponent = 0.5;

/// 폭비 → 배율. 모든 크기 축이 이 함수 하나를 지난다(계단 없음).
double bbProgress(double width, double exponent) =>
    math.pow(width / kBbTypeReferenceWidth, exponent).toDouble();

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

  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BbScaleScope>()?.width;

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
/// `ref > max` 인 역할이 있다 — 기준 폭(1440)에서 이미 상한에 닿아 있다는 뜻이고,
/// 그래야 좁은 쪽 곡선이 자산 탭 실측값을 지나간다.
///
/// ★기준점은 **자산 탭**이다(2026-08-19 사용자 검증: "자산 내 글자 크기가 딱 적절하다").
/// `BbDensity` 의 타일 폰트 3단 값(compact/regular/wide)을 **연속 곡선이 지나가도록**
/// ref/min/max 를 역산했다. 역산 표는 `app_theme.dart` 의 `_slots` 주석에 있다.
///
/// ⚠ 이전 판은 `min == ref` 로 두어 "작은 화면에서 본문을 줄이지 않는다"를 지켰으나,
/// **1440px 아래에서 본문이 통째로 상수**가 되어 폭에 반응하지 않았고 자산 탭보다
/// 2px 컸다. 사용자가 지적한 "거래/분석/더보기가 크다" 가 그 귀결이다.
/// 하한은 여전히 **가독 기준 px** 이고(비율 아님), 다만 그 기준을 자산 탭 실측으로 옮겼다.
const Map<BbTextRole, ({double ref, double min, double max})> kBbTextSpec = {
  BbTextRole.display: (ref: 25, min: 17, max: 22), // headlineSmall
  BbTextRole.title: (ref: 21.1, min: 15, max: 19), // titleLarge / 자산 hdrV
  BbTextRole.section: (ref: 17.8, min: 14, max: 16), // titleMedium / 자산 title
  BbTextRole.body: (ref: 16.7, min: 13, max: 15), // bodyMedium / 자산 metric
  BbTextRole.label: (ref: 13.3, min: 11, max: 12), // bodySmall / 자산 hdrL
  BbTextRole.caption: (ref: 13.4, min: 10, max: 12), // labelSmall / 자산 chip
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

  double _clamped(({double ref, double min, double max}) spec) =>
      bbClamped(spec, width, kBbTypeExponent);

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

/// 역할별 `(ref, min, max)`. `min`/`max` 는 **가독·기하 기준 px** 이다(비율이 아니다).
///
/// ★기준점은 **자산 탭**이다 — 폰트 회차(2026-08-19)와 같은 방법으로, 사용자가 승인한
/// `BbDensity` 3단 값을 **연속 곡선이 지나가도록** 역산했다. `ref = max / (960/1440)^0.5`
/// 이므로 상한을 콘텐츠 최대폭 960 에서 정확히 찍는다.
///
/// ```
/// 토큰(자산 앵커)      min max │  320   360   390   768   960  1440
/// xl  ← tilePaddingH   10  16 │ 10.0  10.0  10.2  14.3  16.0  16.0
/// lg  ← tilePaddingV    8  12 │  8.0   8.0   8.0  10.7  12.0  12.0
/// md  ← gap             6  10 │  6.0   6.1   6.4   8.9  10.0  10.0
/// sm  ← chipPaddingH    5   8 │  5.0   5.0   5.1   7.2   8.0   8.0
/// xs  (앵커 없음)        3   4 │  3.0   3.0   3.0   3.6   4.0   4.0
/// xxl (앵커 없음)       15  24 │ 15.0  15.0  15.3  21.5  24.0  24.0
/// ```
///
/// ⚠ 종전 판은 `base × sqrt(body(W)/14)` 였고 `body` 가 `13~15` 로 clamp 돼 있어
/// 계수 범위가 `0.964~1.035`(7%) 뿐이었다 — **폭 8배에 여백 0.57dp** = 사실상 상수.
/// 원인은 아래 층(폰트)의 clamp 가 위 층(여백)을 묶는 **층 의존 부작용**이고, 폰트에서
/// 한 번 겪은 것과 같은 구도였다(2회). 그래서 이제 **각 토큰이 자기 px clamp** 를 갖는다.
///
/// ★`xs` 는 **폭에 대해 상수(4.0)** 다. 원래 (3,4) 였는데 사용자 승인값 조정
/// (항목 사이 18.0 → **20.0dp @390**, 2026-08-21)으로 하한이 상한과 같아졌다.
/// 이 크기에서 "곡선"은 폭 8배에 **1dp** = 지각 불가능한 노이즈라 축을 없애는 편이 맞다.
/// 항목 사이 계산: `사이 = 2 × padV + (아바타 − 텍스트줄)` = `2×4 + 12` = 20.0 @390.
const Map<BbSpaceToken, ({double min, double max})> kBbSpaceSpec = {
  BbSpaceToken.xs: (min: 4, max: 4),
  BbSpaceToken.sm: (min: 5, max: 8),
  BbSpaceToken.md: (min: 6, max: 10),
  BbSpaceToken.lg: (min: 8, max: 12),
  BbSpaceToken.xl: (min: 10, max: 16),
  BbSpaceToken.xxl: (min: 15, max: 24),
};

/// 폰트↔여백 결합 지수 — **부분 결합 = 제곱근**(calynda 2026-08-14 사용자 결정).
///
/// 이 지수는 이제 **접근성 배율(textScaler)** 에만 걸린다. 폭 결합은
/// [kBbSpaceExponent] 가 담당한다 — 폰트의 **클램프된 출력**에 묶으면 상한/하한이
/// 여백까지 굳혀 버린다(위 ⚠ 참조).
const double kBbSpaceCouplingExponent = 0.5;

/// 결합 기준 본문 폰트(이 값에서 배율 계수가 1.0).
const double kBbSpaceReferenceBody = 14;

/// `(ref, min, max)` spec → px. 타이포·아이콘이 쓴다(`ref` 는 1440px 기준값).
double bbClamped(
  ({double ref, double min, double max}) spec,
  double width,
  double exponent,
) =>
    (spec.ref * bbProgress(width, exponent)).clamp(spec.min, spec.max);

/// `(min, max)` spec → px. 공간·박스가 쓴다.
///
/// ★`ref` 를 적지 않는다. 상한은 **콘텐츠 최대폭([kBbContentMaxWidth])에서 정확히**
/// 찍히도록 유도한다 — `ref` 를 손으로 적으면(`max / 0.8165` 를 반올림) 960px 에서
/// `9.9996` 같은 값이 나와 승인값과 미세하게 어긋난다(2026-08-20 실측).
/// 단일 소스는 **두 개의 px 경계**이고 곡선은 거기서 파생된다.
double bbSaturating(
  ({double min, double max}) spec,
  double width,
  double exponent,
) {
  final raw = spec.max *
      bbProgress(width, exponent) /
      bbProgress(kBbContentMaxWidth, exponent);
  return raw.clamp(spec.min, spec.max);
}

/// 여백 토큰.
///
/// ```
/// space(token, W, scaler)
///   = clamp( min_px, ref × (W/1440)^0.5 , max_px ) × ( scaler(14)/14 )^0.5
/// ```
///
/// ★배율 결합은 **clamp 밖**이다. 안에 넣으면 상한에 잘려 배율을 올릴수록
/// "글자만 커지고 숨 쉴 공간은 그대로"가 된다(도메인 ★4 의 실질).
///
/// ★`EdgeInsets` 를 직접 만들 수 있는 경로를 노출하지 않는다 — 리터럴이 새려면 이 API 를
/// 우회해야 하고 그건 `tool/check_ui_scaling.py` 가 잡는다.
@immutable
class BbSpace {
  const BbSpace._(this.width, this.scaleFactor);

  factory BbSpace.of(BuildContext context) => BbSpace.forWidth(
        BbScaleScope.maybeOf(context) ?? MediaQuery.sizeOf(context).width,
        scaler: MediaQuery.textScalerOf(context),
      );

  /// 컨테이너 폭 기준. [scaler] 를 주지 않으면 배율 1.0.
  factory BbSpace.forWidth(double width, {TextScaler? scaler}) {
    final ratio =
        (scaler ?? TextScaler.noScaling).scale(kBbSpaceReferenceBody) /
            kBbSpaceReferenceBody;
    return BbSpace._(
      width,
      math.pow(ratio, kBbSpaceCouplingExponent).toDouble(),
    );
  }

  /// 이 토큰이 기준으로 삼는 폭.
  final double width;

  /// 접근성 배율에서 온 계수(clamp 밖에서 곱해진다).
  final double scaleFactor;

  double value(BbSpaceToken token) =>
      bbSaturating(kBbSpaceSpec[token]!, width, kBbSpaceExponent) * scaleFactor;

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

  /// 반지름도 같은 곡선을 탄다. **hairline(0.5/1.0)은 결합하지 않는다**(L4).
  BorderRadius radius(BbSpaceToken token) =>
      BorderRadius.circular(value(token));

  @override
  bool operator ==(Object other) =>
      other is BbSpace &&
      other.width == width &&
      other.scaleFactor == scaleFactor;

  @override
  int get hashCode => Object.hash(width, scaleFactor);
}

// ─────────────────────────────────────────────────────────────────────────────
// 박스·크롬 토큰
// ─────────────────────────────────────────────────────────────────────────────

/// 슬롯 기하 역할 — 아바타·액션 슬롯·크롬 높이.
///
/// 왜 공간 곡선(0.5)을 타나: 이들은 **텍스트 줄이 아니라 슬롯 기하**에 묶인다.
/// 타이포 곡선(0.25)으로 계산하면 승인값과의 768 대역 오차가 커진다
/// (`avatarIcon` −0.32 → +0.81) `[측정 2026-08-20]`.
///
/// 접근성 배율은 곱하지 않는다 — `Icon` 은 `textScaler` 를 타지 않으므로 슬롯만 커지면
/// 아이콘이 슬롯 안에서 떠 버린다.
enum BbBoxRole {
  /// 타일 선두 아바타 지름.
  avatar,

  /// 아바타 안 아이콘.
  avatarIcon,

  /// 액션 아이콘(토글·메뉴·드래그 핸들).
  actionIcon,

  /// 액션 탭 타깃 한 변. **L4-2: 44dp 하한을 넘지 않는다.**
  actionSlot,

  /// M3 `Switch` 트랙 폭. **L4-3: 시스템 위젯 고정 치수**라 곡선을 타지 않는다
  /// (`Transform.scale` 은 예약 폭을 줄이지 못한다 — 2026-05-04 오진).
  toggleSlot,

  /// 탭 한 줄 높이. `Tab(icon:, text:)` 는 세로 배치라 SDK 가 72 를 강제한다
  /// (`tabs.dart:205`) — `bb_tab.dart` 가 가로 배치로 이 값을 쓴다.
  tab,

  /// 하단 네비 높이. ⚠ `NavigationBar` 는 `SizedBox` 하드 박스라 과하게 낮추면
  /// 오버플로한다 — 스윕이 배율 1.6 까지 검사한다.
  navBar,

  /// **프레임워크 `ListTile` 의 세로 여백**(`ListTileThemeData.minVerticalPadding`).
  ///
  /// 왜 별도 역할인가 `[측정 2026-08-21]`: `ListTile` 은 높이를 **SDK 가 소유**한다
  /// (M3 기본 1줄 56 · 2줄 72 + `visualDensity`). 그래서 우리 타일(`EntityTileRow`,
  /// 사이 20.0dp)과 나란히 두면 **사이 34.8dp** 로 훨씬 헐렁했다.
  /// `minTileHeight` 를 지정하면 SDK 기본 높이 경로가 꺼지고 높이가 내용 기반이 되며
  /// **2줄 항목 사이 = 2 × 이 값**이 된다 — 그래서 목표 사이의 절반을 넣는다.
  listRowPadV,

  /// **프레임워크 `ListTile` 의 최소 높이**(`ListTileThemeData.minTileHeight`).
  ///
  /// **1줄 항목 사이 = 이 값 − 제목 줄 높이**(14 @390 · 16 @960) `[측정]`.
  /// ⚠ 34dp 는 44dp 터치 하한을 밑돈다 — 사용자가 승인한 "항목 사이 20dp" 를 1줄
  /// 항목에도 적용한 결과다. 되돌리려면 `min` 을 44 로 올린다(사이 30dp).
  listRowMinHeight,
}

/// 자산 탭 승인값(compact = 하한 / wide = 상한). 상한은 960px 에서 찍힌다.
///
/// ```
/// 역할        min max │  320   390   768   960  1440
/// avatar       32  40 │ 32.0  32.0  35.8  40.0  40.0
/// avatarIcon   18  22 │ 18.0  18.0  19.7  22.0  22.0
/// actionIcon   20  24 │ 20.0  20.0  21.5  24.0  24.0
/// actionSlot   44  48 │ 44.0  44.0  44.0  48.0  48.0
/// tab          44  48 │ 44.0  44.0  44.0  48.0  48.0
/// navBar       66  80 │ 66.0  66.0  71.6  80.0  80.0
/// ```
///
/// `actionSlot` 하한은 승인 표면의 40 이 아니라 **44**(L4-2 터치 하한)다. 320px 편집
/// 모드에서 액션 레인이 8dp 넓어지지만 접근성 규격이 이긴다 — 되돌리려면 `min` 을 40 으로.
const Map<BbBoxRole, ({double min, double max})> kBbBoxSpec = {
  BbBoxRole.avatar: (min: 32, max: 40),
  BbBoxRole.avatarIcon: (min: 18, max: 22),
  BbBoxRole.actionIcon: (min: 20, max: 24),
  BbBoxRole.actionSlot: (min: 44, max: 48),
  BbBoxRole.toggleSlot: (min: 52, max: 52),
  BbBoxRole.tab: (min: 44, max: 48),
  BbBoxRole.navBar: (min: 66, max: 80),
  // 목록 행 = **모든 목록의 항목 사이를 20.0/25.0dp 로 맞추는 값** `[측정 2026-08-21]`.
  // 사이(2줄) = 2 × listRowPadV · 사이(1줄) = listRowMinHeight − 제목줄(14/16).
  BbBoxRole.listRowPadV: (min: 10, max: 12.5),
  BbBoxRole.listRowMinHeight: (min: 34, max: 41),
};

/// 슬롯·크롬 치수. 계단(`width < 600 ? … : …`)을 대체한다 — 새 폭 분기는
/// `no_step_ladder_guard_test.dart` 가 막는다.
@immutable
class BbBox {
  const BbBox._(this.width);

  factory BbBox.of(BuildContext context) => BbBox._(
        BbScaleScope.maybeOf(context) ?? MediaQuery.sizeOf(context).width,
      );

  factory BbBox.forWidth(double width) => BbBox._(width);

  final double width;

  double size(BbBoxRole role) =>
      bbSaturating(kBbBoxSpec[role]!, width, kBbSpaceExponent);

  double get avatar => size(BbBoxRole.avatar);
  double get avatarIcon => size(BbBoxRole.avatarIcon);
  double get actionIcon => size(BbBoxRole.actionIcon);
  double get actionSlot => size(BbBoxRole.actionSlot);
  double get toggleSlot => size(BbBoxRole.toggleSlot);
  double get tab => size(BbBoxRole.tab);
  double get navBar => size(BbBoxRole.navBar);
  double get listRowPadV => size(BbBoxRole.listRowPadV);
  double get listRowMinHeight => size(BbBoxRole.listRowMinHeight);

  @override
  bool operator ==(Object other) => other is BbBox && other.width == width;

  @override
  int get hashCode => width.hashCode;
}

/// `context.bbType.body` · `context.bbSpace.md` · `context.bbBox.avatar`
extension BbScaleContext on BuildContext {
  BbType get bbType => BbType.of(this);
  BbSpace get bbSpace => BbSpace.of(this);
  BbBox get bbBox => BbBox.of(this);
}
