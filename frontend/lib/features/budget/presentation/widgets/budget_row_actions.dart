import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/utils/dialog_helpers.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/widgets/budget_transactions_sheet.dart';

/// 예산 행 공통 액션 — 클릭=편집, PopupMenu=거래보기/수정/삭제.
///
/// **이 위젯/메서드 외에서는 budget 행에 PopupMenu / `/budgets/edit` push 인라인 작성 금지.**
/// (월간 / 주간 hero / 주차 카드의 행 동선 통일 목적, 하네스 audit `budget_row_action_unification` 패턴 강제)
///
/// 시그니처는 누락 가능 필드(`categoryGroupId`, `dateFrom/dateTo`)를 explicit nullable 로 받아
/// 호출부에서 명시적으로 null 또는 값 전달을 강제한다 (filter_propagation 회귀 방지).
///
/// 사용 패턴 두 가지:
///  1. 위젯 형태: `BudgetRowActions(...child: ...)` — 행 전체를 InkWell 로 감싸 onTap=편집.
///  2. 정적 메서드: ListTile 등 자체 onTap/trailing 이 있는 컨테이너에서는
///     `BudgetRowActions.openEdit(context, ...)` + `BudgetRowActions.menuButton(...)` 조합.
class BudgetRowActions extends StatelessWidget {
  /// 편집/삭제 대상 budget(monthly) ID
  final String budgetId;

  /// 카테고리 ID (카테고리 단위 예산일 때만 non-null)
  final String? categoryId;

  /// 카테고리 그룹 ID (그룹 단위 예산일 때만 non-null)
  final String? categoryGroupId;

  /// 거래 보기 시트 / 삭제 다이얼로그 라벨
  final String label;

  /// 거래 보기 필터 시작일 (yyyy-MM-dd). 주간 행이면 weekStart, 월간이면 null.
  final String? dateFrom;

  /// 거래 보기 필터 종료일 (yyyy-MM-dd). 주간 행이면 weekEnd, 월간이면 null.
  final String? dateTo;

  /// 편집/거래 보기 시트가 사용할 year (PathParam 가 아닌 query)
  final int year;

  /// 편집/거래 보기 시트가 사용할 month
  final int month;

  /// 행 자체. 클릭 시 편집 진입.
  final Widget child;

  /// 삭제 후 호출되는 콜백. `WeeklyBudgetBloc` reload 등 부모 측 갱신용.
  /// 월간 모드는 BudgetBloc 자체 reload 가 처리하므로 no-op 으로 전달 가능.
  final VoidCallback onAfterDelete;

  /// PopupMenu icon 위치 — 수직 정렬용. trailing 영역에 끼우려면 [trailingMenu] 사용.
  final bool showInlineMenu;

  const BudgetRowActions({
    super.key,
    required this.budgetId,
    required this.categoryId,
    required this.categoryGroupId,
    required this.label,
    required this.dateFrom,
    required this.dateTo,
    required this.year,
    required this.month,
    required this.child,
    required this.onAfterDelete,
    this.showInlineMenu = false,
  });

  /// PopupMenu 위젯만 반환 (trailing 영역에 별도 배치하고 싶을 때).
  /// 값 타입 메뉴 항목 — `EntityTileRow.overflowMenu` 가 렌더한다.
  /// `buildMenu` 의 PopupMenuItem 3종과 **같은 목록**이어야 한다.
  static const List<EntityMenuAction> menuItems = <EntityMenuAction>[
    EntityMenuAction(
        value: 'transactions', label: '거래 보기', icon: Icons.receipt_long),
    EntityMenuAction(value: 'edit', label: '수정', icon: Icons.edit),
    EntityMenuAction(
        value: 'delete', label: '삭제', icon: Icons.delete, destructive: true),
  ];

  /// 위 항목 선택을 처리한다(`buildMenu` 와 같은 경로).
  static Future<void> handleMenuValue(
    BuildContext context,
    String value, {
    required String budgetId,
    required String? categoryId,
    required String? categoryGroupId,
    required String label,
    required String? dateFrom,
    required String? dateTo,
    required int year,
    required int month,
    required VoidCallback onAfterDelete,
  }) {
    return BudgetRowActions(
      budgetId: budgetId,
      categoryId: categoryId,
      categoryGroupId: categoryGroupId,
      label: label,
      dateFrom: dateFrom,
      dateTo: dateTo,
      year: year,
      month: month,
      onAfterDelete: onAfterDelete,
      child: const SizedBox.shrink(),
    )._handleMenu(context, value);
  }

  Widget buildMenu(BuildContext context) {
    final box = context.bbBox;
    // ★메뉴 버튼의 **레이아웃 높이**는 아바타 기준이다 `[측정 2026-08-24]`.
    // 기본 IconButton 은 48dp 정사각이라 이 버튼이 든 행의 박스를 밀어올려
    // **주간 카드 내부 행 사이가 28dp**(승인값 20)였다. 히트 영역 44 는 OverflowBox 로 유지.
    // 같은 처방을 `entity_tile_row.dart` 의 액션 슬롯 4곳에도 적용했다.
    return SizedBox(
      width: box.actionSlot,
      // 높이는 **아이콘 사다리**다 — 아바타(32/40)로 두면 아바타가 없는 행
      // (주간 카드 내부)에서 그 차이가 그대로 slack 이 되어 사이를 벌린다 `[측정]`.
      height: box.actionIcon,
      child: OverflowBox(
        minHeight: box.actionSlot,
        maxHeight: box.actionSlot,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          onSelected: (value) => _handleMenu(context, value),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'transactions',
              child: Row(children: [
                Icon(Icons.receipt_long, size: context.bbType.iconSm),
                const SizedBox(width: 8),
                const Text('거래 보기'),
              ]),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit, size: context.bbType.iconSm),
                const SizedBox(width: 8),
                const Text('수정'),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete, size: context.bbType.iconSm, color: Colors.red),
                const SizedBox(width: 8),
                const Text('삭제', style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tappable = InkWell(
      onTap: () => _pushEdit(context),
      child: child,
    );

    if (!showInlineMenu) return tappable;

    return Row(
      children: [
        Expanded(child: tappable),
        buildMenu(context),
      ],
    );
  }

  void _pushEdit(BuildContext context) {
    openEdit(context, budgetId: budgetId, year: year, month: month);
  }

  /// 편집 진입 단일 진입점. 인라인 `context.push('/budgets/edit/...')` 대신 항상 이 메서드 사용.
  static void openEdit(
    BuildContext context, {
    required String budgetId,
    required int year,
    required int month,
  }) {
    context.push('/budgets/edit/$budgetId?year=$year&month=$month');
  }

  /// PopupMenu 만 별도 trailing 으로 배치하고 싶을 때 사용.
  /// ListTile.trailing 처럼 자체 onTap 이 있는 컨테이너용.
  static Widget menuButton({
    required BuildContext context,
    required String budgetId,
    required String? categoryId,
    required String? categoryGroupId,
    required String label,
    required String? dateFrom,
    required String? dateTo,
    required int year,
    required int month,
    required VoidCallback onAfterDelete,
  }) {
    final actions = BudgetRowActions(
      budgetId: budgetId,
      categoryId: categoryId,
      categoryGroupId: categoryGroupId,
      label: label,
      dateFrom: dateFrom,
      dateTo: dateTo,
      year: year,
      month: month,
      onAfterDelete: onAfterDelete,
      child: const SizedBox.shrink(),
    );
    return actions.buildMenu(context);
  }

  Future<void> _handleMenu(BuildContext context, String value) async {
    if (value == 'transactions') {
      showBudgetTransactionsSheet(
        context: context,
        year: year,
        month: month,
        categoryId: categoryId,
        categoryGroupId: categoryGroupId,
        categoryName: label,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
    } else if (value == 'edit') {
      _pushEdit(context);
    } else if (value == 'delete') {
      final confirmed = await showDeleteConfirmDialog(
        context,
        title: '예산 삭제',
        itemName: label,
      );
      if (confirmed && context.mounted) {
        context.read<BudgetBloc>().add(DeleteBudget(budgetId));
        onAfterDelete();
      }
    }
  }
}
