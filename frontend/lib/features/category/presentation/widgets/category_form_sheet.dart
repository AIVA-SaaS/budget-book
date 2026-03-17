import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/icon_picker.dart';
import 'package:budget_book/core/widgets/color_picker.dart';

class CategoryFormSheet extends StatefulWidget {
  final Category? category;
  final void Function(String name, String type, String? icon, String? color, String? groupId)
      onSubmit;

  const CategoryFormSheet({
    super.key,
    this.category,
    required this.onSubmit,
  });

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedType;
  String? _selectedIcon;
  String? _selectedColor;
  String? _selectedGroupId;
  bool _isSubmitting = false;

  bool get isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedType = widget.category?.type ?? 'EXPENSE';
    _selectedIcon = widget.category?.icon;
    _selectedColor = widget.category?.color;
    _selectedGroupId = widget.category?.groupId;
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
              const SizedBox(height: 16),
              Text(
                isEditing ? '카테고리 수정' : '카테고리 추가',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              // Preview of selected icon and color
              Center(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: _selectedColor != null
                      ? parseHexColor(_selectedColor)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    resolveIcon(_selectedIcon),
                    color: _selectedColor != null
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '카테고리 이름',
                  hintText: '예: 식비, 교통비, 급여',
                ),
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '카테고리 이름을 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Type selector (only for new categories)
              if (!isEditing) ...[
                Text(
                  '유형',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'EXPENSE',
                      label: Text('지출'),
                      icon: Icon(Icons.arrow_downward),
                    ),
                    ButtonSegment(
                      value: 'INCOME',
                      label: Text('수입'),
                      icon: Icon(Icons.arrow_upward),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (value) {
                    setState(() {
                      _selectedType = value.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              // Group selector
              Text(
                '카테고리 그룹',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _buildGroupSelector(context),
              const SizedBox(height: 16),
              // Icon picker button
              Text(
                '아이콘',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await showIconPicker(
                    context: context,
                    selectedIcon: _selectedIcon,
                  );
                  if (result != null) {
                    setState(() {
                      _selectedIcon = result;
                    });
                  }
                },
                icon: Icon(
                  resolveIcon(_selectedIcon),
                  size: 20,
                ),
                label: Text(
                  _selectedIcon ?? '아이콘을 선택하세요',
                ),
              ),
              const SizedBox(height: 16),
              // Color picker button
              Text(
                '색상',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await showColorPicker(
                    context: context,
                    selectedColor: _selectedColor,
                  );
                  if (result != null) {
                    setState(() {
                      _selectedColor = result;
                    });
                  }
                },
                icon: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _selectedColor != null
                        ? parseHexColor(_selectedColor)
                        : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                    ),
                  ),
                ),
                label: Text(
                  _selectedColor ?? '색상을 선택하세요',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _onSubmit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? '수정' : '추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSelector(BuildContext context) {
    return BlocProvider<CategoryGroupBloc>.value(
      value: getIt<CategoryGroupBloc>()..add(const LoadCategoryGroups()),
      child: BlocBuilder<CategoryGroupBloc, CategoryGroupState>(
        builder: (context, state) {
          if (state is! CategoryGroupLoaded) {
            return const LinearProgressIndicator();
          }
          final groups = state.groups
              .where((g) => !g.isDefault || g.categories.isNotEmpty)
              .toList();
          return DropdownButtonFormField<String?>(
            initialValue: _selectedGroupId,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.folder_outlined),
              hintText: '그룹 없음',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('그룹 없음'),
              ),
              ...groups.map((g) => DropdownMenuItem<String?>(
                    value: g.id,
                    child: Text(g.name),
                  )),
            ],
            onChanged: (value) {
              setState(() => _selectedGroupId = value);
            },
          );
        },
      ),
    );
  }

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSubmitting = true);
      widget.onSubmit(
        _nameController.text.trim(),
        _selectedType,
        _selectedIcon,
        _selectedColor,
        _selectedGroupId,
      );
      Navigator.of(context).pop();
    }
  }
}
