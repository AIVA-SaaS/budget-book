import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'package:budget_book/features/payment_method/presentation/widgets/payment_method_form_sheet.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/features/pocket/presentation/widgets/pocket_form_sheet.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/balance_adjustment_sheet.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/features/payment_method/domain/entities/card_settlement_summary.dart';

/// Phase 25 후속 — 자산 탭의 [지출/수입] 토글과 카테고리 추가 dialog 사이 공유 state.
/// _CategoryTab 이 토글 변경 시 갱신하고, FAB 의 _showAddCategory 가 읽어
/// CategoryFormSheet.initialType 으로 전달한다.
String _lastSelectedCategoryType = 'EXPENSE';

/// 그룹 추가 dialog — 자산 페이지(FAB modal sheet) 와 카테고리 탭(inline)
/// 두 곳에서 공통 호출. file-level 로 두어 양쪽에서 사용 가능.
void _showAddGroupDialogTopLevel(
  BuildContext context, {
  String visibility = 'SHARED',
  String categoryType = 'EXPENSE',
}) {
  final controller = TextEditingController();
  final typeLabel = categoryType == 'INCOME' ? '수입' : '지출';
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        '$typeLabel ${visibility == 'PRIVATE' ? '개인 그룹' : '그룹'} 추가',
      ),
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
                CreateCategoryGroup(
                  name: name,
                  visibility: visibility,
                  categoryType: categoryType,
                ),
              );
            }
          },
          child: const Text('추가'),
        ),
      ],
    ),
  );
}

class AssetManagementPage extends StatelessWidget {
  final int? initialYear;
  final int? initialMonth;

  const AssetManagementPage({super.key, this.initialYear, this.initialMonth});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      // 사용자 요청: 결제수단을 첫 번째로 (자산 탭 클릭 시 default).
      initialIndex: 0,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('자산 관리'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: '결제수단'),
                  Tab(text: '카테고리'),
                  Tab(text: '포켓'),
                ],
              ),
            ),
            body: const Column(
              children: [
                _AssetSummaryHeader(),
                _CardSettlementHeader(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _PaymentMethodTab(),
                      _CategoryTab(),
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
            // 사용자 요청 순서 변경: 0=결제수단, 1=카테고리, 2=포켓
            switch (currentIndex) {
              case 0:
                _showAddPaymentMethod(context);
              case 1:
                _showAddCategoryOrGroupSheet(context);
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
        initialType: _lastSelectedCategoryType,
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

  /// FAB 통일 — 카테고리 sub-tab 에서 그룹/카테고리 추가 modal sheet.
  /// 사용자 의견 반영(2회): grid 카드 형태 + 색상 칩 type 강조.
  void _showAddCategoryOrGroupSheet(BuildContext context) {
    final coupled = isCoupleMode();
    final isIncome = _lastSelectedCategoryType == 'INCOME';
    final typeLabel = isIncome ? '수입' : '지출';
    final typeColor = isIncome ? Colors.blue.shade700 : Colors.deepOrange;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '추가하기',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _AddOptionCard(
                      icon: Icons.label_outline,
                      label: '카테고리',
                      color: typeColor,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _showAddCategory(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AddOptionCard(
                      icon: Icons.create_new_folder_outlined,
                      label: coupled ? '공유 그룹' : '그룹',
                      color: typeColor,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _showAddGroupDialogTopLevel(
                          context,
                          categoryType: _lastSelectedCategoryType,
                        );
                      },
                    ),
                  ),
                  if (coupled) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AddOptionCard(
                        icon: Icons.lock_outline,
                        label: '개인 그룹',
                        color: typeColor,
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          _showAddGroupDialogTopLevel(
                            context,
                            visibility: 'PRIVATE',
                            categoryType: _lastSelectedCategoryType,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
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

class _CategoryTab extends StatefulWidget {
  const _CategoryTab();

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> {
  // Phase 25 후속 E-3 — 카테고리 그룹 EXPENSE/INCOME 분리. 페이지 내 토글로 전환.
  // 마지막 선택을 top-level state(`_lastSelectedCategoryType`) 에 동기화하여
  // FAB → 카테고리 추가 시 같은 type 의 dialog 노출.
  String _selectedType = _lastSelectedCategoryType;

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
          // type 별 필터링 — 사용자가 선택한 EXPENSE/INCOME 만 노출.
          final allTypeFiltered = state.groups
              .where((g) => g.categoryType == _selectedType)
              .toList();
          final sharedGroups = coupled
              ? (allTypeFiltered.where((g) => g.isShared).toList()
                ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)))
              : (allTypeFiltered.toList()
                ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)));
          final privateGroups = coupled
              ? (allTypeFiltered.where((g) => g.isPrivate).toList()
                ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)))
              : <CategoryGroup>[];

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
                  // EXPENSE / INCOME 토글
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'EXPENSE', label: Text('지출'), icon: Icon(Icons.shopping_cart_outlined, size: 16)),
                        ButtonSegment(value: 'INCOME', label: Text('수입'), icon: Icon(Icons.trending_up, size: 16)),
                      ],
                      selected: {_selectedType},
                      onSelectionChanged: (s) {
                        setState(() => _selectedType = s.first);
                        _lastSelectedCategoryType = s.first;
                      },
                    ),
                  ),
                  if (allTypeFiltered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: EmptyStateWidget(
                        icon: Icons.category,
                        title: _selectedType == 'EXPENSE'
                            ? '지출 카테고리 그룹이 없습니다'
                            : '수입 카테고리 그룹이 없습니다',
                        subtitle: '+ 버튼을 눌러 추가하세요',
                      ),
                    )
                  else ...[
                    // Shared groups - reorderable
                    _buildReorderableGroupSection(
                      context,
                      groups: sharedGroups,
                    ),
                  ],
                  // 사용자 요청 — FAB 로 통일. inline 그룹 추가 버튼 제거.
                  // (그룹/카테고리 추가는 화면 우하단 + 버튼의 modal sheet 로)
                  // Private section (couple mode only)
                  if (coupled) ...[
                    const SizedBox(height: 8),
                    _buildPrivateSectionHeader(context),
                    // Private groups - reorderable
                    _buildReorderableGroupSection(
                      context,
                      groups: privateGroups,
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

class _PaymentMethodTab extends StatefulWidget {
  const _PaymentMethodTab();

  @override
  State<_PaymentMethodTab> createState() => _PaymentMethodTabState();
}

/// 로컬 reorder state: 사용자가 drop 시 즉시 반영하기 위해 bloc state 와
/// 별개로 _localMethods 를 유지한다. PUT 백그라운드 진행 동안 화면은
/// _localMethods 가 노출. PUT 응답 후 listener 가 bloc state 와 동기화.
class _PaymentMethodTabState extends State<_PaymentMethodTab> {
  List<PaymentMethod>? _localMethods;

  /// bloc state 의 paymentMethods 를 displayOrder ASC 로 정렬하여 반환.
  List<PaymentMethod> _sortedFromState(PaymentMethodLoaded state) {
    return List<PaymentMethod>.from(state.paymentMethods)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentMethodBloc, PaymentMethodState>(
      listenWhen: (prev, curr) => curr is PaymentMethodLoaded,
      listener: (context, state) {
        if (state is! PaymentMethodLoaded) return;

        // 동기화: PUT 응답 후 bloc state 가 도착하면 _localMethods 갱신.
        // 사용자 drop 직후에는 _justReordered 가 true 이므로, 같은 ids 라면
        // displayOrder 만 업데이트 (visual 변화 없음). 다른 변경(예: 외부에서
        // 추가/삭제) 이라면 새 list 로 교체.
        final fromState = _sortedFromState(state);
        if (!mounted) return;
        setState(() {
          _localMethods = fromState;
        });

        if (state.operationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.operationError!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        // 우선 _localMethods 사용 (즉시 반영 보장).
        final List<PaymentMethod> methods;
        final CardSettlementSummary? settlement;
        if (_localMethods != null) {
          methods = _localMethods!;
          settlement =
              state is PaymentMethodLoaded ? state.cardSettlementSummary : null;
        } else if (state is PaymentMethodLoaded) {
          methods = _sortedFromState(state);
          settlement = state.cardSettlementSummary;
        } else {
          return const Center(child: CircularProgressIndicator());
        }

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

            // Flutter ReorderableListView 규약: 아래로 이동 시 newIndex 가
            // 1 크게 들어옴. visual index 단계에서 먼저 보정한다.
            int adjustedNewIndex = newIndex;
            if (adjustedNewIndex > oldIndex) adjustedNewIndex -= 1;

            // 같은 type 내에서만 재정렬 허용 (type 경계 이동 금지).
            final draggedType =
                itemsWithHeaders[oldIndex].paymentMethod!.type;

            // 드롭 위치(adjustedNewIndex)의 type 을 결정.
            // - 리스트 끝(adjustedNewIndex == length): 마지막 item 의 type
            // - 헤더 위치: 해당 헤더의 type
            // - 그 외: 해당 method 의 type
            String targetType;
            if (adjustedNewIndex >= itemsWithHeaders.length) {
              targetType = itemsWithHeaders.last.isHeader
                  ? itemsWithHeaders.last.type!
                  : itemsWithHeaders.last.paymentMethod!.type;
            } else {
              final targetItem = itemsWithHeaders[adjustedNewIndex];
              targetType = targetItem.isHeader
                  ? targetItem.type!
                  : targetItem.paymentMethod!.type;
            }
            if (draggedType != targetType) return;

            // visual → method-only index 변환 (헤더 제외).
            // 경계 처리: adjustedNewIndex 가 list 길이 이상이면 methodCount 전체.
            int methodOldIndex = 0;
            int methodNewIndex = -1;
            int methodCount = 0;
            for (int i = 0; i < itemsWithHeaders.length; i++) {
              if (i == adjustedNewIndex && methodNewIndex == -1) {
                methodNewIndex = methodCount;
              }
              if (!itemsWithHeaders[i].isHeader) {
                if (i == oldIndex) methodOldIndex = methodCount;
                methodCount++;
              }
            }
            // 끝까지 매칭 안 됐으면 맨 끝에 삽입
            if (methodNewIndex == -1) methodNewIndex = methodCount;

            if (methodOldIndex == methodNewIndex) return;

            // visual 단계에서 이미 -1 보정했으므로 method 단계 추가 보정 금지.
            final reordered = List<PaymentMethod>.from(methods);
            final item = reordered.removeAt(methodOldIndex);
            reordered.insert(methodNewIndex, item);

            // FE 즉시 반영: displayOrder 도 새 인덱스로 갱신해 _localMethods 에
            // 저장. PUT 응답 후 listener 가 동기화 (같은 순서면 visual 동일).
            // builder rebuild 시 _localMethods 우선 → ReorderableListView 가
            // 같은 child list 받음 → native drop animation 보존.
            final reorderedWithOrder = <PaymentMethod>[];
            for (int i = 0; i < reordered.length; i++) {
              reorderedWithOrder.add(reordered[i].copyWith(displayOrder: i));
            }
            setState(() {
              _localMethods = reorderedWithOrder;
            });

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
                  child: _buildPaymentMethodTile(
                    context,
                    method,
                    settlement,
                  ),
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

  Widget _buildPaymentMethodTile(
    BuildContext context,
    PaymentMethod method,
    CardSettlementSummary? settlement,
  ) {
    final theme = Theme.of(context);

    // Phase 25 Step 4 — 잔액/미결제 표시 (v1.0 payment_method_page 이식)
    Widget? subtitle;
    if (method.isCredit) {
      // 카드: 마감일/결제일 + 미결제/이번달 (settlement 기준)
      final prevAmount = settlement?.previousMonth.cards
              .firstWhere((c) => c.paymentMethodId == method.id,
                  orElse: () => const CardSettlementCard(
                      paymentMethodId: '',
                      paymentMethodName: '',
                      amount: 0,
                      transactionCount: 0))
              .amount ??
          0;
      final currAmount = settlement?.currentMonth.cards
              .firstWhere((c) => c.paymentMethodId == method.id,
                  orElse: () => const CardSettlementCard(
                      paymentMethodId: '',
                      paymentMethodName: '',
                      amount: 0,
                      transactionCount: 0))
              .amount ??
          0;
      final unpaidAmount = settlement?.unpaidMonth?.cards
              .firstWhere((c) => c.paymentMethodId == method.id,
                  orElse: () => const CardSettlementCard(
                      paymentMethodId: '',
                      paymentMethodName: '',
                      amount: 0,
                      transactionCount: 0))
              .amount ??
          0;
      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '마감일: ${method.closingDay == 31 ? '말일' : '${method.closingDay ?? '-'}일'}, 결제일: ${method.settlementDay ?? '-'}일',
            style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 2),
          // 회차 12 follow-up (2026-05-04) — 모바일에서 chip 3개 + trailing
          // (Switch + PopupMenu) 가로 overflow 방지. Wrap 으로 좁은 화면 시
          // 자동 줄바꿈.
          if (settlement != null)
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                _SubChip(
                    label: '전월',
                    value: prevAmount,
                    bg: Colors.grey.shade200,
                    fg: Colors.grey.shade800),
                _SubChip(
                    label: '미결제',
                    value: unpaidAmount,
                    bg: unpaidAmount > 0 ? Colors.red.shade50 : Colors.green.shade50,
                    fg: unpaidAmount > 0 ? Colors.red.shade800 : Colors.green.shade800),
                _SubChip(
                    label: '이번달',
                    value: currAmount,
                    bg: Colors.blue.shade50,
                    fg: Colors.blue.shade800),
              ],
            ),
        ],
      );
    } else {
      // 비-카드: 잔액 표시 (null 시 0원 fallback) + 기본 결제수단 뱃지
      final balance = method.balance ?? 0;
      final sign = balance >= 0 ? Colors.green.shade800 : Colors.red.shade800;
      // 회차 12 follow-up — 모바일에서 잔액 + "기본" 라벨 overflow 방지.
      subtitle = Row(
        children: [
          Flexible(
            child: Text(
              '잔액: ${CurrencyFormatter.formatWithSign(balance)}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: sign),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (method.isDefault) ...[
            const SizedBox(width: 8),
            Text('· 기본',
                style: TextStyle(
                    fontSize: 11,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.45))),
          ],
        ],
      );
    }

    return ListTile(
      // 사용자 요청: 자산 항목 클릭 시 해당 결제수단으로 필터된 거래 탭으로 이동
      onTap: () {
        final encodedName = Uri.encodeComponent(method.name);
        context.go(
          '/transactions?paymentMethodId=${method.id}&paymentMethodName=$encodedName',
        );
      },
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
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '비활성',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 회차 12 follow-up (2026-05-04) — 모바일에서 Switch 가 trailing 공간
          // 과도하게 차지하여 subtitle chip overflow 유발. visualDensity +
          // materialTapTargetSize 로 컴팩트화.
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: method.isActive,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) {
                context.read<PaymentMethodBloc>().add(
                      UpdatePaymentMethod(id: method.id, isActive: value),
                    );
              },
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'edit') {
                _showEditPaymentMethod(context, method);
              } else if (action == 'delete') {
                _showDeleteDialog(context, method);
              } else if (action == 'adjust_balance') {
                BalanceAdjustmentSheet.show(
                  context,
                  paymentMethodId: method.id,
                  paymentMethodName: method.name,
                  currentBalance: method.balance ?? 0,
                );
              }
            },
            itemBuilder: (_) => [
              // Phase 25 Step 4 — 잔액 수정 popup 항목 (비-카드만, tune IconButton 분리 금지)
              if (!method.isCredit)
                const PopupMenuItem(
                  value: 'adjust_balance',
                  child: Row(
                    children: [
                      Icon(Icons.tune, size: 20),
                      SizedBox(width: 8),
                      Text('잔액 수정'),
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
                        size: 20, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text('삭제',
                        style: TextStyle(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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

/// Phase 25 Step 3 — 자산 탭 상단 총자산 / 부채 / 순자산 3카드.
/// 데이터 출처:
///   - 총자산: CASH / DEBIT / BANK 의 balance 합계 (null 은 0 처리)
///   - 부채: cardSettlementSummary.unpaidMonth 합계 (미결제 카드)
///   - 순자산: 총자산 - 부채
class _AssetSummaryHeader extends StatelessWidget {
  const _AssetSummaryHeader();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
      builder: (context, state) {
        if (state is! PaymentMethodLoaded) {
          return const SizedBox.shrink();
        }

        final active = state.paymentMethods.where((pm) => pm.isActive).toList();
        final asset = active
            .where((pm) => pm.isCash || pm.isDebit || pm.isBank)
            .fold<int>(0, (sum, pm) => sum + (pm.balance ?? 0));

        final debt = state.cardSettlementSummary?.unpaidMonth?.totalAmount ?? 0;
        final net = asset - debt;

        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: '총자산',
                  value: asset,
                  color: Colors.green.shade700,
                  bg: Colors.green.withValues(alpha: 0.08),
                  icon: Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: '부채',
                  value: debt,
                  color: Colors.red.shade700,
                  bg: Colors.red.withValues(alpha: 0.08),
                  icon: Icons.credit_card,
                  signed: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: '순자산',
                  value: net,
                  color: net >= 0 ? theme.colorScheme.primary : Colors.red.shade700,
                  bg: (net >= 0 ? theme.colorScheme.primary : Colors.red)
                      .withValues(alpha: 0.08),
                  icon: Icons.savings,
                  signed: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Phase 25 Step 5 — MonthNavigator + 3열 카드 summary (전월/미결제/이번달).
/// 결제수단 탭(index 1) 선택 + credit 카드 보유 시에만 렌더.
/// v1.0 payment_method_page.dart:131-161, 351-440 에서 이식.
class _CardSettlementHeader extends StatelessWidget {
  const _CardSettlementHeader();

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // 사용자 요청 순서 변경: 결제수단 탭이 index 0
        if (controller.index != 0) return const SizedBox.shrink();

        return BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
          builder: (context, state) {
            if (state is! PaymentMethodLoaded) {
              return const SizedBox.shrink();
            }
            final hasCredit =
                state.paymentMethods.any((pm) => pm.isCredit && pm.isActive);
            if (!hasCredit) return const SizedBox.shrink();

            final summary = state.cardSettlementSummary;
            if (summary == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: MonthNavigator(),
              );
            }

            final theme = Theme.of(context);
            return Column(
              children: [
                const MonthNavigator(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SettlementCard(
                          label: '전월 사용',
                          amount: summary.previousMonth.totalAmount,
                          count: summary.previousMonth.cards.length,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SettlementCard(
                          label: '미결제',
                          amount: summary.unpaidMonth?.totalAmount ?? 0,
                          count: summary.unpaidMonth?.cards.length ?? 0,
                          color: (summary.unpaidMonth?.totalAmount ?? 0) > 0
                              ? theme.colorScheme.error
                              : Colors.green.shade700,
                          highlight: (summary.unpaidMonth?.totalAmount ?? 0) > 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SettlementCard(
                          label: '이번달 사용',
                          amount: summary.currentMonth.totalAmount,
                          count: summary.currentMonth.cards.length,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final String label;
  final int amount;
  final int count;
  final Color color;
  final bool highlight;

  const _SettlementCard({
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${CurrencyFormatter.format(amount)}원',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (count > 0)
            Text('$count건',
                style: TextStyle(
                    fontSize: 10,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class _SubChip extends StatelessWidget {
  final String label;
  final int value;
  final Color bg;
  final Color fg;
  const _SubChip({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        '$label ${CurrencyFormatter.format(value)}원',
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color bg;
  final IconData icon;
  final bool signed;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.icon,
    this.signed = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = signed
        ? CurrencyFormatter.formatWithSign(value)
        : CurrencyFormatter.format(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatted,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// FAB modal sheet 의 grid 옵션 카드.
class _AddOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddOptionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
