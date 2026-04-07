import 'package:flutter/material.dart';

/// Categorized icon map for the picker UI.
const Map<String, Map<String, IconData>> categorizedIcons = {
  '음식': {
    'restaurant': Icons.restaurant,
    'local_cafe': Icons.local_cafe,
    'coffee': Icons.coffee,
    'local_bar': Icons.local_bar,
    'fastfood': Icons.fastfood,
    'bakery_dining': Icons.bakery_dining,
    'lunch_dining': Icons.lunch_dining,
    'ramen_dining': Icons.ramen_dining,
    'local_pizza': Icons.local_pizza,
    'icecream': Icons.icecream,
    'set_meal': Icons.set_meal,
    'local_dining': Icons.local_dining,
  },
  '교통': {
    'directions_car': Icons.directions_car,
    'directions_bus': Icons.directions_bus,
    'train': Icons.train,
    'local_gas_station': Icons.local_gas_station,
    'flight': Icons.flight,
    'local_taxi': Icons.local_taxi,
    'two_wheeler': Icons.two_wheeler,
    'directions_subway': Icons.directions_subway,
    'pedal_bike': Icons.pedal_bike,
    'local_parking': Icons.local_parking,
  },
  '쇼핑': {
    'shopping_bag': Icons.shopping_bag,
    'shopping_cart': Icons.shopping_cart,
    'checkroom': Icons.checkroom,
    'card_giftcard': Icons.card_giftcard,
    'storefront': Icons.storefront,
    'local_mall': Icons.local_mall,
    'redeem': Icons.redeem,
    'diamond': Icons.diamond,
    'watch': Icons.watch,
    'style': Icons.style,
  },
  '생활': {
    'home': Icons.home,
    'electric_bolt': Icons.electric_bolt,
    'water_drop': Icons.water_drop,
    'local_laundry_service': Icons.local_laundry_service,
    'phone_android': Icons.phone_android,
    'phone': Icons.phone,
    'wifi': Icons.wifi,
    'cleaning_services': Icons.cleaning_services,
    'build': Icons.build,
    'handyman': Icons.handyman,
  },
  '건강': {
    'medical_services': Icons.medical_services,
    'local_hospital': Icons.local_hospital,
    'fitness_center': Icons.fitness_center,
    'spa': Icons.spa,
    'self_improvement': Icons.self_improvement,
    'vaccines': Icons.vaccines,
    'medication': Icons.medication,
    'monitor_heart': Icons.monitor_heart,
  },
  '교육': {
    'school': Icons.school,
    'menu_book': Icons.menu_book,
    'auto_stories': Icons.auto_stories,
    'science': Icons.science,
    'calculate': Icons.calculate,
    'translate': Icons.translate,
    'edit_note': Icons.edit_note,
    'library_books': Icons.library_books,
  },
  '여가': {
    'movie': Icons.movie,
    'sports_esports': Icons.sports_esports,
    'music_note': Icons.music_note,
    'palette': Icons.palette,
    'sports_soccer': Icons.sports_soccer,
    'sports_tennis': Icons.sports_tennis,
    'theater_comedy': Icons.theater_comedy,
    'camera_alt': Icons.camera_alt,
    'celebration': Icons.celebration,
    'beach_access': Icons.beach_access,
  },
  '금융': {
    'payments': Icons.payments,
    'savings': Icons.savings,
    'account_balance': Icons.account_balance,
    'trending_up': Icons.trending_up,
    'attach_money': Icons.attach_money,
    'receipt': Icons.receipt,
    'account_balance_wallet': Icons.account_balance_wallet,
    'credit_card': Icons.credit_card,
  },
  '기타': {
    'pets': Icons.pets,
    'child_care': Icons.child_care,
    'volunteer_activism': Icons.volunteer_activism,
    'work': Icons.work,
    'category': Icons.category,
    'favorite': Icons.favorite,
    'star': Icons.star,
    'local_fire_department': Icons.local_fire_department,
    'emoji_events': Icons.emoji_events,
    'public': Icons.public,
  },
};

/// Flat map of all available icons for resolving by name.
final Map<String, IconData> availableIcons = {
  for (final group in categorizedIcons.values) ...group,
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

class _IconPickerSheet extends StatefulWidget {
  final String? selectedIcon;

  const _IconPickerSheet({this.selectedIcon});

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  String _searchQuery = '';
  String? _selectedCategory;

  List<MapEntry<String, IconData>> get _filteredIcons {
    if (_searchQuery.isEmpty && _selectedCategory == null) {
      return availableIcons.entries.toList();
    }

    Map<String, IconData> source;
    if (_selectedCategory != null) {
      source = categorizedIcons[_selectedCategory!] ?? {};
    } else {
      source = availableIcons;
    }

    if (_searchQuery.isEmpty) {
      return source.entries.toList();
    }

    final query = _searchQuery.toLowerCase();
    return source.entries
        .where((e) => e.key.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredIcons;

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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '아이콘 선택',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: '아이콘 검색',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          // Category chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryChip(
                  label: '전체',
                  isSelected: _selectedCategory == null,
                  onTap: () =>
                      setState(() => _selectedCategory = null),
                ),
                ...categorizedIcons.keys.map((category) {
                  return _CategoryChip(
                    label: category,
                    isSelected: _selectedCategory == category,
                    onTap: () => setState(
                        () => _selectedCategory = category),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Icon grid
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '검색 결과가 없습니다',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final isSelected =
                          widget.selectedIcon == entry.key;

                      return InkWell(
                        onTap: () =>
                            Navigator.of(context).pop(entry.key),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.15)
                                : theme.colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                entry.value,
                                size: 24,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.key.replaceAll('_', '\n'),
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(
                                  fontSize: 8,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        labelStyle: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
