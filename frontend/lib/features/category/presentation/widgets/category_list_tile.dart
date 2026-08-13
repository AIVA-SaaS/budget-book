import 'package:flutter/material.dart';
import 'package:budget_book/core/theme/bb_colors.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';

class CategoryListTile extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  /// Index for the edit-mode drag handle. Null hides it.
  final int? reorderIndex;

  const CategoryListTile({
    super.key,
    required this.category,
    required this.onEdit,
    this.onDelete,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) {
    // 사용자가 고른 색은 여기 한 곳에서만 보정한다 (guard S6).
    final color = context.bb.readable(UIHelpers.parseColor(category.color));

    return EntityTileRow(
      title: category.name,
      leadingIcon:
          UIHelpers.resolveIcon(category.icon, fallback: Icons.category),
      leadingColor: color,
      badges: category.isDefault
          ? const [EntityBadge(label: '기본 카테고리')]
          : const [],
      actions: EntityTileActions(
        menu: [
          const EntityMenuAction(
              value: 'edit', label: '수정', icon: Icons.edit_outlined),
          if (onDelete != null)
            const EntityMenuAction(
              value: 'delete',
              label: '삭제',
              icon: Icons.delete_outline,
              destructive: true,
            ),
        ],
        onMenuSelected: (action) {
          if (action == 'edit') {
            onEdit();
          } else if (action == 'delete') {
            onDelete?.call();
          }
        },
        reorderIndex: reorderIndex,
      ),
    );
  }
}
