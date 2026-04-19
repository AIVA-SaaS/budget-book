import 'package:flutter/material.dart';
import 'package:budget_book/core/widgets/category_group_selector_sheet.dart';

/// Category selector widget for use within filter sheets.
/// Taps to open the existing CategoryGroupSelectorSheet.
class CategoryFilter extends StatelessWidget {
  final String? selectedCategoryId;
  final String? selectedCategoryName;
  final String categoryType;
  final void Function(String? id, String? name) onChanged;

  const CategoryFilter({
    super.key,
    this.selectedCategoryId,
    this.selectedCategoryName,
    this.categoryType = 'EXPENSE',
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => CategoryGroupSelectorSheet(
            selectedCategoryId: selectedCategoryId,
            categoryType: categoryType,
            onSelectedWithGroupName: (cat, groupName) {
              // 중첩 bottom sheet 의 Navigator.pop 과 parent 의 setSheetState
              // 가 동시에 발생하면 레이아웃 측정 race 로 UI 크래시 발생.
              // 다음 프레임으로 지연시켜 nested sheet dismiss → parent rebuild
              // 순서를 강제한다.
              final id = cat?.id;
              final name = cat != null
                  ? (groupName != null
                      ? '$groupName > ${cat.name}'
                      : cat.name)
                  : null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onChanged(id, name);
              });
            },
            onSelected: (_) {},
          ),
        );
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '카테고리',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedCategoryName ?? '전체',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
