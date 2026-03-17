import 'package:flutter/material.dart';

class SelectorItem {
  final String id;
  final String label;
  final String? subtitle;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final bool isDeletable;

  const SelectorItem({
    required this.id,
    required this.label,
    this.subtitle,
    this.leadingIcon,
    this.leadingColor,
    this.isDeletable = true,
  });
}

class ItemSelectorSheet extends StatelessWidget {
  final String title;
  final List<SelectorItem> items;
  final String? selectedId;
  final ValueChanged<SelectorItem?> onSelected;
  final ValueChanged<String>? onDelete;
  final VoidCallback? onCreate;
  final String createLabel;
  final String? emptyLabel;
  final bool allowNull;
  final String nullLabel;

  const ItemSelectorSheet({
    super.key,
    required this.title,
    required this.items,
    this.selectedId,
    required this.onSelected,
    this.onDelete,
    this.onCreate,
    this.createLabel = '+ 새로 만들기',
    this.emptyLabel,
    this.allowNull = true,
    this.nullLabel = '선택 안 함',
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
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
                // Null option
                if (allowNull)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Icon(Icons.block, size: 20),
                    ),
                    title: Text(nullLabel),
                    selected: selectedId == null,
                    selectedTileColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3),
                    onTap: () {
                      onSelected(null);
                      Navigator.of(context).pop();
                    },
                  ),
                // Items
                if (items.isEmpty && emptyLabel != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        emptyLabel!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                      ),
                    ),
                  ),
                ...items.map((item) => _buildItemTile(context, item)),
                // Create option
                if (onCreate != null) ...[
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
                      createLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onCreate!();
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, SelectorItem item) {
    final isSelected = item.id == selectedId;
    return ListTile(
      leading: CircleAvatar(
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
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          if (item.isDeletable && onDelete != null)
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
        onSelected(item);
        Navigator.of(context).pop();
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
      onDelete!(item.id);
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
