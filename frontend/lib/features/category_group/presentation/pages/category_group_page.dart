import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';
import 'package:budget_book/features/category_group/presentation/widgets/category_group_form_sheet.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';

class CategoryGroupPage extends StatelessWidget {
  const CategoryGroupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리 그룹'),
      ),
      body: BlocConsumer<CategoryGroupBloc, CategoryGroupState>(
        listener: (context, state) {
          if (state is CategoryGroupError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is CategoryGroupLoaded &&
              state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            CategoryGroupInitial() ||
            CategoryGroupLoading() =>
              const Center(child: CircularProgressIndicator()),
            CategoryGroupLoaded(groups: final groups) =>
              _buildGroupList(context, groups),
            CategoryGroupError() => _buildError(context),
          };
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGroup(context),
        tooltip: '그룹 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGroupList(BuildContext context, List<CategoryGroup> groups) {
    if (groups.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.folder,
        title: '카테고리 그룹이 없습니다',
        subtitle: '그룹을 추가하여 카테고리를 정리하세요',
        actionLabel: '그룹 추가',
        onAction: () => _showAddGroup(context),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupTile(context, group);
      },
    );
  }

  Widget _buildGroupTile(BuildContext context, CategoryGroup group) {
    final color = UIHelpers.parseColor(group.color);
    final budgetTypeLabel = _budgetTypeLabel(group.budgetType);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            UIHelpers.resolveIcon(group.icon, fallback: Icons.folder),
            color: color,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                group.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (budgetTypeLabel != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  budgetTypeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${group.categories.length}개 카테고리',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditGroup(context, group);
            } else if (value == 'delete') {
              _showDeleteDialog(context, group);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('수정'),
                ],
              ),
            ),
            if (!group.isDefault)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('삭제', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
        children: group.categories.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '이 그룹에 속한 카테고리가 없습니다',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ]
            : group.categories
                .map((category) => _buildCategoryItem(context, category))
                .toList(),
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, Category category) {
    final color = UIHelpers.parseColor(category.color);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(
          UIHelpers.resolveIcon(category.icon, fallback: Icons.folder),
          color: color,
          size: 14,
        ),
      ),
      title: Text(
        category.name,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: category.isDefault
          ? Text(
              '기본',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
            )
          : null,
    );
  }

  Widget _buildError(BuildContext context) {
    return AppErrorWidget(
      message: '카테고리 그룹을 불러오지 못했습니다',
      onRetry: () {
        context
            .read<CategoryGroupBloc>()
            .add(const LoadCategoryGroups());
      },
      showHomeButton: true,
    );
  }

  void _showAddGroup(BuildContext context) {
    final bloc = context.read<CategoryGroupBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryGroupFormSheet(
        onSubmit: (name, icon, color, budgetType) {
          bloc.add(CreateCategoryGroup(
            name: name,
            icon: icon,
            color: color,
            budgetType: budgetType,
          ));
        },
      ),
    );
  }

  void _showEditGroup(BuildContext context, CategoryGroup group) {
    final bloc = context.read<CategoryGroupBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryGroupFormSheet(
        group: group,
        onSubmit: (name, icon, color, budgetType) {
          bloc.add(UpdateCategoryGroup(
            id: group.id,
            name: name,
            icon: icon,
            color: color,
            budgetType: budgetType,
          ));
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, CategoryGroup group) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('그룹 삭제'),
        content: Text(
          "'${group.name}' 그룹을 삭제하시겠습니까?\n그룹에 속한 카테고리는 미분류로 이동합니다.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<CategoryGroupBloc>()
                  .add(DeleteCategoryGroup(group.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  String? _budgetTypeLabel(String budgetType) {
    return switch (budgetType) {
      'MONTHLY' => '월간',
      'WEEKLY' => '주간',
      _ => null,
    };
  }

}
