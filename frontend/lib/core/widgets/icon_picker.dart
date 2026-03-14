import 'package:flutter/material.dart';

/// A map of icon name strings to their Material [IconData].
/// Used for category icons throughout the app.
const Map<String, IconData> availableIcons = {
  'restaurant': Icons.restaurant,
  'shopping_bag': Icons.shopping_bag,
  'shopping_cart': Icons.shopping_cart,
  'local_gas_station': Icons.local_gas_station,
  'train': Icons.train,
  'directions_bus': Icons.directions_bus,
  'directions_car': Icons.directions_car,
  'movie': Icons.movie,
  'home': Icons.home,
  'school': Icons.school,
  'medical_services': Icons.medical_services,
  'local_hospital': Icons.local_hospital,
  'sports_esports': Icons.sports_esports,
  'checkroom': Icons.checkroom,
  'coffee': Icons.coffee,
  'local_cafe': Icons.local_cafe,
  'phone_android': Icons.phone_android,
  'phone': Icons.phone,
  'build': Icons.build,
  'flight': Icons.flight,
  'pets': Icons.pets,
  'payments': Icons.payments,
  'work': Icons.work,
  'savings': Icons.savings,
  'card_giftcard': Icons.card_giftcard,
  'trending_up': Icons.trending_up,
  'fitness_center': Icons.fitness_center,
  'child_care': Icons.child_care,
  'electric_bolt': Icons.electric_bolt,
  'account_balance': Icons.account_balance,
  'category': Icons.category,
  'receipt': Icons.receipt,
  'attach_money': Icons.attach_money,
  'volunteer_activism': Icons.volunteer_activism,
  'celebration': Icons.celebration,
};

/// Resolves an icon name string to its [IconData].
/// Returns [Icons.account_balance_wallet] if the name is not found.
IconData resolveIcon(String? iconName) {
  if (iconName == null) return Icons.account_balance_wallet;
  return availableIcons[iconName] ?? Icons.account_balance_wallet;
}

/// Shows a bottom sheet grid of Material Icons for the user to pick from.
/// Returns the selected icon name string, or null if dismissed.
Future<String?> showIconPicker({
  required BuildContext context,
  String? selectedIcon,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return _IconPickerSheet(selectedIcon: selectedIcon);
    },
  );
}

class _IconPickerSheet extends StatelessWidget {
  final String? selectedIcon;

  const _IconPickerSheet({this.selectedIcon});

  @override
  Widget build(BuildContext context) {
    final entries = availableIcons.entries.toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '아이콘 선택',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isSelected = selectedIcon == entry.key;

                return InkWell(
                  onTap: () => Navigator.of(context).pop(entry.key),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          entry.value,
                          size: 24,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.key.replaceAll('_', '\n'),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 8,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                  ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
