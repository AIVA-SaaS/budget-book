import 'package:flutter/material.dart';

/// A single item in a FilterChipGroup.
class FilterChipItem {
  final String? value;
  final String label;

  const FilterChipItem({required this.value, required this.label});
}

/// A horizontal scrolling group of FilterChips for status/type filters.
///
/// Used by spending_plan status filters, visibility segments, etc.
class FilterChipGroup extends StatelessWidget {
  final List<FilterChipItem> items;
  final String? selectedValue;
  final ValueChanged<String?> onSelected;
  final bool showCheckmark;

  const FilterChipGroup({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.showCheckmark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selectedValue == item.value;
          return FilterChip(
            label: Text(item.label),
            selected: isSelected,
            onSelected: (_) {
              onSelected(isSelected ? null : item.value);
            },
            showCheckmark: showCheckmark,
          );
        },
      ),
    );
  }
}
