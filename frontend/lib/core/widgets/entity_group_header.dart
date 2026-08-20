import 'package:flutter/material.dart';

import 'package:budget_book/core/theme/bb_scale.dart';

/// 목록의 **그룹 구분 헤더** — `현금` · `은행 / 체크` · `카드` 처럼 타일 묶음 위에 놓인다.
///
/// 왜 위젯인가 (2026-08-21 실측): 같은 자산 그룹 목록을 그리는 손수 작성 구현이 **두 개**
/// 있었다. 자산 탭은 평면 목록 + 토큰 헤더였고(그룹 경계 ≈19dp), 분석>예산의 자산현황은
/// 그룹마다 `Container(margin 8, padding all(12), border)` 를 직접 조립해 **32dp** 였다.
/// 리터럴만 이관하면 다음 화면에서 또 갈린다 — 완료 기준은 "토큰을 썼다"가 아니라
/// **"경쟁 경로를 0개로 만들었다"** 다(하네스 `ui_pattern` 3회+ 재발).
///
/// ★API 를 값 타입으로 봉인한다: [label]·[icon]·[color] 만 받고 `padding`·`fontSize`·
/// `Widget` 슬롯을 **노출하지 않는다**. 호출부가 여백·폰트를 적을 경로 자체가 없다.
/// 여백이 다시 새려면 이 위젯을 우회해야 하고 그건 `tool/check_ui_scaling.py` 와
/// `test/core/widgets/vertical_rhythm_guard_test.dart` 가 잡는다.
///
/// 세로 리듬: 위 `md` · 아래 `xs`. 타일 내부 세로 padding(`EntityTileRow` = `md`)과 합쳐
/// 그룹 경계가 결정된다 — 두 값 모두 **각자 한 곳**에만 있다.
class EntityGroupHeader extends StatelessWidget {
  const EntityGroupHeader({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  final String label;

  final IconData? icon;

  /// 그룹 색. 사용자가 고른 색은 `context.bb.readable()` 로 이미 보정돼 있어야 한다.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final space = context.bbSpace;
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: space.only(
        left: BbSpaceToken.xl,
        top: BbSpaceToken.md,
        right: BbSpaceToken.xl,
        bottom: BbSpaceToken.xs,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: context.bbType.iconSm, color: tint),
            space.gapH(BbSpaceToken.md),
          ],
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tint,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
