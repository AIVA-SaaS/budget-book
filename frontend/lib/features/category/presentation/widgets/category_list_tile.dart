import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';

class CategoryListTile extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const CategoryListTile({
    super.key,
    required this.category,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = UIHelpers.parseColor(category.color);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(
          UIHelpers.resolveIcon(category.icon, fallback: Icons.category),
          color: color,
          size: 20,
        ),
      ),
      title: Text(category.name),
      subtitle: category.isDefault
          ? Text(
              '기본 카테고리',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontSize: 12,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
            tooltip: '수정',
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
              tooltip: '삭제',
              color: Colors.red,
            ),
        ],
      ),
    );
  }

}
