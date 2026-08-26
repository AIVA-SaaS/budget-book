import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:budget_book/core/widgets/color_picker.dart';
import 'package:budget_book/core/widgets/icon_picker.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';

/// 예산 목록 한 행.
///
/// ## 왜 `ListTile` 이 아닌가 `[측정 2026-08-26]`
///
/// 종전 `budget_list_page.dart:_buildBudgetTile` 은 `ListTile` 이었다. `ListTile` 은
/// **프레임워크가 높이를 소유**하고 그 높이는 콘텐츠를 따라간다. 그런데 부제목 Column
/// 안의 프로그레스바가 `budgetAmount <= 0` 일 때 `SizedBox.shrink()` 를 돌려줘서
/// **행마다 잉크 높이가 갈렸다** → 사용자 보고 "예산 간의 위아래 항목 높이가 다르다".
///
/// `EntityTileRow` 는 **앱이 높이를 소유**한다:
/// ```
/// 박스 = max(잉크 + 2 × xs, 터치 슬롯 44)
/// ```
/// 그래서 **모든 행의 잉크 구성이 같기만 하면** 높이가 자동으로 같아진다. 통과 판정을
/// 받은 자산·카테고리 탭이 쓰는 것과 같은 계약이고, 사용자가 "자산처럼"이라고 말한 것이
/// 바로 이것이다.
///
/// ## 그래서 이 위젯이 지키는 불변식
///
/// 1. **프로그레스 자리는 항상 예약한다** — 예산액이 0 이어도 빈 트랙을 그린다.
///    자리를 비우면 그 행만 낮아지고, 그게 원래 결함이다.
/// 2. **부제목은 항상 한 줄이다** — 개인 예산 표시도 별도 뱃지가 아니라 부제목 안에
///    넣는다. 뱃지는 칩 행을 새로 만들어 **그 행만 높아진다**.
/// 3. **메뉴는 슬롯에 둔다** — `trailingAction` 은 세로 흐름 **밖**이라 높이에 관여하지
///    않는다(2026-08-24 6차에서 세운 계약).
class BudgetTile extends StatelessWidget {
  const BudgetTile({
    super.key,
    required this.budget,
    required this.summaryItem,
    required this.numberFormat,
    required this.showPrivateMark,
    required this.onTap,
    this.menu,
    this.onMenuSelected,
  });

  final Budget budget;
  final BudgetSummaryItem? summaryItem;
  final NumberFormat numberFormat;

  /// 커플 모드에서만 개인 예산임을 밝힌다.
  final bool showPrivateMark;

  final VoidCallback onTap;

  /// ⋮ 메뉴 항목. 슬롯에 들어가므로 행 높이에 영향이 없다.
  final List<EntityMenuAction>? menu;
  final ValueChanged<String>? onMenuSelected;

  /// 사용률 → 의미 톤. 색은 `BbColors` 가 소유한다(하드코딩 팔레트 금지 래칫).
  static EntityTone _progressTone(double usageRate) {
    if (usageRate > 100) return EntityTone.negative;
    if (usageRate >= 80) return EntityTone.warn;
    return EntityTone.positive;
  }

  @override
  Widget build(BuildContext context) {
    final usageRate = summaryItem?.usageRate ?? 0.0;
    final budgetAmount =
        summaryItem?.budgetAmount ?? budget.effectiveMonthlyAmount;
    final spentAmount = summaryItem?.spentAmount ?? 0;

    // ★값이 없어도 트랙은 그린다. 자리를 비우면 그 행만 낮아지고
    //   "항목 높이가 다르다" 가 그대로 재발한다.
    final ratio =
        budgetAmount <= 0 ? 0.0 : (spentAmount / budgetAmount).clamp(0.0, 1.0);

    // 개인 표시는 **부제목 안**에 넣는다 — 뱃지로 만들면 칩 행이 생겨 그 행만 높아진다.
    final spentText =
        '${numberFormat.format(spentAmount)}원 (${usageRate.toStringAsFixed(1)}%)';
    final subtitle = showPrivateMark ? '개인 · $spentText' : spentText;

    return EntityTileRow(
      title: budget.targetLabel,
      subtitle: subtitle,
      trailingMetric: EntityMetric(
        value: '${numberFormat.format(budgetAmount)}원',
      ),
      leadingIcon: resolveIcon(budget.category?.icon),
      leadingColor: parseHexColor(budget.category?.color),
      progress: EntityProgress(
        value: ratio,
        tone: _progressTone(usageRate),
      ),
      overflowMenu: (menu == null || onMenuSelected == null)
          ? null
          : EntityOverflowMenu(items: menu!, onSelected: onMenuSelected!),
      // ★금액을 제목 행에 고정한다. 기본 동작은 제목이 길면 금액을 칩 행으로
      //   내리는데, 칩 행은 **그 행만** 25.19px 높인다 `[측정 2026-08-26]`.
      //   이 화면의 요구는 행 간 높이 동일성이므로 그 대가가 더 크다.
      keepMetricInline: true,
      onTap: onTap,
    );
  }
}
