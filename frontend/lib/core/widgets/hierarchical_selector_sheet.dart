import 'package:flutter/material.dart';

/// A generic two-level hierarchical selector presented as a bottom sheet.
///
/// [G] is the group type, [I] is the item type (child of a group).
///
/// When [groupSelectable] is true (e.g. budget setting), tapping the
/// group header's icon+name area selects the group itself; tapping the
/// trailing chevron toggles expansion. When false (e.g. transaction form),
/// tapping anywhere on the group header toggles expansion only.
class HierarchicalSelectorSheet<G, I> extends StatefulWidget {
  final List<G> groups;
  final List<I> Function(G group) itemsOf;
  final String Function(G) groupLabel;
  final String Function(I) itemLabel;
  final Color? Function(G)? groupColor;
  final Color? Function(I)? itemColor;
  final String Function(G) groupId;
  final String Function(I) itemId;
  final bool groupSelectable;
  final String? selectedGroupId;
  final String? selectedItemId;
  final void Function(G group)? onGroupSelected;
  final void Function(I item)? onItemSelected;
  final void Function(I item, G group)? onItemSelectedWithGroup;
  final void Function(G group)? onAddItem;
  final void Function()? onAddGroup;
  final void Function(I item)? onDeleteItem;
  final String title;

  const HierarchicalSelectorSheet({
    super.key,
    required this.groups,
    required this.itemsOf,
    required this.groupLabel,
    required this.itemLabel,
    required this.groupId,
    required this.itemId,
    this.groupColor,
    this.itemColor,
    this.groupSelectable = false,
    this.selectedGroupId,
    this.selectedItemId,
    this.onGroupSelected,
    this.onItemSelected,
    this.onItemSelectedWithGroup,
    this.onAddItem,
    this.onAddGroup,
    this.onDeleteItem,
    required this.title,
  });

  @override
  State<HierarchicalSelectorSheet<G, I>> createState() =>
      _HierarchicalSelectorSheetState<G, I>();
}

class _HierarchicalSelectorSheetState<G, I>
    extends State<HierarchicalSelectorSheet<G, I>> {
  final Set<String> _expandedGroupIds = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1),
          // Content
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final group in widget.groups)
                  _buildGroupSection(context, group),
                if (widget.onAddGroup != null) _buildAddGroupButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(BuildContext context, G group) {
    final gId = widget.groupId(group);
    final isExpanded = _expandedGroupIds.contains(gId);
    final items = widget.itemsOf(group);
    final color = widget.groupColor?.call(group) ?? Colors.grey;
    final isGroupSelected =
        widget.groupSelectable && gId == widget.selectedGroupId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        _buildGroupHeader(
          context,
          group: group,
          gId: gId,
          color: color,
          isExpanded: isExpanded,
          isGroupSelected: isGroupSelected,
          itemCount: items.length,
        ),
        // Expanded children
        if (isExpanded) ...[
          ...items.map((item) => _buildItemTile(context, item, group)),
          if (widget.onAddItem != null) _buildAddItemButton(context, group),
        ],
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildGroupHeader(
    BuildContext context, {
    required G group,
    required String gId,
    required Color color,
    required bool isExpanded,
    required bool isGroupSelected,
    required int itemCount,
  }) {
    final label = widget.groupLabel(group);

    if (widget.groupSelectable) {
      // Split: icon+name area is selectable, trailing chevron toggles expand
      return Container(
        color: isGroupSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        child: Row(
          children: [
            // Selectable area: icon + name
            Expanded(
              child: InkWell(
                onTap: () {
                  widget.onGroupSelected?.call(group);
                  Navigator.of(context).pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(Icons.folder, color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isGroupSelected)
                        Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      if (itemCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$itemCount',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Toggle expand
            InkWell(
              onTap: () => _toggleExpand(gId),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Non-selectable group: entire header toggles expand
    return InkWell(
      onTap: () => _toggleExpand(gId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(Icons.folder, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (itemCount == 0)
                    Text(
                      '카테고리를 추가하세요',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                    ),
                ],
              ),
            ),
            if (itemCount > 0)
              Text(
                '$itemCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            const SizedBox(width: 4),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, I item, G group) {
    final iId = widget.itemId(item);
    final isSelected = iId == widget.selectedItemId;
    final color = widget.itemColor?.call(item) ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.label, color: color, size: 16),
        ),
        title: Text(
          widget.itemLabel(item),
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(
                Icons.check,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            if (widget.onDeleteItem != null)
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                tooltip: '삭제',
                onPressed: () => widget.onDeleteItem?.call(item),
              ),
          ],
        ),
        onTap: () {
          widget.onItemSelected?.call(item);
          widget.onItemSelectedWithGroup?.call(item, group);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildAddItemButton(BuildContext context, G group) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.add,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          '하위 카테고리 추가',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        onTap: () => widget.onAddItem?.call(group),
      ),
    );
  }

  Widget _buildAddGroupButton(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        child: Icon(
          Icons.create_new_folder,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        '+ 그룹 추가',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: widget.onAddGroup,
    );
  }

  void _toggleExpand(String gId) {
    setState(() {
      if (_expandedGroupIds.contains(gId)) {
        _expandedGroupIds.remove(gId);
      } else {
        _expandedGroupIds.add(gId);
      }
    });
  }
}
