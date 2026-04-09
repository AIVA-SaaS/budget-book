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
              onChanged(
                cat?.id,
                cat != null
                    ? (groupName != null
                        ? '$groupName > ${cat.name}'
                        : cat.name)
                    : null,
              );
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
