import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/utils/couple_mode.dart';
import 'package:budget_book/core/utils/dialog_helpers.dart';
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
import 'package:budget_book/features/preference/presentation/bloc/favorites_bloc.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_event.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_state.dart';

/// Selection mode for [CategoryGroupSelectorSheet].
///
/// - [singleCategory]: Legacy behavior — tapping a category fires
///   [CategoryGroupSelectorSheet.onSelected] and pops the sheet.
/// - [multiCategoryWithGroup]: Checkboxes on every category and group header.
///   Selecting a group checkbox cascades to its categories (both the group id
///   is kept in `_tempGroupIds` and all child category ids are added to
///   `_tempCategoryIds`). On apply, [CategoryGroupSelectorSheet.onApplyMulti]
///   is invoked with `(categoryIds, groupIds)`.
enum CategorySelectionMode { singleCategory, multiCategoryWithGroup }

/// Hierarchical category selector: groups -> sub-categories.
/// Groups are expandable headers, only sub-categories are selectable.
/// Groups are separated into SHARED and PRIVATE sections.
class CategoryGroupSelectorSheet extends StatefulWidget {
  final String? selectedCategoryId;
  final String categoryType; // 'INCOME' or 'EXPENSE'

  /// Selection mode. Defaults to [CategorySelectionMode.singleCategory].
  final CategorySelectionMode mode;

  /// Single-mode selection callback.
  final ValueChanged<Category?>? onSelected;
  final ValueChanged<String>? onDelete;
  /// Called with (category, groupName) for display purposes.
  final void Function(Category? category, String? groupName)? onSelectedWithGroupName;

  /// Multi-mode: initially checked category ids.
  final Set<String> initialCategoryIds;

  /// Multi-mode: initially checked group ids.
  final Set<String> initialGroupIds;

  /// Multi-mode apply callback with `(categoryIds, groupIds)`.
  final void Function(Set<String> categoryIds, Set<String> groupIds)? onApplyMulti;

  const CategoryGroupSelectorSheet({
    super.key,
    this.selectedCategoryId,
    required this.categoryType,
    this.mode = CategorySelectionMode.singleCategory,
    this.onSelected,
    this.onDelete,
    this.onSelectedWithGroupName,
    this.initialCategoryIds = const {},
    this.initialGroupIds = const {},
    this.onApplyMulti,
  })  : assert(
          mode == CategorySelectionMode.singleCategory ? onSelected != null : true,
          'CategorySelectionMode.singleCategory requires onSelected',
        ),
        assert(
          mode == CategorySelectionMode.multiCategoryWithGroup
              ? onApplyMulti != null
              : true,
          'CategorySelectionMode.multiCategoryWithGroup requires onApplyMulti',
        );

  @override
  State<CategoryGroupSelectorSheet> createState() =>
      _CategoryGroupSelectorSheetState();
}

class _CategoryGroupSelectorSheetState
    extends State<CategoryGroupSelectorSheet> {
  final Set<String> _expandedGroupIds = {};
  final _groupNameController = TextEditingController();
  final _categoryNameController = TextEditingController();
  bool _autoExpandedOnce = false;

  late Set<String> _tempCategoryIds;
  late Set<String> _tempGroupIds;

  bool get _isMulti =>
      widget.mode == CategorySelectionMode.multiCategoryWithGroup;

  @override
  void initState() {
    super.initState();
    _tempCategoryIds = {...widget.initialCategoryIds};
    _tempGroupIds = {...widget.initialGroupIds};
    final bloc = getIt<CategoryGroupBloc>();
    if (bloc.state is! CategoryGroupLoaded) {
      bloc.add(const LoadCategoryGroups());
    }
  }

  void _toggleCategory(String id) {
    setState(() {
      if (_tempCategoryIds.contains(id)) {
        _tempCategoryIds.remove(id);
      } else {
        _tempCategoryIds.add(id);
      }
    });
  }

  void _setGroupCheckedCascade(CategoryGroup group, bool checked) {
    final childIds = group.categories
        .where((c) => c.type == widget.categoryType)
        .map((c) => c.id)
        .toList();
    setState(() {
      if (checked) {
        _tempGroupIds.add(group.id);
        _tempCategoryIds.addAll(childIds);
      } else {
        _tempGroupIds.remove(group.id);
        _tempCategoryIds.removeAll(childIds);
      }
    });
  }

  void _clearAllMulti() {
    setState(() {
      _tempCategoryIds.clear();
      _tempGroupIds.clear();
    });
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
        BlocProvider<FavoritesBloc>.value(
          value: getIt<FavoritesBloc>(),
        ),
      ],
      child: BlocListener<CategoryBloc, CategoryState>(
        listener: (context, state) {
          // When a category is created/deleted, reload groups to get updated lists
          if (state is CategoryLoaded) {
            getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
          }
        },
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '카테고리 선택',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
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
                const Divider(height: 1),
                if (_isMulti)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clearAllMulti,
                            child: const Text('전체 해제'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () {
                              widget.onApplyMulti!(
                                {..._tempCategoryIds},
                                {..._tempGroupIds},
                              );
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              '적용 (${_tempCategoryIds.length + _tempGroupIds.length})',
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/asset-management');
                        },
                        child: const Text('순서 관리 >'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupList(BuildContext context, List<CategoryGroup> groups) {
    // Auto-expand the group containing the selected category (once)
    if (!_autoExpandedOnce && widget.selectedCategoryId != null) {
      for (final group in groups) {
        if (group.categories.any((c) => c.id == widget.selectedCategoryId)) {
          _expandedGroupIds.add(group.id);
          _autoExpandedOnce = true;
          break;
        }
      }
    }

    final coupled = isCoupleMode();
    // Phase 25 후속 — 그룹 자체도 categoryType 으로 필터링.
    // (선택 sheet 가 거래 type 에 맞는 그룹만 노출)
    final typed = groups
        .where((g) => g.categoryType == widget.categoryType)
        .toList();
    final sharedGroups = coupled
        ? (typed.where((g) => g.isShared).toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)))
        : (typed.toList()..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)));
    final privateGroups = coupled
        ? (typed.where((g) => g.isPrivate).toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)))
        : <CategoryGroup>[];

    // Collect all categories of this type for favorites lookup
    final allCategories = <Category>[];
    for (final group in groups) {
      allCategories.addAll(
        group.categories.where((c) => c.type == widget.categoryType),
      );
    }

    return BlocBuilder<FavoritesBloc, FavoritesState>(
      builder: (context, favState) {
        final favCategoryIds = favState is FavoritesLoaded
            ? favState.favorites.categoryIds
            : <String>[];

        // Build the favorites section categories
        final favoriteCategories = allCategories
            .where((c) => favCategoryIds.contains(c.id))
            .toList();

        final List<Widget> children = [];

        // Favorites section at the top
        if (favoriteCategories.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    '즐겨찾기',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                  ),
                ],
              ),
            ),
          );
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: favoriteCategories.map((cat) {
                  // Find group name for display
                  String? groupName;
                  for (final g in groups) {
                    if (g.categories.any((c) => c.id == cat.id)) {
                      groupName = g.name;
                      break;
                    }
                  }
                  if (_isMulti) {
                    final selected = _tempCategoryIds.contains(cat.id);
                    return FilterChip(
                      label: Text(cat.name),
                      avatar: const Icon(Icons.star, size: 14, color: Colors.amber),
                      selected: selected,
                      onSelected: (_) => _toggleCategory(cat.id),
                    );
                  }
                  return ActionChip(
                    label: Text(cat.name),
                    avatar: const Icon(Icons.star, size: 14, color: Colors.amber),
                    onPressed: () {
                      widget.onSelected!(cat);
                      widget.onSelectedWithGroupName?.call(cat, groupName);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ),
          );
          children.add(const Divider());
        }

        // Shared section — show all groups (including empty) so newly-created
        // groups appear in the sheet immediately for "+ 카테고리 추가" entry.
        // (회차 2 #15/#16 fix — hierarchical_empty_group_display 정책)
        for (final group in sharedGroups) {
          final filteredCategories = group.categories
              .where((c) => c.type == widget.categoryType)
              .toList()
            ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

          // 멀티 모드(필터 sheet) 에서는 선택할 카테고리가 없으면 의미 없으므로 skip.
          if (_isMulti && filteredCategories.isEmpty) continue;

          final isExpanded = _expandedGroupIds.contains(group.id);

          children.add(_buildGroupSection(
            context,
            group,
            filteredCategories,
            isExpanded,
            favCategoryIds,
          ));
        }

        // Add shared group button — hidden in multi mode (filter context)
        if (!_isMulti) {
          children.add(
            ListTile(
              dense: true,
              leading: Icon(
                Icons.add,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                '공유 그룹 추가',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () => _showAddGroupDialog(context),
            ),
          );
        }

        // Private section (couple mode only)
        if (coupled && (privateGroups.isNotEmpty || true)) {
          // Always show private section for discoverability in couple mode
          children.add(const SizedBox(height: 8));
          children.add(
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '나만 보임',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '상대방에게 보이지 않습니다',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
          );
          children.add(const SizedBox(height: 4));
        }

        // Private groups — show all (including empty) for the same reason.
        for (final group in privateGroups) {
          final filteredCategories = group.categories
              .where((c) => c.type == widget.categoryType)
              .toList()
            ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

          if (_isMulti && filteredCategories.isEmpty) continue;

          final isExpanded = _expandedGroupIds.contains(group.id);

          children.add(_buildGroupSection(
            context,
            group,
            filteredCategories,
            isExpanded,
            favCategoryIds,
          ));
        }

        // Add private group button (couple mode only, hidden in multi)
        if (coupled && !_isMulti) {
          children.add(
            ListTile(
              dense: true,
              leading: Icon(
                Icons.add,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(
                '개인 그룹 추가',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: () => _showAddGroupDialog(context, visibility: 'PRIVATE'),
            ),
          );
        }

        return ListView(
          shrinkWrap: true,
          children: children,
        );
      },
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    CategoryGroup group,
    List<Category> categories,
    bool isExpanded,
    List<String> favCategoryIds,
  ) {
    final color = UIHelpers.parseColor(group.color);

    final groupChecked = _isMulti && _tempGroupIds.contains(group.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header — expandable. 빈 그룹은 expand 시 "+ 하위 카테고리 추가" 만 노출.
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
                if (_isMulti)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Checkbox(
                      value: groupChecked,
                      onChanged: (value) =>
                          _setGroupCheckedCascade(group, value ?? false),
                    ),
                  ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    (group.isPrivate && isCoupleMode()) ? Icons.visibility_off : Icons.folder,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (categories.isEmpty)
                        Text(
                          '카테고리 없음 — 탭하여 추가',
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
          ...categories.map((c) => _buildCategoryTile(context, c, group.name, favCategoryIds)),
          // Add sub-category button — hidden in multi mode (filter context)
          if (!_isMulti)
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

  Widget _buildCategoryTile(
    BuildContext context,
    Category category,
    String groupName,
    List<String> favCategoryIds,
  ) {
    final isSingleSelected =
        !_isMulti && category.id == widget.selectedCategoryId;
    final isMultiSelected = _isMulti && _tempCategoryIds.contains(category.id);
    final color = UIHelpers.parseColor(category.color);
    final isFavorite = favCategoryIds.contains(category.id);

    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: ListTile(
        dense: true,
        leading: _isMulti
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: isMultiSelected,
                    onChanged: (_) => _toggleCategory(category.id),
                  ),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.label,
                      color: color,
                      size: 16,
                    ),
                  ),
                ],
              )
            : CircleAvatar(
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
            fontWeight:
                (isSingleSelected || isMultiSelected) ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSingleSelected || isMultiSelected,
        selectedTileColor: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Favorite star toggle
            GestureDetector(
              onTap: () {
                getIt<FavoritesBloc>().add(ToggleFavorite(
                  type: 'CATEGORY',
                  itemId: category.id,
                ));
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isFavorite ? Icons.star : Icons.star_outline,
                  size: 18,
                  color: isFavorite ? Colors.amber : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
            // Edit button — hidden in multi mode (filter context)
            if (!_isMulti)
              GestureDetector(
                onTap: () => _showEditCategoryDialog(context, category),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            if (isSingleSelected)
              Icon(
                Icons.check,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            // Delete button — hidden in multi mode (filter context)
            if (widget.onDelete != null && !_isMulti)
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
          if (_isMulti) {
            _toggleCategory(category.id);
          } else {
            widget.onSelected!(category);
            widget.onSelectedWithGroupName?.call(category, groupName);
            Navigator.of(context).pop();
          }
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

  Future<void> _showEditCategoryDialog(BuildContext context, Category category) async {
    _categoryNameController.text = category.name;
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('카테고리 수정'),
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
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (newName != null && newName != category.name && context.mounted) {
      getIt<CategoryBloc>().add(UpdateCategory(
        id: category.id,
        name: newName,
      ));
    }
  }

  Future<void> _confirmDelete(BuildContext context, Category category) async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: '카테고리 삭제',
      itemName: category.name,
    );
    if (confirmed) {
      widget.onDelete?.call(category.id);
      getIt<CategoryBloc>().add(DeleteCategory(category.id));
    }
  }

}
