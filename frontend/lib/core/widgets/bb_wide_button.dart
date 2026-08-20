import 'package:flutter/material.dart';

import 'package:budget_book/core/theme/bb_scale.dart';

/// 아이콘을 붙일 쪽.
enum BbIconEdge { start, end }

/// 버튼 종류.
enum BbButtonVariant { filled, outlined, text }

/// **폭이 남는 자리**(전폭 CTA · `Expanded` · `stretch` 칼럼)용 버튼.
///
/// 왜 이 위젯이 있나 `[측정 2026-08-20]`
/// ------------------------------------
/// 사용자 지적: "거래 추가 시 `-1일 전` / `+1일 후` **문구**를 보면 왼쪽 여백이 더 길다."
/// 위젯 기하를 직접 읽어 보면 버튼의 좌우 여백은 **정확히 같다**:
///
/// ```
/// [1일 전] btn=0.00..191.00  icon=57.30..73.30  text=81.30..133.70
///          leftGap=57.30  rightGap=57.30
/// ```
///
/// 어긋난 것은 **라벨**이다. `*Button.icon` 은 `아이콘 + 간격 + 라벨` 을 한 덩어리로
/// 중앙 정렬하므로, 라벨만 보면 `아이콘폭(16) + 간격(8) = 24dp` 오른쪽으로 밀려 있다.
/// 프레임워크가 소유한 거동이라 `padding` 으로는 고쳐지지 않는다
/// (`reference_framework_owned_affordance` 와 같은 성질 — 경로를 더하지 말고 구조를 바꾼다).
///
/// 이 위젯은 **아이콘 레인을 양쪽에 대칭으로 예약**하고 라벨을 그 안에서 중앙에 둔다.
/// 그래서 라벨이 버튼 정중앙에 오고, 아이콘은 지정한 끝에 붙는다. 아이콘이 없어도
/// 같은 레인을 예약하지 않으므로 일반 전폭 버튼으로도 쓸 수 있다.
///
/// ★새 전폭 버튼은 이 위젯을 쓴다. `*Button.icon` 을 폭 남는 자리에 쓰면
/// `no_step_ladder_guard_test.dart` S4 가 막는다.
class BbWideButton extends StatelessWidget {
  const BbWideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconEdge = BbIconEdge.start,
    this.variant = BbButtonVariant.filled,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BbIconEdge iconEdge;
  final BbButtonVariant variant;

  /// 촘촘한 자리(보조 액션 행). 세로 여백을 한 단계 낮춘다.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final type = context.bbType;
    final space = context.bbSpace;
    final iconSize = type.iconSm;
    // 아이콘 레인은 **양쪽 모두** 예약한다 — 한쪽만 비우면 라벨이 다시 밀린다.
    final lane = icon == null ? 0.0 : iconSize + space.md;

    final child = Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: lane),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (icon != null)
          Align(
            alignment: iconEdge == BbIconEdge.start
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Icon(icon, size: iconSize),
          ),
      ],
    );

    final padding = space.symmetric(
      h: BbSpaceToken.md,
      v: dense ? BbSpaceToken.md : BbSpaceToken.xl,
    );

    return switch (variant) {
      BbButtonVariant.filled => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(padding: padding),
          child: child,
        ),
      BbButtonVariant.outlined => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(padding: padding),
          child: child,
        ),
      BbButtonVariant.text => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(padding: padding),
          child: child,
        ),
    };
  }
}
