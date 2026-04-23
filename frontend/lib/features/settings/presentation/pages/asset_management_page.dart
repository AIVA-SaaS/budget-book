import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/utils/couple_mode.dart';
import 'package:budget_book/core/utils/payment_method_helpers.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category/presentation/widgets/category_form_sheet.dart';
import 'package:budget_book/features/category/presentation/widgets/category_list_tile.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/balance_adjustment_dialog.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/payment_method_form_sheet.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/features/pocket/presentation/widgets/pocket_form_sheet.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';

class AssetManagementPage extends StatelessWidget {
  final int? initialYear;
  final int? initialMonth;

  /// Initial tab index: 0=카테고리, 1=결제수단, 2=포켓. Clamped to [0, 2].
  final int initialTabIndex;

  const AssetManagementPage({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = initialTabIndex.clamp(0, 2);
    return DefaultTabController(
      length: 3,
      initialIndex: safeIndex,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('자산 관리'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: '카테고리'),
                  Tab(text: '결제수단'),
                  Tab(text: '포켓'),
                ],
              ),
            ),
            body: const Column(
              children: [
                _AssetSummaryHeader(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _CategoryTab(),
                      _PaymentMethodTab(),
                      _PocketTab(),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: _buildFab(context),
          );
        },
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return ListenableBuilder(
      listenable: DefaultTabController.of(context),
      builder: (context, _) {
        return FloatingActionButton(
          onPressed: () {
            final currentIndex = DefaultTabController.of(context).index;
            switch (currentIndex) {
              case 0:
                _showAddCategory(context);
              case 1:
                _showAddPaymentMethod(context);
              case 2:
                _showAddPocket(context);
            }
          },
          tooltip: '추가',
          child: const Icon(Icons.add),
        );
      },
    );
  }

  void _showAddCategory(BuildContext context) {
    final bloc = context.read<CategoryBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryFormSheet(
        onSubmit: (name, type, icon, color, groupId) {
          bloc.add(CreateCategory(
            name: name,
            type: type,
            icon: icon,
            color: color,
            groupId: groupId,
          ));
        },
      ),
    );
  }

  void _showAddPaymentMethod(BuildContext context) {
    final bloc = context.read<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: PaymentMethodFormSheet(
          onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
            bloc.add(CreatePaymentMethod(
              name: name,
              type: type,
              settlementDay: settlementDay,
              closingDay: closingDay,
              linkedBankId: linkedBankId,
            ));
          },
        ),
      ),
    );
  }

  void _showAddPocket(BuildContext context) {
    final bloc = context.read<PocketBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PocketFormSheet(
        onSubmit:
            (name, type, allocatedAmount, icon, color, goalAmount, targetDate) {
          bloc.add(CreatePocket(
            name: name,
            type: type,
            allocatedAmount: allocatedAmount,
            icon: icon,
            color: color,
            goalAmount: goalAmount,
            targetDate: targetDate,
          ));
        },
      ),
    );
  }
}

const _virtualGroupId = '00000000-0000-0000-0000-000000000000';

class _CategoryTab extends StatelessWidget {
  const _CategoryTab();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CategoryGroupBloc>.value(
      value: getIt<CategoryGroupBloc>()..add(const LoadCategoryGroups()),
      child: BlocConsumer<CategoryGroupBloc, CategoryGroupState>(
        listener: (context, state) {
          if (state is CategoryGroupLoaded && state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is! CategoryGroupLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final coupled = isCoupleMode();
          final sharedGroups = coupled
              ? (state.groups.where((g) => g.isShared).toList()
                ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)))
              : (state.groups.toList()
                ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)));
          final privateGroups = coupled
              ? (state.groups.where((g) => g.isPrivate).toList()
                ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)))
              : <CategoryGroup>[];

          if (state.groups.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.category,
              title: '카테고리가 없습니다',
              subtitle: '+ 버튼을 눌러 카테고리를 추가하세요',
            );
          }

          return BlocListener<CategoryBloc, CategoryState>(
            listener: (context, catState) {
              if (catState is CategoryLoaded) {
                getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shared groups - reorderable
                  _buildReorderableGroupSection(
                    context,
                    groups: sharedGroups,
                  ),
                  // Add group button
                  _buildAddButton(
                    context,
                    icon: Icons.create_new_folder,
                    label: coupled ? '공유 그룹 추가' : '그룹 추가',
                    onTap: () => _showAddGroupDialog(context),
                  ),
                  // Private section (couple mode only)
                  if (coupled) ...[
                    const SizedBox(height: 8),
                    _buildPrivateSectionHeader(context),
                    // Private groups - reorderable
                    _buildReorderableGroupSection(
                      context,
                      groups: privateGroups,
                    ),
                    // Add private group button
                    _buildAddButton(
                      context,
                      icon: Icons.add,
                      label: '개인 그룹 추가',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      onTap: () => _showAddGroupDialog(context, visibility: 'PRIVATE'),
                    ),
                  ],
                  const SizedBox(height: 88),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReorderableGroupSection(
    BuildContext context, {
    required List<CategoryGroup> groups,
  }) {
    if (groups.isEmpty) return const SizedBox.shrink();

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevation =
                Tween<double>(begin: 0, end: 4).evaluate(animation);
            return Material(
              elevation: elevation,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shadowColor: Theme.of(context).shadowColor,
              borderRadius: BorderRadius.circular(8),
              child: child,
            );
          },
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final reordered = List<CategoryGroup>.from(groups);
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        getIt<CategoryGroupBloc>().add(
          ReorderCategoryGroups(reordered.map((g) => g.id).toList()),
        );
      },
      children: [
        for (int i = 0; i < groups.length; i++)
          _buildGroupSection(context, groups[i], groupIndex: i,
              key: ValueKey(groups[i].id)),
      ],
    );
  }

  Widget _buildPrivateSectionHeader(BuildContext context) {
    return Container(
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
    );
  }

  Widget _buildAddButton(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: c),
      title: Text(label, style: TextStyle(fontSize: 13, color: c)),
      onTap: onTap,
    );
  }

  Widget _buildGroupSection(BuildContext context, CategoryGroup group,
      {int groupIndex = 0, Key? key}) {
    final color = UIHelpers.parseColor(group.color);
    final isVirtual = group.id == _virtualGroupId;
    final sortedCategories = List<Category>.from(group.categories)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header with drag handle and edit/delete
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 8, 4),
          child: Row(
            children: [
              // Drag handle for group reorder
              ReorderableDragStartListener(
                index: groupIndex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(
                  (group.isPrivate && isCoupleMode()) ? Icons.visibility_off : Icons.folder,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Text(
                '${group.categories.length}개',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
              if (!isVirtual)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditGroupDialog(context, group);
                    } else if (value == 'delete') {
                      _showDeleteGroupDialog(context, group);
                    } else if (value == 'add_category') {
                      _showAddCategoryToGroup(context, group);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'add_category',
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 8),
                          Text('카테고리 추가'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('그룹 수정'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('그룹 삭제', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // Sub-categories (with drag handle reorder)
        if (sortedCategories.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 52, bottom: 8),
            child: Text(
              '하위 카테고리 없음',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
            ),
          )
        else
          _buildReorderableCategoryList(context, sortedCategories),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildReorderableCategoryList(
    BuildContext context,
    List<Category> sortedCategories,
  ) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevation =
                Tween<double>(begin: 0, end: 3).evaluate(animation);
            return Material(
              elevation: elevation,
              color: Theme.of(context).colorScheme.surface,
              shadowColor: Theme.of(context).shadowColor,
              child: child,
            );
          },
          child: child,
        );
      },
      itemCount: sortedCategories.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final reordered = List<Category>.from(sortedCategories);
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        getIt<CategoryBloc>().add(
          ReorderCategories(reordered.map((c) => c.id).toList()),
        );
        // Reload groups to reflect new order
        getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
      },
      itemBuilder: (context, index) {
        final c = sortedCategories[index];
        return Padding(
          key: ValueKey(c.id),
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            children: [
              Expanded(
                child: CategoryListTile(
                  category: c,
                  onEdit: () => _showEditCategory(context, c),
                  onDelete: () => _showDeleteCategoryDialog(context, c),
                ),
              ),
              if (sortedCategories.length > 1)
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Icon(
                      Icons.drag_handle,
                      size: 20,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAddGroupDialog(BuildContext context, {String visibility = 'SHARED'}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(visibility == 'PRIVATE' ? '개인 그룹 추가' : '그룹 추가'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '그룹 이름'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(dialogContext).pop();
                getIt<CategoryGroupBloc>().add(
                  CreateCategoryGroup(name: name, visibility: visibility),
                );
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showEditGroupDialog(BuildContext context, CategoryGroup group) {
    final controller = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('그룹 수정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '그룹 이름'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(dialogContext).pop();
                getIt<CategoryGroupBloc>().add(
                  UpdateCategoryGroup(id: group.id, name: name),
                );
              }
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog(BuildContext context, CategoryGroup group) {
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
              getIt<CategoryGroupBloc>().add(DeleteCategoryGroup(group.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryToGroup(BuildContext context, CategoryGroup group) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${group.name} - 카테고리 추가'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '카테고리 이름'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(dialogContext).pop();
                getIt<CategoryBloc>().add(CreateCategory(
                  name: name,
                  type: 'EXPENSE',
                  groupId: group.id,
                  visibility: group.visibility,
                ));
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showEditCategory(BuildContext context, Category category) {
    final bloc = context.read<CategoryBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryFormSheet(
        category: category,
        onSubmit: (name, type, icon, color, groupId) {
          bloc.add(UpdateCategory(
            id: category.id,
            name: name,
            icon: icon,
            color: color,
            groupId: groupId,
          ));
        },
      ),
    );
  }

  void _showDeleteCategoryDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text(
            "'${category.name}' 카테고리를 삭제하시겠습니까?\n이 카테고리를 사용하는 거래의 카테고리가 해제됩니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<CategoryBloc>().add(DeleteCategory(category.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

}

class _PaymentMethodTab extends StatelessWidget {
  const _PaymentMethodTab();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentMethodBloc, PaymentMethodState>(
      listener: (context, state) {
        if (state is PaymentMethodLoaded && state.operationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.operationError!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is! PaymentMethodLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final methods = List<PaymentMethod>.from(state.paymentMethods)
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

        if (methods.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.payment,
            title: '결제수단이 없습니다',
            subtitle: '+ 버튼을 눌러 결제수단을 추가하세요',
          );
        }

        // Build a flat list with type group headers inserted
        final itemsWithHeaders = <_PaymentMethodListItem>[];
        String? lastType;
        for (final method in methods) {
          if (method.type != lastType) {
            itemsWithHeaders.add(_PaymentMethodListItem.header(method.type));
            lastType = method.type;
          }
          itemsWithHeaders.add(_PaymentMethodListItem.method(method));
        }

        // For reorder we need original method indices
        // The ReorderableListView operates on the full list including headers
        return ReorderableListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 88),
          itemCount: itemsWithHeaders.length,
          buildDefaultDragHandles: false,
          onReorder: (oldIndex, newIndex) {
            // Ignore if dragging a header
            if (itemsWithHeaders[oldIndex].isHeader) return;

            // Convert visual indices to method-only indices
            int methodOldIndex = 0;
            int methodNewIndex = 0;
            int methodCount = 0;
            for (int i = 0; i < itemsWithHeaders.length; i++) {
              if (!itemsWithHeaders[i].isHeader) {
                if (i == oldIndex) methodOldIndex = methodCount;
                if (i == newIndex) methodNewIndex = methodCount;
                methodCount++;
              } else {
                if (i == newIndex) {
                  // Dropped on a header — use the next method index
                  methodNewIndex = methodCount;
                }
              }
            }

            if (newIndex > oldIndex) {
              // When moving down, account for removal shifting
              // But since we mapped to method indices, adjust accordingly
            }
            if (methodOldIndex == methodNewIndex) return;

            final reordered = List<PaymentMethod>.from(methods);
            if (methodNewIndex > methodOldIndex) methodNewIndex--;
            final item = reordered.removeAt(methodOldIndex);
            reordered.insert(methodNewIndex, item);
            context.read<PaymentMethodBloc>().add(
              ReorderPaymentMethods(reordered.map((m) => m.id).toList()),
            );
          },
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final elevation = Tween<double>(begin: 0, end: 4).evaluate(animation);
                return Material(
                  elevation: elevation,
                  color: Colors.transparent,
                  shadowColor: Theme.of(context).shadowColor,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                );
              },
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final listItem = itemsWithHeaders[index];

            if (listItem.isHeader) {
              final typeLabel = paymentMethodGroupLabels[listItem.type] ?? listItem.type!;
              final typeColor = paymentMethodTypeColor(listItem.type!);
              return Container(
                key: ValueKey('header_${listItem.type}'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      paymentMethodTypeIcon(listItem.type!),
                      size: 16,
                      color: typeColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      typeLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                    ),
                  ],
                ),
              );
            }

            final method = listItem.paymentMethod!;
            return Row(
              key: ValueKey(method.id),
              children: [
                Expanded(
                  child: _buildPaymentMethodTile(context, method),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Icon(
                      Icons.drag_handle,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentMethodTile(BuildContext context, PaymentMethod method) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: paymentMethodTypeColor(method.type).withValues(alpha: 0.15),
        child: Icon(
          paymentMethodTypeIcon(method.type),
          color: paymentMethodTypeColor(method.type),
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(method.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          buildPaymentMethodTypeBadge(context, method.type),
          if (!method.isActive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .error
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '비활성',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: _buildTileSubtitle(context, method),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: method.isActive,
            onChanged: (value) {
              context.read<PaymentMethodBloc>().add(
                    UpdatePaymentMethod(id: method.id, isActive: value),
                  );
            },
          ),
          // Explicit "잔액 수정" tune button (non-credit only).
          // Credit cards derive their usage from pending transactions and do
          // not expose a mutable balance.
          if (!method.isCredit)
            IconButton(
              icon: const Icon(Icons.tune, size: 20),
              tooltip: '잔액 수정',
              onPressed: () => _showBalanceAdjustment(context, method),
            ),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'edit') {
                _showEditPaymentMethod(context, method);
              } else if (action == 'delete') {
                _showDeleteDialog(context, method);
              } else if (action == 'history') {
                final monthState = context.read<MonthCubit>().state;
                context.push(
                  '/transactions?paymentMethodId=${method.id}'
                  '&paymentMethodName=${Uri.encodeComponent(method.name)}'
                  '&year=${monthState.year}&month=${monthState.month}',
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 20),
                    SizedBox(width: 8),
                    Text('내역 보기'),
                  ],
                ),
              ),
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
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Text('삭제',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the subtitle row for a payment method tile.
  ///
  /// - Credit cards: 미결제 + 이번달 사용 (from `cardSettlementSummary`).
  ///   Falls back to "마감일/결제일" when the summary is not yet loaded so the
  ///   tile is never empty.
  /// - Non-credit (BANK/CASH/DEBIT): 잔액 (from `PaymentMethod.balance`).
  Widget? _buildTileSubtitle(BuildContext context, PaymentMethod method) {
    final mutedStyle = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    );

    if (method.isCredit) {
      int? pendingAmount;
      int? monthUsage;
      final pmState = context.watch<PaymentMethodBloc>().state;
      if (pmState is PaymentMethodLoaded &&
          pmState.cardSettlementSummary != null) {
        final summary = pmState.cardSettlementSummary!;
        try {
          final unpaidCards = summary.unpaidMonth?.cards
                  .where((c) => c.paymentMethodId == method.id) ??
              const Iterable.empty();
          if (unpaidCards.isNotEmpty) {
            pendingAmount = unpaidCards.first.amount;
          }
          final currentCards = summary.currentMonth.cards
              .where((c) => c.paymentMethodId == method.id);
          if (currentCards.isNotEmpty) {
            monthUsage = currentCards.first.amount;
          }
        } catch (_) {
          // Defensive: summary shape mismatch shouldn't break the tile.
        }
      }

      // Show the summary row when we have any data; otherwise fall back
      // to the closing/settlement day hint.
      if (pendingAmount != null || monthUsage != null) {
        return Text(
          '미결제: ${CurrencyFormatter.format(pendingAmount ?? 0)}원   '
          '이번달 사용: ${CurrencyFormatter.format(monthUsage ?? 0)}원',
          style: mutedStyle,
        );
      }
      return Text(
        '마감일: ${method.closingDay == 31 ? '말일' : '${method.closingDay ?? '-'}일'}, 결제일: ${method.settlementDay ?? '-'}일',
        style: mutedStyle,
      );
    }

    // BANK / CASH / DEBIT — show the current balance.
    if (method.balance != null) {
      final balance = method.balance!;
      final color = balance > 0
          ? Colors.green.shade700
          : balance < 0
              ? Colors.red.shade700
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
      return Text(
        '잔액: ${CurrencyFormatter.formatWithSign(balance)}원',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (method.isDefault) {
      return Text('기본 결제수단', style: mutedStyle);
    }
    return null;
  }

  void _showBalanceAdjustment(BuildContext context, PaymentMethod method) {
    final bloc = context.read<PaymentMethodBloc>();
    BalanceAdjustmentDialog.show(
      context,
      paymentMethod: method,
      onSuccess: () {
        // Reload payment methods so the new balance reflects on the tile.
        bloc.add(const LoadPaymentMethods());
      },
    );
  }

  void _showEditPaymentMethod(BuildContext context, PaymentMethod method) {
    final bloc = context.read<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: PaymentMethodFormSheet(
          paymentMethod: method,
          onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
            bloc.add(UpdatePaymentMethod(
              id: method.id,
              name: name,
              settlementDay: settlementDay,
              closingDay: closingDay,
              linkedBankId: linkedBankId,
              clearLinkedBank: linkedBankId == null && method.linkedBankId != null,
            ));
          },
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, PaymentMethod method) {
    final warningText = method.isDefault
        ? "'${method.name}'은(는) 기본 결제수단입니다. 삭제하시겠습니까?\n이 결제수단을 사용한 거래 기록은 유지됩니다."
        : "'${method.name}' 결제수단을 삭제하시겠습니까?\n이 결제수단을 사용한 거래 기록은 유지됩니다.";
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('결제수단 삭제'),
        content: Text(warningText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<PaymentMethodBloc>()
                  .add(DeletePaymentMethod(method.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _PocketTab extends StatelessWidget {
  const _PocketTab();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PocketBloc, PocketState>(
      listener: (context, state) {
        if (state is PocketLoaded && state.operationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.operationError!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is! PocketLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final pockets = state.pockets;

        if (pockets.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.savings,
            title: '포켓이 없습니다',
            subtitle: '+ 버튼을 눌러 포켓을 추가하세요',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: pockets.length,
          itemBuilder: (context, index) =>
              _buildPocketTile(context, pockets[index]),
        );
      },
    );
  }

  Widget _buildPocketTile(BuildContext context, MoneyPocket pocket) {
    final color = UIHelpers.parseColor(pocket.color);
    final typeLabel = switch (pocket.type) {
      'LIVING' => '생활비',
      'FIXED' => '고정지출',
      'CARD_PENDING' => '카드미결제',
      'SAVINGS' => '저축',
      'CUSTOM' => '직접입력',
      _ => pocket.type,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            UIHelpers.resolveIcon(pocket.icon, fallback: Icons.account_balance_wallet),
            color: color,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Flexible(
                child: Text(pocket.name, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '잔액: ${CurrencyFormatter.format(pocket.balance)}원 / 할당: ${CurrencyFormatter.format(pocket.allocatedAmount)}원',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') {
              _showEditPocket(context, pocket);
            } else if (action == 'delete') {
              _showDeleteDialog(context, pocket);
            }
          },
          itemBuilder: (_) => [
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
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Text('삭제',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPocket(BuildContext context, MoneyPocket pocket) {
    final bloc = context.read<PocketBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PocketFormSheet(
        pocket: pocket,
        onSubmit:
            (name, type, allocatedAmount, icon, color, goalAmount, targetDate) {
          bloc.add(UpdatePocket(
            id: pocket.id,
            name: name,
            type: type,
            allocatedAmount: allocatedAmount,
            icon: icon,
            color: color,
            goalAmount: goalAmount,
            targetDate: targetDate,
          ));
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, MoneyPocket pocket) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('포켓 삭제'),
        content: Text("'${pocket.name}' 포켓을 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<PocketBloc>().add(DeletePocket(pocket.id));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

}

/// Top-of-page summary showing 총 자산 / 부채(미결제) / 순자산.
///
/// **Computation** (aggregated from `PaymentMethodBloc` state):
/// - 총 자산 = sum of `PaymentMethod.balance` for non-credit active methods
///   (CASH/BANK/DEBIT) whose balance is non-null. Matches
///   `AccountBalanceCard` which is the existing "자산 현황" aggregate.
/// - 부채(미결제) = sum of unpaid-month amounts across credit cards from
///   `cardSettlementSummary.unpaidMonth.cards` (paid_at IS NULL filter).
/// - 순자산 = 총 자산 − 부채.
///
/// The widget rebuilds on PaymentMethodBloc state changes, so month
/// switches / new transactions propagate automatically.
class _AssetSummaryHeader extends StatelessWidget {
  const _AssetSummaryHeader();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
      builder: (context, state) {
        int totalAssets = 0;
        int totalDebt = 0;
        if (state is PaymentMethodLoaded) {
          for (final pm in state.paymentMethods) {
            if (!pm.isActive) continue;
            if (!pm.isCredit && pm.balance != null) {
              totalAssets += pm.balance!;
            }
          }
          final unpaid = state.cardSettlementSummary?.unpaidMonth;
          if (unpaid != null) {
            for (final card in unpaid.cards) {
              totalDebt += card.amount;
            }
          }
        }
        final netWorth = totalAssets - totalDebt;

        return Padding(
          key: const Key('asset_summary_header'),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: '총 자산',
                  amount: totalAssets,
                  color: Colors.green.shade700,
                  icon: Icons.savings_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: '부채',
                  amount: totalDebt,
                  color: Colors.red.shade700,
                  icon: Icons.credit_card_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: '순자산',
                  amount: netWorth,
                  color: netWorth >= 0
                      ? Colors.blue.shade700
                      : Colors.red.shade700,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${CurrencyFormatter.format(amount)}원',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper class for mixed list of headers and payment methods.
class _PaymentMethodListItem {
  final bool isHeader;
  final String? type;
  final PaymentMethod? paymentMethod;

  const _PaymentMethodListItem._({
    required this.isHeader,
    this.type,
    this.paymentMethod,
  });

  factory _PaymentMethodListItem.header(String type) =>
      _PaymentMethodListItem._(isHeader: true, type: type);

  factory _PaymentMethodListItem.method(PaymentMethod method) =>
      _PaymentMethodListItem._(isHeader: false, paymentMethod: method, type: method.type);
}
