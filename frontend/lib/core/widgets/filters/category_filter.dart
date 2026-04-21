import 'package:flutter/material.dart';
import 'package:budget_book/core/widgets/category_group_selector_sheet.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';

/// Category selector widget for use within filter sheets.
///
/// PR-C3: multi 선택 + 그룹 선택 지원.
/// 거래 폼과 동일한 `ItemSelectorField` 트리거 UI 사용으로 UI 패턴 통일.
/// 탭 시 [CategoryGroupSelectorSheet] 를 `multiCategoryWithGroup` 모드로 열어
/// 카테고리·그룹을 함께 고를 수 있다.
class CategoryFilter extends StatelessWidget {
  /// 현재 선택된 카테고리 ID 집합.
  final Set<String> selectedCategoryIds;

  /// 현재 선택된 카테고리 그룹 ID 집합.
  final Set<String> selectedGroupIds;

  /// 필드에 표시할 라벨 (예: "전체", "식비", "식비 외 2개").
  final String? displayLabel;

  final String categoryType;

  /// 사용자가 다중 선택을 적용했을 때 호출.
  final void Function(Set<String> categoryIds, Set<String> groupIds) onChanged;

  const CategoryFilter({
    super.key,
    this.selectedCategoryIds = const {},
    this.selectedGroupIds = const {},
    this.displayLabel,
    this.categoryType = 'EXPENSE',
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ItemSelectorField(
      label: '카테고리',
      selectedLabel: displayLabel,
      prefixIcon: Icons.category,
      placeholder: '전체',
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => CategoryGroupSelectorSheet(
            mode: CategorySelectionMode.multiCategoryWithGroup,
            initialCategoryIds: selectedCategoryIds,
            initialGroupIds: selectedGroupIds,
            categoryType: categoryType,
            onSelected: (_) {},
            onApplyMulti: (cats, groups) {
              // 다음 프레임으로 지연: nested dialog dismiss → parent rebuild
              // 순서를 강제하여 race-layout 크래시 방지.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onChanged(cats, groups);
              });
            },
          ),
        );
      },
    );
  }
}
