import 'package:flutter/material.dart';
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
    final color = _parseColor(category.color);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(
          _resolveIcon(category.icon),
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

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    try {
      final colorStr = hex.replaceFirst('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _resolveIcon(String? iconName) {
    if (iconName == null) return Icons.category;
    const iconMap = <String, IconData>{
      'restaurant': Icons.restaurant,
      'restaurant_menu': Icons.restaurant_menu,
      'shopping_cart': Icons.shopping_cart,
      'directions_bus': Icons.directions_bus,
      'home': Icons.home,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'pets': Icons.pets,
      'payments': Icons.payments,
      'work': Icons.work,
      'savings': Icons.savings,
      'card_giftcard': Icons.card_giftcard,
      'trending_up': Icons.trending_up,
      'local_cafe': Icons.local_cafe,
      'movie': Icons.movie,
      'fitness_center': Icons.fitness_center,
      'child_care': Icons.child_care,
      'phone': Icons.phone,
      'electric_bolt': Icons.electric_bolt,
      'account_balance': Icons.account_balance,
    };
    return iconMap[iconName] ?? Icons.category;
  }
}
