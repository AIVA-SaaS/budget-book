import 'package:flutter/material.dart';

/// Single item in a [SelectableChipGroup].
class ChipItem<T> {
  final T value;
  final String label;

  const ChipItem({required this.value, required this.label});
}

/// Layout direction for chips.
enum ChipGroupDirection { horizontal, wrap }

/// Common chip group for status / type / visibility filters.
///
/// Multi mode: first chip is "전체" (derived state — on when all individual
/// items are selected). Tapping it toggles select-all/clear-all.
///
/// Single mode: first chip "전체" represents null (no filter). Individual
/// chips replace the current selection.
class SelectableChipGroup<T> extends StatelessWidget {
  final List<ChipItem<T>> items;
  final String allLabel;
  final bool showCheckmark;
  final ChipGroupDirection direction;

  // Multi mode state (null in single mode)
  final Set<T>? _multiSelected;
  final ValueChanged<Set<T>>? _onMultiChanged;

  // Single mode state (null in multi mode; T? nullable to allow unselected)
  final T? _singleSelected;
  final ValueChanged<T?>? _onSingleChanged;

  final bool _isMulti;

  const SelectableChipGroup.multi({
    super.key,
    required this.items,
    required Set<T> selected,
    required ValueChanged<Set<T>> onChanged,
    this.allLabel = '전체',
    this.showCheckmark = true,
    this.direction = ChipGroupDirection.horizontal,
  })  : _multiSelected = selected,
        _onMultiChanged = onChanged,
        _singleSelected = null,
        _onSingleChanged = null,
        _isMulti = true;

  const SelectableChipGroup.single({
    super.key,
    required this.items,
    required T? selected,
    required ValueChanged<T?> onChanged,
    this.allLabel = '전체',
    this.showCheckmark = false,
    this.direction = ChipGroupDirection.horizontal,
  })  : _singleSelected = selected,
        _onSingleChanged = onChanged,
        _multiSelected = null,
        _onMultiChanged = null,
        _isMulti = false;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _buildAllChip(),
      ...items.map(_buildItemChip),
    ];

    if (direction == ChipGroupDirection.wrap) {
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        children: chips,
      );
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }

  Widget _buildAllChip() {
    final selected = _isMulti
        ? _multiSelected!.length == items.length && items.isNotEmpty
        : _singleSelected == null;
    return FilterChip(
      label: Text(allLabel),
      selected: selected,
      showCheckmark: showCheckmark,
      onSelected: (_) {
        if (_isMulti) {
          if (selected) {
            _onMultiChanged!(<T>{});
          } else {
            _onMultiChanged!(items.map((e) => e.value).toSet());
          }
        } else {
          _onSingleChanged!(null);
        }
      },
    );
  }

  Widget _buildItemChip(ChipItem<T> item) {
    final selected = _isMulti
        ? _multiSelected!.contains(item.value)
        : _singleSelected == item.value;
    return FilterChip(
      label: Text(item.label),
      selected: selected,
      showCheckmark: showCheckmark,
      onSelected: (on) {
        if (_isMulti) {
          final next = Set<T>.of(_multiSelected!);
          if (on) {
            next.add(item.value);
          } else {
            next.remove(item.value);
          }
          _onMultiChanged!(next);
        } else {
          _onSingleChanged!(on ? item.value : _singleSelected);
        }
      },
    );
  }
}
