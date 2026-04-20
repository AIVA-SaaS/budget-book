import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_bloc.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_event.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_state.dart';

class SelectorItem {
  final String id;
  final String label;
  final String? subtitle;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final bool isDeletable;
  final int displayOrder;

  /// Optional group key for section headers (e.g. payment method type).
  final String? group;

  const SelectorItem({
    required this.id,
    required this.label,
    this.subtitle,
    this.leadingIcon,
    this.leadingColor,
    this.isDeletable = true,
    this.displayOrder = 0,
    this.group,
  });
}

/// Selection mode for [ItemSelectorSheet].
///
/// - [single]: Legacy behavior — tapping an item fires [ItemSelectorSheet.onSelected]
///   and immediately pops the sheet.
/// - [multi]: Each tile renders a checkbox; tapping toggles membership in an
///   internal [Set]; a bottom apply bar invokes [ItemSelectorSheet.onApplyMulti]
///   with the final selection and then pops.
enum SelectionMode { single, multi }

class ItemSelectorSheet extends StatefulWidget {
  final String title;
  final List<SelectorItem> items;

  /// Selection mode. Defaults to [SelectionMode.single] for backward compatibility.
  final SelectionMode mode;

  /// Single-select: currently selected id (highlighted).
  final String? selectedId;

  /// Single-select callback. Required when [mode] == [SelectionMode.single].
  final ValueChanged<SelectorItem?>? onSelected;

  /// Multi-select: initially selected ids.
  final Set<String> initialSelectedIds;

  /// Multi-select callback. Required when [mode] == [SelectionMode.multi].
  /// Called once with the final set when the user presses the apply button.
  final void Function(Set<String> ids)? onApplyMulti;

  /// Multi-select upper bound. Beyond this, further checks are refused with a SnackBar.
  final int maxSelection;

  final ValueChanged<String>? onDelete;
  final ValueChanged<SelectorItem>? onEdit;
  final VoidCallback? onCreate;
  final String createLabel;
  final String? emptyLabel;
  final bool allowNull;
  final String nullLabel;

  /// The favorite type for toggle operations.
  /// Set to 'PAYMENT_METHOD' for payment method selectors, or null to disable favorites.
  final String? favoriteType;

  /// Route to navigate for reorder management. If set, shows a "순서 관리" link at the bottom.
  final String? reorderRoute;

  /// Optional map from group key to display label for section headers.
  /// When provided and items have [SelectorItem.group] set, items are grouped
  /// with a header label between each group.
  final Map<String, String>? groupLabels;

  const ItemSelectorSheet({
    super.key,
    required this.title,
    required this.items,
    this.mode = SelectionMode.single,
    this.selectedId,
    this.onSelected,
    this.initialSelectedIds = const {},
    this.onApplyMulti,
    this.maxSelection = 50,
    this.onDelete,
    this.onEdit,
    this.onCreate,
    this.createLabel = '+ 새로 만들기',
    this.emptyLabel,
    this.allowNull = true,
    this.nullLabel = '선택 안 함',
    this.favoriteType,
    this.reorderRoute,
    this.groupLabels,
  })  : assert(
          mode == SelectionMode.single ? onSelected != null : true,
          'SelectionMode.single requires onSelected',
        ),
        assert(
          mode == SelectionMode.multi ? onApplyMulti != null : true,
          'SelectionMode.multi requires onApplyMulti',
        );

  @override
  State<ItemSelectorSheet> createState() => _ItemSelectorSheetState();
}

class _ItemSelectorSheetState extends State<ItemSelectorSheet> {
  late Set<String> _tempSelectedIds;

  bool get _isMulti => widget.mode == SelectionMode.multi;

  @override
  void initState() {
    super.initState();
    _tempSelectedIds = {...widget.initialSelectedIds};
  }

  void _toggleItem(String id) {
    setState(() {
      if (_tempSelectedIds.contains(id)) {
        _tempSelectedIds.remove(id);
      } else {
        if (_tempSelectedIds.length >= widget.maxSelection) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('최대 ${widget.maxSelection}개까지 선택할 수 있습니다.'),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _tempSelectedIds.add(id);
      }
    });
  }

  void _setGroupSelection(Iterable<String> groupItemIds, bool select) {
    setState(() {
      if (select) {
        for (final id in groupItemIds) {
          if (_tempSelectedIds.contains(id)) continue;
          if (_tempSelectedIds.length >= widget.maxSelection) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('최대 ${widget.maxSelection}개까지 선택할 수 있습니다.'),
                duration: const Duration(seconds: 2),
              ),
            );
            break;
          }
          _tempSelectedIds.add(id);
        }
      } else {
        _tempSelectedIds.removeAll(groupItemIds);
      }
    });
  }

  void _selectAll(List<SelectorItem> sortedItems) {
    setState(() {
      final toAdd = sortedItems
          .map((e) => e.id)
          .where((id) => !_tempSelectedIds.contains(id))
          .take(widget.maxSelection - _tempSelectedIds.length);
      _tempSelectedIds.addAll(toAdd);
      if (sortedItems.length > widget.maxSelection) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('최대 ${widget.maxSelection}개까지 선택되었습니다.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _clearAll() {
    setState(() {
      _tempSelectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sort items by displayOrder
    final sortedItems = List<SelectorItem>.from(widget.items)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return BlocProvider<FavoritesBloc>.value(
      value: getIt<FavoritesBloc>(),
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Flexible(
                child: BlocBuilder<FavoritesBloc, FavoritesState>(
                  builder: (context, favState) {
                    final favIds = _getFavoriteIds(favState);
                    final favoriteItems = widget.favoriteType != null
                        ? sortedItems.where((item) => favIds.contains(item.id)).toList()
                        : <SelectorItem>[];

                    return ListView(
                      shrinkWrap: true,
                      children: [
                        // Favorites section at top
                        if (favoriteItems.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                                const SizedBox(width: 6),
                                Text(
                                  '즐겨찾기',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: favoriteItems.map((item) {
                                if (_isMulti) {
                                  final selected = _tempSelectedIds.contains(item.id);
                                  return FilterChip(
                                    label: Text(item.label),
                                    avatar: const Icon(Icons.star, size: 14, color: Colors.amber),
                                    selected: selected,
                                    onSelected: (_) => _toggleItem(item.id),
                                  );
                                }
                                return ActionChip(
                                  label: Text(item.label),
                                  avatar: const Icon(Icons.star, size: 14, color: Colors.amber),
                                  onPressed: () {
                                    widget.onSelected!(item);
                                    Navigator.of(context).pop();
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const Divider(),
                        ],
                        // Null option — hidden in multi mode
                        if (widget.allowNull && !_isMulti)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Icon(Icons.block, size: 20),
                            ),
                            title: Text(widget.nullLabel),
                            selected: widget.selectedId == null,
                            selectedTileColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.3),
                            onTap: () {
                              widget.onSelected!(null);
                              Navigator.of(context).pop();
                            },
                          ),
                        // Items
                        if (sortedItems.isEmpty && widget.emptyLabel != null)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                widget.emptyLabel!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                              ),
                            ),
                          ),
                        ..._buildGroupedItems(context, sortedItems, favIds),
                        // Create option — hidden in multi mode (filter context)
                        if (widget.onCreate != null && !_isMulti) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              child: Icon(
                                Icons.add,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              widget.createLabel,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onCreate!();
                            },
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              // Multi-mode apply bar
              if (_isMulti) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _selectAll(sortedItems),
                          child: const Text('전체 선택'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearAll,
                          child: const Text('전체 해제'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            widget.onApplyMulti!({..._tempSelectedIds});
                            Navigator.of(context).pop();
                          },
                          child: Text('적용 (${_tempSelectedIds.length})'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Reorder management link — hidden in multi mode (filter context)
              if (widget.reorderRoute != null && !_isMulti) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push(widget.reorderRoute!);
                      },
                      child: const Text('순서 관리 >'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the list of item tiles, inserting section headers when [groupLabels]
  /// is provided and items have a [SelectorItem.group] value.
  List<Widget> _buildGroupedItems(
    BuildContext context,
    List<SelectorItem> sortedItems,
    List<String> favIds,
  ) {
    if (widget.groupLabels == null || widget.groupLabels!.isEmpty) {
      return sortedItems.map((item) => _buildItemTile(context, item, favIds)).toList();
    }

    // Pre-group items by their group key so we can offer "group-all" checkbox in multi mode.
    final itemsByGroup = <String, List<SelectorItem>>{};
    for (final item in sortedItems) {
      final key = item.group ?? '';
      itemsByGroup.putIfAbsent(key, () => []).add(item);
    }

    final widgets = <Widget>[];
    String? lastGroup;
    for (final item in sortedItems) {
      if (item.group != null && item.group != lastGroup) {
        final label = widget.groupLabels![item.group] ?? item.group!;
        final groupItems = itemsByGroup[item.group!] ?? const <SelectorItem>[];
        widgets.add(_buildGroupHeader(context, item.group!, label, groupItems));
        lastGroup = item.group;
      }
      widgets.add(_buildItemTile(context, item, favIds));
    }
    return widgets;
  }

  Widget _buildGroupHeader(
    BuildContext context,
    String groupKey,
    String label,
    List<SelectorItem> groupItems,
  ) {
    if (!_isMulti) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
    }

    final groupIds = groupItems.map((e) => e.id).toList();
    final selectedInGroup =
        groupIds.where((id) => _tempSelectedIds.contains(id)).length;
    final allSelected =
        groupIds.isNotEmpty && selectedInGroup == groupIds.length;
    final someSelected = selectedInGroup > 0 && !allSelected;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          Checkbox(
            value: allSelected ? true : (someSelected ? null : false),
            tristate: true,
            onChanged: (_) =>
                _setGroupSelection(groupIds, !allSelected),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$label (그룹 전체)',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getFavoriteIds(FavoritesState state) {
    if (state is! FavoritesLoaded || widget.favoriteType == null) return [];
    if (widget.favoriteType == 'PAYMENT_METHOD') {
      return state.favorites.paymentMethodIds;
    } else if (widget.favoriteType == 'CATEGORY') {
      return state.favorites.categoryIds;
    }
    return [];
  }

  Widget _buildItemTile(BuildContext context, SelectorItem item, List<String> favIds) {
    final isSingleSelected = !_isMulti && item.id == widget.selectedId;
    final isMultiSelected = _isMulti && _tempSelectedIds.contains(item.id);
    final isFavorite = favIds.contains(item.id);

    return ListTile(
      leading: _isMulti
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: isMultiSelected,
                  onChanged: (_) => _toggleItem(item.id),
                ),
                CircleAvatar(
                  backgroundColor:
                      (item.leadingColor ?? Colors.grey).withValues(alpha: 0.15),
                  child: Icon(
                    item.leadingIcon ?? Icons.label,
                    color: item.leadingColor ?? Colors.grey,
                    size: 20,
                  ),
                ),
              ],
            )
          : CircleAvatar(
              backgroundColor:
                  (item.leadingColor ?? Colors.grey).withValues(alpha: 0.15),
              child: Icon(
                item.leadingIcon ?? Icons.label,
                color: item.leadingColor ?? Colors.grey,
                size: 20,
              ),
            ),
      title: Text(item.label),
      subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
      selected: isSingleSelected || isMultiSelected,
      selectedTileColor: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.3),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Favorite star toggle
          if (widget.favoriteType != null)
            GestureDetector(
              onTap: () {
                getIt<FavoritesBloc>().add(ToggleFavorite(
                  type: widget.favoriteType!,
                  itemId: item.id,
                ));
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isFavorite ? Icons.star : Icons.star_outline,
                  size: 18,
                  color: isFavorite
                      ? Colors.amber
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
          // Edit button — hidden in multi mode (filter context)
          if (widget.onEdit != null && !_isMulti)
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                widget.onEdit!(item);
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          if (isSingleSelected)
            Icon(
              Icons.check,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          // Delete button — hidden in multi mode (filter context)
          if (item.isDeletable && widget.onDelete != null && !_isMulti)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: '삭제',
              onPressed: () => _confirmDelete(context, item),
            ),
        ],
      ),
      onTap: () {
        if (_isMulti) {
          _toggleItem(item.id);
        } else {
          widget.onSelected!(item);
          Navigator.of(context).pop();
        }
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, SelectorItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('삭제'),
        content: Text("'${item.label}'을(를) 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onDelete!(item.id);
    }
  }
}

class ItemSelectorField extends StatelessWidget {
  final String label;
  final String? selectedLabel;
  final IconData prefixIcon;
  final VoidCallback onTap;
  final String? placeholder;

  const ItemSelectorField({
    super.key,
    required this.label,
    this.selectedLabel,
    required this.prefixIcon,
    required this.onTap,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(prefixIcon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedLabel ?? placeholder ?? '선택하세요',
          style: selectedLabel != null
              ? null
              : TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
        ),
      ),
    );
  }
}
