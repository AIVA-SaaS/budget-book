import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';

/// Hierarchical category selector: groups -> sub-categories.
/// Groups are expandable headers, only sub-categories are selectable.
/// Groups are separated into SHARED and PRIVATE sections.
class CategoryGroupSelectorSheet extends StatefulWidget {
  final String? selectedCategoryId;
  final String categoryType; // 'INCOME' or 'EXPENSE'
  final ValueChanged<Category?> onSelected;
  final ValueChanged<String>? onDelete;
  /// Called when a category's visibility affects the parent form.
  /// Passes the visibility of the selected category ('SHARED' or 'PRIVATE').
  final ValueChanged<String>? onVisibilityChanged;

  const CategoryGroupSelectorSheet({
    super.key,
    this.selectedCategoryId,
    required this.categoryType,
    required this.onSelected,
    this.onDelete,
    this.onVisibilityChanged,
  });

  @override
  State<CategoryGroupSelectorSheet> createState() =>
      _CategoryGroupSelectorSheetState();
}

class _CategoryGroupSelectorSheetState
    extends State<CategoryGroupSelectorSheet> {
  final Set<String> _expandedGroupIds = {};
  final _groupNameController = TextEditingController();
  final _categoryNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CategoryGroupBloc>.value(
          value: getIt<CategoryGroupBloc>(),
        ),
        BlocProvider<CategoryBloc>.value(
          value: getIt<CategoryBloc>(),
        ),
      ],
      child: BlocListener<CategoryBloc, CategoryState>(
        listener: (context, state) {
          // When a category is created/deleted, reload groups to get updated lists
          if (state is CategoryLoaded) {
            getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
          }
        },
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '카테고리 선택',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: BlocBuilder<CategoryGroupBloc, CategoryGroupState>(
                  builder: (context, state) {
                    if (state is! CategoryGroupLoaded) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return _buildGroupList(context, state.groups);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupList(BuildContext context, List<CategoryGroup> groups) {
    final sharedGroups = groups.where((g) => g.isShared).toList();
    final privateGroups = groups.where((g) => g.isPrivate).toList();

    final List<Widget> children = [];

    // Shared section
    for (final group in sharedGroups) {
      final filteredCategories = group.categories
          .where((c) => c.type == widget.categoryType)
          .toList();

      final isExpanded = _expandedGroupIds.contains(group.id);

      children.add(_buildGroupSection(
        context,
        group,
        filteredCategories,
        isExpanded,
      ));
    }

    // Private section header
    if (privateGroups.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.lock, size: 16),
              const SizedBox(width: 6),
              Text(
                '내 개인 카테고리',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      );
      children.add(const Divider(height: 1));
    }

    // Private groups
    for (final group in privateGroups) {
      final filteredCategories = group.categories
          .where((c) => c.type == widget.categoryType)
          .toList();

      final isExpanded = _expandedGroupIds.contains(group.id);

      children.add(_buildGroupSection(
        context,
        group,
        filteredCategories,
        isExpanded,
      ));
    }

    // Add group button
    children.add(
      ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.create_new_folder,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          '+ 그룹 추가',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: () => _showAddGroupDialog(context),
      ),
    );

    // Add private category group button
    children.add(
      ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          child: Icon(
            Icons.lock_outline,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
        ),
        title: Text(
          '+ 개인 그룹 추가',
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: () => _showAddGroupDialog(context, visibility: 'PRIVATE'),
      ),
    );

    return ListView(
      shrinkWrap: true,
      children: children,
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    CategoryGroup group,
    List<Category> categories,
    bool isExpanded,
  ) {
    final color = UIHelpers.parseColor(group.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header — expandable if has sub-categories, auto-expand if empty
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedGroupIds.remove(group.id);
              } else {
                _expandedGroupIds.add(group.id);
              }
            });
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    group.isPrivate ? Icons.lock : Icons.folder,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            group.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (group.isPrivate) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.lock,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ],
                        ],
                      ),
                      if (categories.isEmpty)
                        Text(
                          '카테고리를 추가하세요',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
                                fontSize: 11,
                              ),
                        ),
                    ],
                  ),
                ),
                if (categories.isNotEmpty)
                  Text(
                    '${categories.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        // Expanded sub-categories
        if (isExpanded) ...[
          ...categories.map((c) => _buildCategoryTile(context, c)),
          // Add sub-category button
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.add,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                '하위 카테고리 추가',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () => _showAddCategoryDialog(context, group),
            ),
          ),
        ],
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildCategoryTile(BuildContext context, Category category) {
    final isSelected = category.id == widget.selectedCategoryId;
    final color = UIHelpers.parseColor(category.color);

    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            Icons.label,
            color: color,
            size: 16,
          ),
        ),
        title: Text(
          category.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(
                Icons.check,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            if (widget.onDelete != null)
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                tooltip: '삭제',
                onPressed: () => _confirmDelete(context, category),
              ),
          ],
        ),
        onTap: () {
          widget.onSelected(category);
          // Notify parent about the visibility of the selected category
          widget.onVisibilityChanged?.call(category.visibility);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _showAddGroupDialog(BuildContext context, {String visibility = 'SHARED'}) async {
    _groupNameController.clear();
    final isPrivate = visibility == 'PRIVATE';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isPrivate ? '개인 그룹 추가' : '그룹 추가'),
        content: TextField(
          controller: _groupNameController,
          decoration: InputDecoration(
            hintText: '그룹 이름',
            prefixIcon: isPrivate ? const Icon(Icons.lock_outline) : null,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final text = _groupNameController.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(dialogContext).pop(text);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (name != null && context.mounted) {
      getIt<CategoryGroupBloc>().add(CreateCategoryGroup(
        name: name,
        visibility: visibility,
      ));
    }
  }

  Future<void> _showAddCategoryDialog(
      BuildContext context, CategoryGroup group) async {
    _categoryNameController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${group.name} - 카테고리 추가'),
        content: TextField(
          controller: _categoryNameController,
          decoration: const InputDecoration(
            hintText: '카테고리 이름',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final text = _categoryNameController.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(dialogContext).pop(text);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (name != null && context.mounted) {
      getIt<CategoryBloc>().add(CreateCategory(
        name: name,
        type: widget.categoryType,
        groupId: group.id,
        visibility: group.visibility,
      ));
    }
  }

  Future<void> _confirmDelete(BuildContext context, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text("'${category.name}'을(를) 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onDelete?.call(category.id);
      getIt<CategoryBloc>().add(DeleteCategory(category.id));
    }
  }

}
