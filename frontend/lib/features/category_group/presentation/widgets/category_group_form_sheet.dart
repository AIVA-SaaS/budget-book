import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';

class CategoryGroupFormSheet extends StatefulWidget {
  final CategoryGroup? group;
  final void Function(
    String name,
    String? icon,
    String? color,
    String budgetType,
  ) onSubmit;

  const CategoryGroupFormSheet({
    super.key,
    this.group,
    required this.onSubmit,
  });

  @override
  State<CategoryGroupFormSheet> createState() => _CategoryGroupFormSheetState();
}

class _CategoryGroupFormSheetState extends State<CategoryGroupFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedBudgetType;
  String? _selectedIcon;
  String? _selectedColor;

  bool get isEditing => widget.group != null;

  static const _budgetTypeLabels = {
    'MONTHLY': '월간',
    'WEEKLY': '주간',
    'NONE': '없음',
  };

  static const _availableIcons = <String, IconData>{
    'account_balance_wallet': Icons.account_balance_wallet,
    'home': Icons.home,
    'directions_car': Icons.directions_car,
    'restaurant': Icons.restaurant,
    'school': Icons.school,
    'local_hospital': Icons.local_hospital,
    'shopping_bag': Icons.shopping_bag,
    'savings': Icons.savings,
    'work': Icons.work,
    'card_giftcard': Icons.card_giftcard,
    'sports_esports': Icons.sports_esports,
    'flight': Icons.flight,
    'child_care': Icons.child_care,
    'pets': Icons.pets,
    'fitness_center': Icons.fitness_center,
    'category': Icons.category,
  };

  static const _availableColors = [
    '#4CAF50',
    '#2196F3',
    '#FF5733',
    '#E91E63',
    '#9C27B0',
    '#673AB7',
    '#3F51B5',
    '#03A9F4',
    '#00BCD4',
    '#009688',
    '#8BC34A',
    '#FFC107',
    '#FF9800',
    '#FF5722',
    '#795548',
    '#607D8B',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    _selectedBudgetType = widget.group?.budgetType ?? 'MONTHLY';
    _selectedIcon = widget.group?.icon;
    _selectedColor = widget.group?.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              context.bbSpace.gapV(BbSpaceToken.xxl),
              Text(
                isEditing ? '그룹 수정' : '그룹 추가',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              context.bbSpace.gapV(BbSpaceToken.block),
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '그룹 이름',
                  hintText: '예: 생활비, 고정비, 저축',
                ),
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '그룹 이름을 입력하세요';
                  }
                  return null;
                },
              ),
              context.bbSpace.gapV(BbSpaceToken.xxl),
              // Budget type dropdown
              Text(
                '예산 주기',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              context.bbSpace.gapV(BbSpaceToken.lg),
              SegmentedButton<String>(
                segments: _budgetTypeLabels.entries
                    .map((entry) => ButtonSegment(
                          value: entry.key,
                          label: Text(entry.value),
                        ))
                    .toList(),
                selected: {_selectedBudgetType},
                onSelectionChanged: (value) {
                  setState(() {
                    _selectedBudgetType = value.first;
                  });
                },
              ),
              context.bbSpace.gapV(BbSpaceToken.xxl),
              // Icon picker
              Text(
                '아이콘',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              context.bbSpace.gapV(BbSpaceToken.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableIcons.entries.map((entry) {
                  final isSelected = _selectedIcon == entry.key;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIcon = entry.key;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.15)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Icon(
                        entry.value,
                        size: context.bbType.iconSm,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              context.bbSpace.gapV(BbSpaceToken.xxl),
              // Color picker
              Text(
                '색상',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              context.bbSpace.gapV(BbSpaceToken.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableColors.map((hex) {
                  final isSelected = _selectedColor == hex;
                  final color = UIHelpers.parseColor(hex);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColor = hex;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: Colors.white,
                              size: context.bbType.iconSm,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              context.bbSpace.gapV(BbSpaceToken.block),
              FilledButton(
                onPressed: _onSubmit,
                style: FilledButton.styleFrom(
                  padding: context.bbSpace
                      .symmetric(h: BbSpaceToken.md, v: BbSpaceToken.xl),
                ),
                child: Text(isEditing ? '수정' : '추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(
        _nameController.text.trim(),
        _selectedIcon,
        _selectedColor,
        _selectedBudgetType,
      );
      Navigator.of(context).pop();
    }
  }
}
