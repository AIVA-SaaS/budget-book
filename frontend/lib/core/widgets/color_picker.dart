import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/bb_scale.dart';

/// Extended color palette — Material Design colors.
const List<String> presetColors = [
  // Row 1: Reds & Pinks
  '#F44336', '#E91E63', '#FF5252', '#FF4081',
  // Row 2: Purples
  '#9C27B0', '#673AB7', '#7C4DFF', '#E040FB',
  // Row 3: Blues
  '#3F51B5', '#2196F3', '#03A9F4', '#448AFF',
  // Row 4: Cyans & Teals
  '#00BCD4', '#009688', '#00E5FF', '#1DE9B6',
  // Row 5: Greens
  '#4CAF50', '#8BC34A', '#00C853', '#69F0AE',
  // Row 6: Yellows & Ambers
  '#FFEB3B', '#FFC107', '#FF9800', '#FFD740',
  // Row 7: Oranges & Browns
  '#FF5722', '#FF5733', '#795548', '#A1887F',
  // Row 8: Greys & Blue-greys
  '#607D8B', '#9E9E9E', '#455A64', '#78909C',
];

const _recentColorsKey = 'recent_colors';
const _maxRecentColors = 8;

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

/// Shows a bottom sheet with a color palette, recent colors, and custom hex input.
/// Returns the selected hex color string, or null if dismissed.
Future<String?> showColorPicker({
  required BuildContext context,
  String? selectedColor,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return _ColorPickerSheet(selectedColor: selectedColor);
    },
  );
}

class _ColorPickerSheet extends StatefulWidget {
  final String? selectedColor;

  const _ColorPickerSheet({this.selectedColor});

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  final TextEditingController _hexController = TextEditingController();
  List<String> _recentColors = [];
  String? _customPreview;

  @override
  void initState() {
    super.initState();
    _loadRecentColors();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentColors() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentColorsKey) ?? [];
    if (mounted) {
      setState(() => _recentColors = recent);
    }
  }

  Future<void> _saveRecentColor(String hex) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentColorsKey) ?? [];
    recent.remove(hex.toUpperCase());
    recent.insert(0, hex.toUpperCase());
    if (recent.length > _maxRecentColors) {
      recent.removeRange(_maxRecentColors, recent.length);
    }
    await prefs.setStringList(_recentColorsKey, recent);
  }

  void _selectColor(String hex) {
    _saveRecentColor(hex);
    Navigator.of(context).pop(hex);
  }

  void _onHexChanged(String value) {
    final cleaned = value.replaceFirst('#', '').toUpperCase();
    if (cleaned.length == 6 &&
        RegExp(r'^[0-9A-F]{6}$').hasMatch(cleaned)) {
      setState(() => _customPreview = '#$cleaned');
    } else {
      setState(() => _customPreview = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          context.bbSpace.gapV(BbSpaceToken.xl),
          Text(
            '색상 선택',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // Recent colors
          if (_recentColors.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '최근 사용',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.lg),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _recentColors.map((hex) {
                return _ColorCircle(
                  hex: hex,
                  isSelected: widget.selectedColor?.toUpperCase() ==
                      hex.toUpperCase(),
                  onTap: () => _selectColor(hex),
                  size: 40,
                );
              }).toList(),
            ),
            context.bbSpace.gapV(BbSpaceToken.xxl),
          ],
          // Preset palette
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '기본 색상',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          context.bbSpace.gapV(BbSpaceToken.lg),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: presetColors.map((hex) {
              final isSelected =
                  widget.selectedColor?.toUpperCase() == hex.toUpperCase();
              return _ColorCircle(
                hex: hex,
                isSelected: isSelected,
                onTap: () => _selectColor(hex),
              );
            }).toList(),
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // Custom hex input
          Row(
            children: [
              if (_customPreview != null)
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: parseHexColor(_customPreview),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.outline,
                      width: 1,
                    ),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: _hexController,
                  decoration: InputDecoration(
                    hintText: '#RRGGBB',
                    labelText: '직접 입력',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.color_lens, size: context.bbType.iconSm),
                    suffixIcon: _customPreview != null
                        ? IconButton(
                            icon: Icon(Icons.check, size: context.bbType.iconMd),
                            onPressed: () =>
                                _selectColor(_customPreview!),
                          )
                        : null,
                  ),
                  onChanged: _onHexChanged,
                  onSubmitted: (_) {
                    if (_customPreview != null) {
                      _selectColor(_customPreview!);
                    }
                  },
                ),
              ),
            ],
          ),
          context.bbSpace.gapV(BbSpaceToken.lg),
        ],
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final String hex;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  const _ColorCircle({
    required this.hex,
    required this.isSelected,
    required this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(hex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
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
            ? Icon(Icons.check, color: Colors.white, size: context.bbType.iconSm)
            : null,
      ),
    );
  }
}
