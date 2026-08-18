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
import 'package:budget_book/core/theme/bb_colors.dart';
import 'package:budget_book/core/theme/bb_density.dart';
import 'package:budget_book/core/widgets/asset_edit_mode_scope.dart';
import 'package:budget_book/core/widgets/entity_tile_row.dart';
import 'package:budget_book/core/widgets/one_line_label.dart';
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

class AssetManagementPage extends StatefulWidget {
  final int? initialYear;
  final int? initialMonth;

  const AssetManagementPage({super.key, this.initialYear, this.initialMonth});

  @override
  State<AssetManagementPage> createState() => _AssetManagementPageState();
}

class _AssetManagementPageState extends State<AssetManagementPage> {
  /// 보기 모드는 이름 + 금액만 보여준다. 활성 토글 · 설정(⋮) · 순서 변경(≡) 은
  /// 이 컨트롤러가 켜졌을 때만 나타난다. 탭을 바꿔도 유지되고, 화면을 나가면
  /// 컨트롤러와 함께 사라진다 (검증 B6).
  final AssetEditModeController _editMode = AssetEditModeController();

  @override
  void dispose() {
    _editMode.dispose();
    super.dispose();
  }

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
              actions: [_buildEditToggle(context)],
              bottom: const TabBar(
                tabs: [
                  Tab(text: '결제수단'),
                  Tab(text: '카테고리'),
                  Tab(text: '포켓'),
                ],
              ),
            ),
            // 회차 12 follow-up Phase 1 (2026-05-04) — MonthNavigator 최상단 이동.
            // 회차 12 follow-up Phase 2 (2026-05-04) — 자산 금액 (총자산/부채/순자산)
            // 과 사용 금액 (전월/미결제/이번달) 을 PageView 로 통합. 좌우 스와이프 +
            // dot indicator 로 동일 영역에서 데이터 전환. 결제수단 탭 + credit 보유
            // 시에만 2 page, 그외는 자산 1 page.
            body: AssetEditModeScope(
              controller: _editMode,
              child: const Column(
                children: [
                  MonthNavigator(),
                  _AssetPagerHeader(),
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
            ),
            floatingActionButton: _buildFab(context),
          );
        },
      ),
    );
  }

  /// 아이콘만 두면 편집 진입을 못 찾는다는 어포던스 위험(R1)이 있어 라벨을 병기한다.
  Widget _buildEditToggle(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _editMode,
      builder: (context, editing, _) {
        return TextButton.icon(
          onPressed: _editMode.toggle,
          icon: Icon(editing ? Icons.check : Icons.edit_outlined, size: 18),
          label: Text(editing ? '완료' : '편집'),
        );
      },
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
    final typeColor =
        isIncome ? context.bb.income.color : context.bb.expense.color;

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
              // 순서: 공유 그룹 / 하위 카테고리 / 개인 그룹.
              // '카테고리' 는 그룹 아래에 들어가는 항목이므로 페이지 내 다른
              // 표현('하위 카테고리 없음' 등)과 통일해 '하위 카테고리' 로 표기.
              Row(
                children: [
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AddOptionCard(
                      icon: Icons.label_outline,
                      label: '하위 카테고리',
                      color: typeColor,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _showAddCategory(context);
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
    // guard S6 — 사용자 지정 색은 readable() 을 거쳐야 다크에서 묻지 않는다.
    final color = context.bb.readable(UIHelpers.parseColor(group.color));
    final editing = AssetEditModeScope.of(context);
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
              // Drag handle for group reorder — 편집 모드에서만.
              if (editing) ...[
                ReorderableDragStartListener(
                  index: groupIndex,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Icon(
                      Icons.drag_handle,
                      size: 20,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
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
              if (!isVirtual && editing)
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
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text('그룹 삭제',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
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
          // 순서 변경 핸들은 타일 안 편집 모드 레인으로 들어갔다 — 보기 모드에서
          // 이름이 쓸 수 있는 폭이 그만큼 돌아온다.
          child: CategoryListTile(
            category: c,
            onEdit: () => _showEditCategory(context, c),
            onDelete: () => _showDeleteCategoryDialog(context, c),
            reorderIndex: sortedCategories.length > 1 ? index : null,
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
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error),
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
                  // 그룹의 실제 타입(INCOME/EXPENSE)으로 생성.
                  // 과거 'EXPENSE' 하드코딩 → 수입 그룹에 하위 카테고리 추가 시
                  // EXPENSE 로 생성되어 수입 거래 폼 필터(c.type=='INCOME')에서
                  // 탈락 → 노출 안 됨.
                  type: group.categoryType,
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
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error),
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

  /// 타입 그룹 표시 우선순위 (현금→은행→체크→신용).
  /// paymentMethodGroupLabels 키 순서와 일치.
  static const List<String> _typeOrder = ['CASH', 'BANK', 'DEBIT', 'CREDIT'];

  /// bloc state 의 paymentMethods 를 **타입 그룹 → displayOrder** 순으로 정렬.
  /// displayOrder 만으로 정렬하면 같은 타입이 흩어져 헤더가 쪼개지는 버그
  /// (은행 항목이 은행 그룹에 안 모임) 가 있어, 타입을 1차 키로 둔다.
  /// reorder 는 동일 타입 내로 제한되므로 충돌 없음.
  List<PaymentMethod> _sortedFromState(PaymentMethodLoaded state) {
    int typeRank(String t) {
      final i = _typeOrder.indexOf(t);
      return i < 0 ? _typeOrder.length : i;
    }

    return List<PaymentMethod>.from(state.paymentMethods)
      ..sort((a, b) {
        final byType = typeRank(a.type).compareTo(typeRank(b.type));
        if (byType != 0) return byType;
        return a.displayOrder.compareTo(b.displayOrder);
      });
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
              final typeColor = context.bb.paymentType(listItem.type!);
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
            // 순서 변경 핸들은 이제 타일 안(편집 모드 액션 레인)에 있다. 예전처럼
            // 타일 밖 Row 로 빼면 보기 모드에서도 40dp 를 영구히 잡아먹는다.
            return KeyedSubtree(
              key: ValueKey(method.id),
              child: _buildPaymentMethodTile(context, method, settlement, index),
            );
          },
        );
      },
    );
  }

  /// 결제수단 한 행.
  ///
  /// 회차 12(2026-05-04) 의 `Transform.scale(0.85)` 는 Switch 의 **레이아웃 폭을
  /// 1dp 도 줄이지 않았다** — Transform 은 페인트만 스케일하므로 부모 Row 는 여전히
  /// 52dp 를 예약한다. 그래서 컴팩트해 보이기만 하고 이름 영역은 그대로 눌려 있었다.
  /// 이번에는 토글·설정·순서를 편집 모드로 빼서 **폭 자체를 회수**한다.
  Widget _buildPaymentMethodTile(
    BuildContext context,
    PaymentMethod method,
    CardSettlementSummary? settlement,
    int reorderIndex,
  ) {
    final bb = context.bb;

    int cardAmount(CardSettlementMonth? month) =>
        month?.cards
            .firstWhere(
              (c) => c.paymentMethodId == method.id,
              orElse: () => const CardSettlementCard(
                paymentMethodId: '',
                paymentMethodName: '',
                amount: 0,
                transactionCount: 0,
              ),
            )
            .amount ??
        0;

    EntityMetric? trailingMetric;
    final metrics = <EntityMetric>[];
    final badges = <EntityBadge>[];

    if (method.isCredit) {
      final closing =
          method.closingDay == 31 ? '말일' : '${method.closingDay ?? '-'}일';
      // 2026-08-18 사용자 요청 — 신용카드는 잔액이 없어 `trailingMetric` 슬롯이
      // 비어 있었고, 마감일·결제일이 `subtitle` 로 내려가 **3줄**이 됐다
      // (이름 / 마감·결제 / 전월·미결제·이번달 칩).
      // 비어 있는 잔액 자리로 끌어올려 **2줄**로 끝낸다. 계좌 타일은 그대로다.
      trailingMetric = EntityMetric(
        label: '마감·결제',
        value: '$closing · ${method.settlementDay ?? '-'}일',
      );
      if (settlement != null) {
        final unpaid = cardAmount(settlement.unpaidMonth);
        metrics.addAll([
          EntityMetric(
            label: '전월',
            value: '${CurrencyFormatter.format(cardAmount(settlement.previousMonth))}원',
          ),
          EntityMetric(
            label: '미결제',
            value: '${CurrencyFormatter.format(unpaid)}원',
            tone: unpaid > 0 ? EntityTone.expense : EntityTone.neutral,
          ),
          EntityMetric(
            label: '이번달',
            value: '${CurrencyFormatter.format(cardAmount(settlement.currentMonth))}원',
            tone: EntityTone.income,
          ),
        ]);
      }
    } else {
      final balance = method.balance ?? 0;
      trailingMetric = EntityMetric(
        label: '잔액',
        value: CurrencyFormatter.formatWithSign(balance),
        tone: balance >= 0 ? EntityTone.positive : EntityTone.negative,
      );
      if (method.isDefault) badges.add(const EntityBadge(label: '기본'));
    }

    return EntityTileRow(
      title: method.name,
      badges: badges,
      trailingMetric: trailingMetric,
      metrics: metrics,
      // 타입 텍스트 뱃지는 제거했다 — 아바타 아이콘이 이미 타입을 말하고 있어서
      // 40~50dp 를 중복으로 쓰고 있었다.
      leadingIcon: paymentMethodTypeIcon(method.type),
      leadingColor: bb.paymentType(method.type),
      dimmed: !method.isActive,
      // 사용자 요청: 자산 항목 클릭 시 해당 결제수단으로 필터된 거래 탭으로 이동
      onTap: () {
        final encodedName = Uri.encodeComponent(method.name);
        context.go(
          '/transactions?paymentMethodId=${method.id}&paymentMethodName=$encodedName',
        );
      },
      actions: EntityTileActions(
        isActive: method.isActive,
        onActiveChanged: (value) {
          context.read<PaymentMethodBloc>().add(
                UpdatePaymentMethod(id: method.id, isActive: value),
              );
        },
        menu: [
          // Phase 25 Step 4 — 잔액 수정 popup 항목 (비-카드만, tune IconButton 분리 금지)
          if (!method.isCredit)
            const EntityMenuAction(
                value: 'adjust_balance', label: '잔액 수정', icon: Icons.tune),
          const EntityMenuAction(
              value: 'edit', label: '수정', icon: Icons.edit_outlined),
          const EntityMenuAction(
            value: 'delete',
            label: '삭제',
            icon: Icons.delete_outline,
            destructive: true,
          ),
        ],
        onMenuSelected: (action) {
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
        reorderIndex: reorderIndex,
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
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error),
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
    // 사용자가 고른 색은 여기 한 곳에서만 보정한다 (guard S6):
    // 다크 배경에 묻지 않도록 HSL 명도만 클램프하고 색상·채도는 그대로 둔다.
    final color = context.bb.readable(UIHelpers.parseColor(pocket.color));
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
      child: EntityTileRow(
        title: pocket.name,
        leadingIcon: UIHelpers.resolveIcon(pocket.icon,
            fallback: Icons.account_balance_wallet),
        leadingColor: color,
        badges: [EntityBadge(label: typeLabel, color: color)],
        trailingMetric: EntityMetric(
          label: '잔액',
          value: '${CurrencyFormatter.format(pocket.balance)}원',
          tone: pocket.balance >= 0 ? EntityTone.positive : EntityTone.negative,
        ),
        metrics: [
          EntityMetric(
            label: '할당',
            value: '${CurrencyFormatter.format(pocket.allocatedAmount)}원',
          ),
        ],
        actions: EntityTileActions(
          menu: const [
            EntityMenuAction(
                value: 'edit', label: '수정', icon: Icons.edit_outlined),
            EntityMenuAction(
              value: 'delete',
              label: '삭제',
              icon: Icons.delete_outline,
              destructive: true,
            ),
          ],
          onMenuSelected: (action) {
            if (action == 'edit') {
              _showEditPocket(context, pocket);
            } else if (action == 'delete') {
              _showDeleteDialog(context, pocket);
            }
          },
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
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error),
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

/// 회차 12 follow-up Phase 2 (2026-05-04) — 자산 / 사용 금액 PageView 스와핑.
///
/// 결제수단 탭 (index 0) + credit card 보유 시: 2 page (자산 / 사용) PageView +
/// dot indicator. 좌우 스와이프 또는 dot 클릭으로 전환.
/// 그외 (다른 탭 또는 credit 미보유): 자산 1 page 만.
class _AssetPagerHeader extends StatefulWidget {
  const _AssetPagerHeader();

  @override
  State<_AssetPagerHeader> createState() => _AssetPagerHeaderState();
}

class _AssetPagerHeaderState extends State<_AssetPagerHeader> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabController = DefaultTabController.of(context);
    return ListenableBuilder(
      listenable: tabController,
      builder: (context, _) {
        return BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
          builder: (context, state) {
            final isPaymentTab = tabController.index == 0;
            final hasCredit = state is PaymentMethodLoaded &&
                state.paymentMethods.any((pm) => pm.isCredit && pm.isActive);
            final summary =
                state is PaymentMethodLoaded ? state.cardSettlementSummary : null;
            final showCardPage = isPaymentTab && hasCredit && summary != null;

            if (!showCardPage) {
              // 결제수단 탭 외 또는 credit 없음 → 자산 단일 표시 (PageView X).
              return const _AssetSummaryHeader();
            }

            // 2 page PageView. 동일 height (Padding + Row of 3 cards).
            return Column(
              children: [
                SizedBox(
                  height: 96,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) =>
                        setState(() => _currentPage = i),
                    children: [
                      const _AssetSummaryHeader(),
                      _CardSettlementCardsView(summary: summary),
                    ],
                  ),
                ),
                _PageDotIndicator(
                  count: 2,
                  current: _currentPage,
                  onDotTap: (i) {
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PageDotIndicator extends StatelessWidget {
  final int count;
  final int current;
  final ValueChanged<int> onDotTap;

  const _PageDotIndicator({
    required this.count,
    required this.current,
    required this.onDotTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == current;
          return GestureDetector(
            onTap: () => onDotTap(i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 회차 12 follow-up Phase 2 — _CardSettlementHeader cards 부분만 추출하여
/// _AssetPagerHeader 의 page 2 로 사용.
class _CardSettlementCardsView extends StatelessWidget {
  final CardSettlementSummary summary;

  const _CardSettlementCardsView({required this.summary});

  @override
  Widget build(BuildContext context) {
    final bb = context.bb;
    final theme = Theme.of(context);
    final unpaid = summary.unpaidMonth?.totalAmount ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: _SettlementCard(
              label: '전월 사용',
              amount: summary.previousMonth.totalAmount,
              count: summary.previousMonth.cards.length,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SettlementCard(
              label: '미결제',
              amount: unpaid,
              count: summary.unpaidMonth?.cards.length ?? 0,
              color: unpaid > 0 ? bb.expense.color : bb.positiveBalance,
              highlight: unpaid > 0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SettlementCard(
              label: '이번달 사용',
              amount: summary.currentMonth.totalAmount,
              count: summary.currentMonth.cards.length,
              color: bb.income.color,
            ),
          ),
        ],
      ),
    );
  }
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

        final bb = context.bb;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: '총자산',
                  value: asset,
                  color: bb.income.color,
                  icon: Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: '부채',
                  value: debt,
                  color: bb.expense.color,
                  icon: Icons.credit_card,
                  signed: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: '순자산',
                  value: net,
                  color: net >= 0 ? bb.positiveBalance : bb.negativeBalance,
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

// 회차 12 follow-up Phase 2 — 기존 _CardSettlementHeader 제거. 자산/사용 영역
// PageView 통합 후 cards 부분은 _CardSettlementCardsView 로 분리됨.

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
    final density = context.density;
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
          OneLineLabel(
            label,
            baseFontSize: density.headerLabelFontSize,
            minFontSize: 10,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          // 금액은 FittedBox 로 줄인다 — 카드 폭이 화면의 1/3 뿐이라 축소 하한을
          // 두면 잘릴 수 있고, 금액은 **잘리는 것보다 작아지는 쪽**이 맞다
          // (금액 축약·절단 금지).
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
                        theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final bool signed;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.signed = false,
  });

  @override
  Widget build(BuildContext context) {
    final density = context.density;
    final formatted = signed
        ? CurrencyFormatter.formatWithSign(value)
        : CurrencyFormatter.format(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        // 배경은 전경색의 옅은 틴트다. 색 자체가 라이트·다크 쌍으로 정의돼
        // 있으므로 두 모드 모두에서 대비가 유지된다.
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: OneLineLabel(
                  label,
                  baseFontSize: density.headerLabelFontSize,
                  minFontSize: 10,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatted,
              style: TextStyle(
                fontSize: density.headerValueFontSize,
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
