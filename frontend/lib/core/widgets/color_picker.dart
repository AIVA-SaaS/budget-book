import 'package:flutter/material.dart';

/// Preset color palette for categories.
const List<String> presetColors = [
  '#FF5733',
  '#2196F3',
  '#4CAF50',
  '#FF9800',
  '#9C27B0',
  '#00BCD4',
  '#E91E63',
  '#795548',
  '#607D8B',
  '#F44336',
  '#3F51B5',
  '#009688',
  '#FFEB3B',
  '#8BC34A',
  '#FF5722',
  '#673AB7',
];

/// Parses a hex color string (e.g., "#FF5733") to a [Color].
Color parseHexColor(String? hex) {
  if (hex == null) return Colors.grey;
  try {
    final colorStr = hex.replaceFirst('#', '');
    return Color(int.parse('FF$colorStr', radix: 16));
  } catch (_) {
    return Colors.grey;
  }
}

/// Shows a bottom sheet with a preset color palette for the user to pick from.
/// Returns the selected hex color string, or null if dismissed.
Future<String?> showColorPicker({
  required BuildContext context,
  String? selectedColor,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) {
      return _ColorPickerSheet(selectedColor: selectedColor);
    },
  );
}

class _ColorPickerSheet extends StatelessWidget {
  final String? selectedColor;

  const _ColorPickerSheet({this.selectedColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
            '색상 선택',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: presetColors.map((hex) {
              final isSelected =
                  selectedColor?.toUpperCase() == hex.toUpperCase();
              final color = parseHexColor(hex);

              return InkWell(
                onTap: () => Navigator.of(context).pop(hex),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : Border.all(
                            color: Colors.transparent,
                            width: 3,
                          ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
