import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_bloc.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_event.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_state.dart';
import 'package:budget_book/features/spending_plan/presentation/widgets/spending_plan_card.dart';
import 'package:budget_book/features/spending_plan/presentation/widgets/spending_plan_summary_card.dart';
import 'package:budget_book/features/spending_plan/presentation/widgets/assign_plan_dialog.dart';
import 'package:budget_book/features/spending_plan/presentation/widgets/complete_plan_dialog.dart';
import 'package:budget_book/features/spending_plan/presentation/widgets/link_transaction_sheet.dart';
import 'package:budget_book/core/widgets/filters/filter_chip_group.dart';

class SpendingPlanListPage extends StatefulWidget {
  const SpendingPlanListPage({super.key});

  @override
  State<SpendingPlanListPage> createState() => _SpendingPlanListPageState();
}

class _SpendingPlanListPageState extends State<SpendingPlanListPage>
    with SingleTickerProviderStateMixin {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  String? _statusFilter;
  late final TabController _tabController;

  static const _filterItems = <FilterChipItem>[
    FilterChipItem(value: null, label: '전체'),
    FilterChipItem(value: 'PLANNED', label: '계획됨'),
    FilterChipItem(value: 'COMPLETED', label: '완료'),
    FilterChipItem(value: 'SKIPPED', label: '건너뜀'),
    FilterChipItem(value: 'OVERDUE', label: '기한초과'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPlans();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      // Wishlist tab selected — load wishlist
      context.read<SpendingPlanBloc>().add(const LoadWishlist());
    }
  }

  void _loadPlans() {
    final startDate = DateFormat('yyyy-MM-dd')
        .format(DateTime(_year, _month, 1));
    final endDate = DateFormat('yyyy-MM-dd')
        .format(DateTime(_year, _month + 1, 0));
    context.read<SpendingPlanBloc>().add(LoadSpendingPlans(
          startDate: startDate,
          endDate: endDate,
          status: _statusFilter,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지출 계획'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '계획됨'),
            Tab(text: '구매 목록'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPlansTab(),
          _buildWishlistTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 1) {
            context.push('/spending-plans/create?wishlist=true');
          } else {
            context.push('/spending-plans/create');
          }
        },
        tooltip: _tabController.index == 1 ? '구매 목록 추가' : '계획 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---------- Tab 0: Plans ----------

  Widget _buildPlansTab() {
    return Column(
      children: [
        // Month navigator
        MonthNavigator(
          year: _year,
          month: _month,
          onMonthChanged: (val) {
            setState(() {
              _year = val.year;
              _month = val.month;
            });
            // MonthCubit 동기화 (다른 페이지와 양방향 sync)
            context.read<MonthCubit>().changeMonth(val.year, val.month);
            _loadPlans();
          },
        ),
        // Filter chips
        _buildFilterChips(),
        // Content
        Expanded(
          child: BlocConsumer<SpendingPlanBloc, SpendingPlanState>(
            listener: _onStateChange,
            builder: (context, state) {
              return switch (state) {
                SpendingPlanInitial() || SpendingPlanLoading() =>
                  const SkeletonLoader(itemCount: 5),
                SpendingPlanLoaded() => _buildLoaded(context, state),
                SpendingPlanError() => _buildError(context),
              };
            },
          ),
        ),
      ],
    );
  }

  void _onStateChange(BuildContext context, SpendingPlanState state) {
    if (state is SpendingPlanError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else if (state is SpendingPlanLoaded && state.operationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.operationError!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else if (state is SpendingPlanLoaded &&
        state.operationSuccess != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.operationSuccess!)),
      );
    }
  }

  Widget _buildFilterChips() {
    return FilterChipGroup(
      items: _filterItems,
      selectedValue: _statusFilter,
      onSelected: (value) {
        setState(() => _statusFilter = value);
        _loadPlans();
      },
    );
  }

  Widget _buildLoaded(BuildContext context, SpendingPlanLoaded state) {
    return Column(
      children: [
        // Summary card
        SpendingPlanSummaryCard(summary: state.summary),
        const Divider(height: 1),
        // Timeline grouped by date
        Expanded(
          child: state.plans.isEmpty
              ? _buildEmpty(context)
              : _buildTimeline(context, state),
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context, SpendingPlanLoaded state) {
    final grouped = state.groupedByDate;
    final dates = grouped.keys.toList();

    return ListView.builder(
      key: const PageStorageKey('spending_plan_list'),
      itemCount: dates.length + 1,
      itemBuilder: (context, index) {
        if (index == dates.length) return const SizedBox(height: 88);
        final dateStr = dates[index];
        final plans = grouped[dateStr]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(dateStr: dateStr),
            ...plans.map((plan) => SpendingPlanCard(
                  plan: plan,
                  onTap: () =>
                      context.push('/spending-plans/edit/${plan.id}'),
                  onComplete: () => _showCompleteDialog(context, plan),
                  onSkip: () => _confirmSkip(context, plan),
                  onDelete: () => _confirmDelete(context, plan),
                  onLinkTransaction: () => _showLinkTransaction(context, plan),
                  onUnlinkTransaction: () => _confirmUnlink(context, plan),
                )),
          ],
        );
      },
    );
  }

  void _showCompleteDialog(BuildContext context, SpendingPlan plan) async {
    final result = await showCompletePlanDialog(context, plan);
    if (result == null || !context.mounted) return;

    context.read<SpendingPlanBloc>().add(CompleteWithTransaction(
      planId: plan.id,
      amount: result.actualAmount,
      transactionDate: result.transactionDate,
      description: result.description,
      categoryId: result.categoryId,
      paymentMethodId: result.paymentMethodId,
      linkedTransactionId: result.linkedTransactionId,
    ));
  }

  void _confirmSkip(BuildContext context, SpendingPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계획 건너뛰기'),
        content: Text('\'${plan.name}\'을(를) 건너뛰시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<SpendingPlanBloc>().add(SkipPlan(plan.id));
            },
            child: const Text('건너뛰기'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SpendingPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계획 삭제'),
        content: Text('\'${plan.name}\'을(를) 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context
                  .read<SpendingPlanBloc>()
                  .add(DeleteSpendingPlan(plan.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showLinkTransaction(BuildContext context, SpendingPlan plan) async {
    final tx = await showLinkTransactionSheet(context: context, plan: plan);
    if (tx == null || !context.mounted) return;

    context.read<SpendingPlanBloc>().add(LinkTransaction(
          planId: plan.id,
          transactionId: tx.id,
        ));
  }

  void _confirmUnlink(BuildContext context, SpendingPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거래 연결 해제'),
        content: Text('\'${plan.name}\'의 거래 연결을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context
                  .read<SpendingPlanBloc>()
                  .add(UnlinkTransaction(planId: plan.id));
            },
            child: const Text('해제'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.event_note_outlined,
      title: '등록된 계획이 없습니다',
      subtitle: '지출 계획을 등록하고 예산 사용을 관리하세요',
      actionLabel: '계획 추가',
      onAction: () => context.push('/spending-plans/create'),
    );
  }

  Widget _buildError(BuildContext context) {
    return AppErrorWidget(
      message: '지출 계획을 불러오지 못했습니다',
      onRetry: _loadPlans,
      showHomeButton: true,
    );
  }

  // ---------- Tab 1: Wishlist ----------

  Widget _buildWishlistTab() {
    return BlocBuilder<SpendingPlanBloc, SpendingPlanState>(
      builder: (context, state) {
        if (state is SpendingPlanLoaded) {
          final wishlist = state.wishlist;
          if (wishlist == null) {
            // Not yet loaded
            return const Center(child: CircularProgressIndicator());
          }
          if (wishlist.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.shopping_cart_outlined,
              title: '구매 목록이 비어있습니다',
              subtitle: '사고 싶은 것을 구매 목록에 추가해보세요',
              actionLabel: '구매 목록 추가',
              onAction: () => context.push('/spending-plans/create?wishlist=true'),
            );
          }
          return _buildWishlistGrouped(context, state);
        }
        return const SkeletonLoader(itemCount: 3);
      },
    );
  }

  Widget _buildWishlistGrouped(BuildContext context, SpendingPlanLoaded state) {
    final grouped = state.wishlistByPriority;
    final priorities = grouped.keys.toList();

    return ListView.builder(
      key: const PageStorageKey('wishlist_list'),
      itemCount: priorities.length + 1,
      itemBuilder: (context, index) {
        if (index == priorities.length) return const SizedBox(height: 88);
        final priority = priorities[index];
        final items = grouped[priority]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PriorityHeader(priority: priority),
            ...items.map((plan) => _WishlistItemCard(
                  plan: plan,
                  onTap: () => context.push('/spending-plans/edit/${plan.id}'),
                  onAssign: () => _showAssignDialog(context, plan),
                  onSkip: () => _confirmSkip(context, plan),
                )),
          ],
        );
      },
    );
  }

  void _showAssignDialog(BuildContext context, SpendingPlan plan) async {
    final result = await showAssignPlanDialog(context, plan);
    if (result == null || !context.mounted) return;

    context.read<SpendingPlanBloc>().add(AssignPlan(
          planId: plan.id,
          targetDate: result.targetDate,
          weekNumber: result.weekNumber,
          budgetId: result.budgetId,
        ));
  }
}

// ---------- Helper widgets ----------

class _DateHeader extends StatelessWidget {
  final String dateStr;

  const _DateHeader({required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(dateStr);
    String displayText;
    if (date != null) {
      final weekday = DateFormat.E('ko').format(date);
      displayText =
          '${date.month}월 ${date.day}일 ($weekday)';
    } else {
      displayText = dateStr;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.calendar_today,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Text(
            displayText,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityHeader extends StatelessWidget {
  final String priority;

  const _PriorityHeader({required this.priority});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = priorityColor(priority);
    final label = priorityLabel(priority);

    String emoji;
    switch (priority) {
      case 'HIGH':
        emoji = '\u{1F534}'; // red circle
        break;
      case 'MEDIUM':
        emoji = '\u{1F7E1}'; // yellow circle
        break;
      case 'LOW':
        emoji = '\u{1F535}'; // blue circle
        break;
      default:
        emoji = '';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.08),
      child: Text(
        '$emoji $label',
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _WishlistItemCard extends StatelessWidget {
  final SpendingPlan plan;
  final VoidCallback? onTap;
  final VoidCallback? onAssign;
  final VoidCallback? onSkip;

  const _WishlistItemCard({
    required this.plan,
    this.onTap,
    this.onAssign,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pColor = priorityColor(plan.priority);

    return Dismissible(
      key: Key('wishlist_${plan.id}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.blue,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, color: Colors.white),
            SizedBox(width: 4),
            Text('배정', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.grey,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('건너뛰기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            SizedBox(width: 4),
            Icon(Icons.skip_next, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onAssign?.call();
        } else {
          onSkip?.call();
        }
        return false;
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: pColor.withValues(alpha: 0.15),
          child: Icon(Icons.shopping_cart, color: pColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                plan.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (plan.categoryName != null)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  plan.categoryName!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: plan.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  )).toList(),
                ),
              ),
          ],
        ),
        trailing: Text(
          plan.priceRangeText,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: pColor,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
