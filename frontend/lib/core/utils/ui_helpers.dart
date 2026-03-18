import 'package:flutter/material.dart';

/// Shared UI utility functions used across widgets.
class UIHelpers {
  UIHelpers._();

  /// Parse hex color string (#RRGGBB) to [Color]. Falls back to [fallback].
  static Color parseColor(String? hex, {Color fallback = Colors.grey}) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final colorStr = hex.replaceFirst('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  /// Resolve icon name string to [IconData]. Falls back to [fallback].
  static IconData resolveIcon(String? iconName,
      {IconData fallback = Icons.receipt_long}) {
    if (iconName == null) return fallback;
    return _iconMap[iconName] ?? fallback;
  }

  static const _iconMap = <String, IconData>{
    'account_balance': Icons.account_balance,
    'account_balance_wallet': Icons.account_balance_wallet,
    'card_giftcard': Icons.card_giftcard,
    'category': Icons.category,
    'child_care': Icons.child_care,
    'directions_bus': Icons.directions_bus,
    'directions_car': Icons.directions_car,
    'electric_bolt': Icons.electric_bolt,
    'fitness_center': Icons.fitness_center,
    'flight': Icons.flight,
    'home': Icons.home,
    'local_cafe': Icons.local_cafe,
    'local_hospital': Icons.local_hospital,
    'movie': Icons.movie,
    'payments': Icons.payments,
    'pets': Icons.pets,
    'phone': Icons.phone,
    'restaurant': Icons.restaurant,
    'restaurant_menu': Icons.restaurant_menu,
    'savings': Icons.savings,
    'school': Icons.school,
    'shopping_bag': Icons.shopping_bag,
    'shopping_cart': Icons.shopping_cart,
    'sports_esports': Icons.sports_esports,
    'trending_up': Icons.trending_up,
    'work': Icons.work,
  };
}
