import 'package:flutter/material.dart';

import 'package:budget_book/core/theme/bb_scale.dart';

/// 카드형 **목록 항목**의 세로 리듬 단일 소유자 (2026-08-24, 세로 리듬 4차).
///
/// ## 왜 이 위젯이 있나
///
/// 사용자 요청은 "항목 1과 2 **사이**를 좁혀라, **모든 목록**에" 였고 승인값은
/// **20.0dp @390 · 25.0dp @960** 이다. 3차(PR #308)에서 우리 타일(`EntityTileRow`)과
/// 프레임워크 `ListTile` 은 그 값을 지나가게 됐지만 **카드형은 남아 있었다**
/// `[측정 2026-08-24]`:
///
/// - 통계 > 카테고리별 **34.2 / 48.0** (승인값의 1.71× / 1.92×)
/// - 통계 > 결제수단별 **32.0 / 32.0**
/// - 통계 > 전년 비교 **62.7 / 67.5**
/// - 예산 > 주간 카드 **75.2 / 80.5**
///
/// ⚠ 3차의 처방(테마 2값)이 카드에 통하지 않은 이유: `cardTheme.margin` 은 전역이지만
/// **호출부가 margin 을 덮어쓰는 곳이 18건**이었다(결제수단별 `only(bottom: 8)` 등).
/// 테마 한 줄은 그 화면들에 **도달하지 않는다**.
///
/// ## 계약
///
/// 사이 = `2 × (Card margin 세로 + 카드 내부 padding 세로)`
///      = `2 × (space.xs + box.cardRowPadV)` = `2 × (4 + 6)` = **20.0 @390**
///      = `2 × (4 + 8.5)` = **25.0 @960**
///
/// **세로 축 인자를 노출하지 않는다.** 리터럴이 새려면 이 위젯을 우회해야 하고 그건
/// `tool/check_ui_scaling.py` 와 `bb_card_tile_adoption_test.dart` 가 잡는다.
/// 승인값 자체는 `vertical_rhythm_guard_test.dart`(V3)가 소유한다 — 여기서 읽어 오면
/// 순환 검증이 된다.
///
/// 가로는 **이번 축이 아니다**. 호스트가 지금 쓰는 값을 그대로 전달하도록
/// [hMargin] · [hPadding] 을 토큰으로만 받는다(리터럴 불가).
class BbCardTile extends StatelessWidget {
  const BbCardTile({
    super.key,
    required this.child,
    this.onTap,
    this.hMargin,
    this.hPadding = BbSpaceToken.lg,
    this.elevation,
    this.shape,
    this.color,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// 카드 좌우 여백. `null` 이면 0 (호스트 목록의 padding 이 담당하는 경우).
  final BbSpaceToken? hMargin;

  /// 카드 내부 좌우 여백.
  final BbSpaceToken hPadding;

  final double? elevation;
  final ShapeBorder? shape;
  final Color? color;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final space = context.bbSpace;
    final box = context.bbBox;

    final padded = Padding(
      // ★세로는 cardRowPadV 하나뿐. 가로는 호스트가 정한다(요청이 한 축이면 한 축만).
      padding: EdgeInsets.symmetric(
        horizontal: space.value(hPadding),
        vertical: box.cardRowPadV,
      ),
      child: child,
    );

    return Card(
      // ★세로 margin 은 xs(4.0 상수) 고정 — 이 값이 승인값 계산의 절반을 만든다.
      margin: EdgeInsets.symmetric(
        horizontal: hMargin == null ? 0 : space.value(hMargin!),
        vertical: space.xs,
      ),
      elevation: elevation,
      shape: shape,
      color: color,
      clipBehavior: clipBehavior,
      child: onTap == null
          ? padded
          : InkWell(
              onTap: onTap,
              borderRadius: space.radius(BbSpaceToken.md),
              child: padded,
            ),
    );
  }
}
