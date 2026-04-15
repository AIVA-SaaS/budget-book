import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/home/domain/entities/dashboard_widget_config.dart';
import 'package:budget_book/features/home/data/home_config_service.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_list_tile.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/core/widgets/announcement_banner.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/utils/payment_method_helpers.dart';
import 'package:budget_book/core/widgets/account_balance_card.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_bloc.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_event.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_state.dart';
import 'package:budget_book/features/ai/presentation/bloc/ai_insight_bloc.dart';
import 'package:budget_book/features/ai/presentation/bloc/ai_insight_event.dart';
import 'package:budget_book/features/ai/presentation/bloc/ai_insight_state.dart';
import 'package:budget_book/features/home/presentation/widgets/monthly_trend_card.dart';
import 'package:budget_book/features/home/presentation/widgets/category_breakdown_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<DashboardWidgetConfig> _widgetConfigs = [];
  final _configService = HomeConfigService();

  @override
  void initState() {
    super.initState();
    _loadWidgetConfig();
  }

  Future<void> _loadWidgetConfig() async {
    final configs = await _configService.loadConfig();
    configs.sort((a, b) => a.order.compareTo(b.order));
    if (mounted) {
      setState(() => _widgetConfigs = configs);
    }
  }

  /// Returns merged settings for a widget (saved + defaults).
  Map<String, dynamic> _getWidgetSettings(String widgetId) {
    final config = _widgetConfigs.where((c) => c.id == widgetId).firstOrNull;
    if (config != null) {
      return _configService.getWidgetSettings(config);
    }
    return defaultWidgetSettings[widgetId] ?? {};
  }

  /// Builds the widget card matching [id] using the given dashboard [state].
  /// Returns null when the widget should be skipped (e.g. no data).
  Widget? _buildWidgetById(String id, DashboardLoaded state) {
    switch (id) {
      case 'monthly_summary':
        return _SummaryCard(state: state);
      case 'budget_usage':
        if (state.budgetSummary == null) return null;
        return _BudgetUsageCard(budgetSummary: state.budgetSummary!);
      case 'recent_transactions':
        return _RecentTransactionsCard(
          transactions: state.recentTransactions,
          error: state.transactionsError,
          year: state.year,
          month: state.month,
        );
      case 'payment_breakdown':
        return _PaymentMethodStatsCard(
          stats: state.paymentMethodStats,
          year: state.year,
          month: state.month,
        );
      case 'asset_balance':
        return const AccountBalanceCard();
      case 'private_summary':
        final privateTransactions = state.recentTransactions
            .where((t) => t.visibility == 'PRIVATE')
            .toList();
        if (privateTransactions.isEmpty) return null;
        return _PrivateSummaryCard(transactions: privateTransactions);
      case 'spending_plans':
        return const _SpendingPlansPreviewCard();
      case 'ai_insights':
        return _AiInsightPreviewCard(year: state.year, month: state.month);
      case 'monthly_trend':
        return MonthlyTrendCard(
          trends: state.monthlyTrends,
          settings: _getWidgetSettings('monthly_trend'),
        );
      case 'category_breakdown':
        return CategoryBreakdownCard(
          categoryStats: state.categoryStats,
          settings: _getWidgetSettings('category_breakdown'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transactions/create'),
        tooltip: '거래 추가',
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: const Text('Budget Book'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings/partner'),
            icon: const Icon(Icons.people),
            tooltip: '파트너 관리',
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading || state is DashboardInitial) {
            return const SkeletonLoader(itemCount: 5);
          }

          if (state is DashboardError) {
            return AppErrorWidget(
              message: state.message,
              onRetry: () {
                final now = DateTime.now();
                context.read<DashboardBloc>().add(
                      LoadDashboard(year: now.year, month: now.month),
                    );
              },
            );
          }

          if (state is DashboardLoaded) {
            // Build configurable widget list based on saved order/visibility
            final enabledWidgets = <Widget>[];
            for (final config
                in _widgetConfigs.where((c) => c.enabled)) {
              final widget = _buildWidgetById(config.id, state);
              if (widget != null) {
                if (enabledWidgets.isNotEmpty) {
                  enabledWidgets.add(const SizedBox(height: 16));
                }
                enabledWidgets.add(widget);
              }
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<DashboardBloc>().add(
                      LoadDashboard(year: state.year, month: state.month),
                    );
                // Reload widget config in case user changed it
                await _loadWidgetConfig();
              },
              child: ListView(
                key: const PageStorageKey('dashboard_list'),
                padding: const EdgeInsets.all(16),
                children: [
                  // Fixed elements (not configurable)
                  const AnnouncementBanner(),
                  _MonthHeader(year: state.year, month: state.month),
                  const SizedBox(height: 16),
                  const _QuickActions(),
                  const SizedBox(height: 16),
                  // Dynamic configurable widgets
                  ...enabledWidgets,
                  const SizedBox(height: 88),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final int year;
  final int month;

  const _MonthHeader({required this.year, required this.month});

  void _goToPreviousMonth(BuildContext context) {
    int newYear = year;
    int newMonth = month - 1;
    if (newMonth < 1) {
      newMonth = 12;
      newYear -= 1;
    }
    context.read<DashboardBloc>().add(
          LoadDashboard(year: newYear, month: newMonth),
        );
  }

  void _goToNextMonth(BuildContext context) {
    int newYear = year;
    int newMonth = month + 1;
    if (newMonth > 12) {
      newMonth = 1;
      newYear += 1;
    }
    context.read<DashboardBloc>().add(
          LoadDashboard(year: newYear, month: newMonth),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _goToPreviousMonth(context),
          tooltip: '이전 달',
        ),
        Text(
          '$year년 $month월',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _goToNextMonth(context),
          tooltip: '다음 달',
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickActionButton(
          icon: Icons.arrow_downward,
          label: '지출',
          color: Colors.red,
          onTap: () => context.push('/transactions/create'),
        ),
        _QuickActionButton(
          icon: Icons.arrow_upward,
          label: '수입',
          color: Colors.blue,
          onTap: () => context.push('/transactions/create?tab=income'),
        ),
        _QuickActionButton(
          icon: Icons.swap_horiz,
          label: '이체',
          color: Colors.teal,
          onTap: () => context.push('/transactions/create?tab=transfer'),
        ),
        _QuickActionButton(
          icon: Icons.event_note,
          label: '계획',
          color: Colors.purple,
          onTap: () => context.push('/spending-plans'),
        ),
        _QuickActionButton(
          icon: Icons.settings,
          label: '설정',
          color: Colors.grey,
          onTap: () {
            // Navigate to settings tab (index 4)
            final shell = StatefulNavigationShell.maybeOf(context);
            if (shell != null) {
              shell.goBranch(4);
            } else {
              context.go('/settings');
            }
          },
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DashboardLoaded state;

  const _SummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    final formatter = NumberFormat('#,###');

    if (state.summaryError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('요약 정보를 불러올 수 없습니다: ${state.summaryError}'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이번 달 요약',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: '수입',
                    amount: summary?.totalIncome ?? 0,
                    color: Colors.blue,
                    formatter: formatter,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '지출',
                    amount: summary?.totalExpense ?? 0,
                    color: Colors.red,
                    formatter: formatter,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '잔액',
                    amount: summary?.balance ?? 0,
                    color: (summary?.balance ?? 0) >= 0
                        ? Colors.green
                        : Colors.red,
                    formatter: formatter,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final NumberFormat formatter;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatter.format(amount)}원',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _BudgetUsageCard extends StatefulWidget {
  final BudgetSummary budgetSummary;

  const _BudgetUsageCard({required this.budgetSummary});

  @override
  State<_BudgetUsageCard> createState() => _BudgetUsageCardState();
}

class _BudgetUsageCardState extends State<_BudgetUsageCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final summary = widget.budgetSummary;
    final usageRate = summary.usageRate;
    final isOver = summary.isOverBudget;
    final progressColor = isOver
        ? Colors.red
        : usageRate > 80
            ? Colors.orange
            : Colors.green;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '예산 사용 현황',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${usageRate.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: progressColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (usageRate / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  color: progressColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '사용: ${formatter.format(summary.totalSpent)}원',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '예산: ${formatter.format(summary.totalBudget)}원',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (isOver)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '예산을 ${formatter.format(summary.totalSpent - summary.totalBudget)}원 초과했습니다',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              // Expanded: per-item breakdown
              if (_expanded && summary.items.isNotEmpty) ...[
                const Divider(height: 24),
                ...summary.items.map((item) {
                  final itemRate = item.budgetAmount > 0
                      ? (item.spentAmount / item.budgetAmount * 100).clamp(0.0, 999.0)
                      : 0.0;
                  final itemColor = itemRate > 100
                      ? Colors.red
                      : itemRate > 80
                          ? Colors.orange
                          : Colors.green;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.category?.displayName ?? item.groupName ?? '전체',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              '${formatter.format(item.spentAmount)} / ${formatter.format(item.budgetAmount)}원',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (itemRate / 100).clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            color: itemColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  final List<Transaction> transactions;
  final String? error;
  final int year;
  final int month;

  const _RecentTransactionsCard({
    required this.transactions,
    this.error,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 거래',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    final shell = StatefulNavigationShell.maybeOf(context);
                    if (shell != null) {
                      shell.goBranch(1);
                    } else {
                      context.go('/transactions?year=$year&month=$month');
                    }
                  },
                  child: const Text('더보기'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (error != null)
              Text('거래 내역을 불러올 수 없습니다: $error'),
            if (error == null && transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '이번 달 거래 내역이 없습니다',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ),
              ),
            if (error == null)
              ...transactions.map(
                (txn) => TransactionListTile(
                  transaction: txn,
                  onTap: () => context.push('/transactions/detail/${txn.id}?year=$year&month=$month'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// AccountBalanceCard is now in core/widgets/account_balance_card.dart

class _PaymentMethodStatsCard extends StatelessWidget {
  final List<PaymentMethodStatistics> stats;
  final int year;
  final int month;

  static const _colors = [
    Color(0xFF2196F3),
    Color(0xFFF44336),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFF795548),
  ];

  const _PaymentMethodStatsCard({
    required this.stats,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '결제수단별 지출',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    final shell = StatefulNavigationShell.maybeOf(context);
                    if (shell != null) {
                      shell.goBranch(3); // Statistics tab
                    }
                  },
                  child: const Text('더보기'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (stats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.credit_card_off,
                        size: 32,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '이번 달 거래 내역이 없습니다',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ...stats.asMap().entries.map((entry) {
              final index = entry.key;
              final stat = entry.value;
              final color = _colors[index % _colors.length];

              return InkWell(
                onTap: () => context.push(
                  '/transactions?year=$year&month=$month&paymentMethodId=${stat.paymentMethodId}&paymentMethodName=${Uri.encodeComponent(stat.paymentMethodName)}',
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (stat.paymentMethodType != null) ...[
                        Icon(
                          paymentMethodTypeIcon(stat.paymentMethodType!),
                          size: 16,
                          color: paymentMethodTypeColor(stat.paymentMethodType!),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stat.paymentMethodName,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            Text(
                              '${stat.transactionCount}건',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${CurrencyFormatter.format(stat.totalAmount)}원',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${stat.percentage.toStringAsFixed(0)}%',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Dashboard card showing spending plan and wishlist preview with actual data.
class _SpendingPlansPreviewCard extends StatefulWidget {
  const _SpendingPlansPreviewCard();

  @override
  State<_SpendingPlansPreviewCard> createState() =>
      _SpendingPlansPreviewCardState();
}

class _SpendingPlansPreviewCardState extends State<_SpendingPlansPreviewCard> {
  @override
  void initState() {
    super.initState();
    final bloc = getIt<SpendingPlanBloc>();
    if (bloc.state is! SpendingPlanLoaded) {
      final now = DateTime.now();
      bloc.add(LoadSpendingPlans(
        startDate:
            DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10),
        endDate: DateTime(now.year, now.month + 1, 0)
            .toIso8601String()
            .substring(0, 10),
      ));
      bloc.add(const LoadWishlist());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');

    return BlocBuilder<SpendingPlanBloc, SpendingPlanState>(
      bloc: getIt<SpendingPlanBloc>(),
      builder: (context, state) {
        if (state is! SpendingPlanLoaded) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final planned = state.plans
            .where((p) => p.status == 'PLANNED')
            .take(3)
            .toList();
        final wishlist = (state.wishlist ?? []).take(3).toList();

        if (planned.isEmpty && wishlist.isEmpty) {
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => GoRouter.of(context).push('/spending-plans'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.purple.withValues(alpha: 0.12),
                      child: const Icon(Icons.event_note,
                          color: Colors.purple),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '지출 계획',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '지출 계획을 추가하세요',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title + "더보기" link
                Row(
                  children: [
                    const Icon(Icons.event_note, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '지출 계획',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          GoRouter.of(context).push('/spending-plans'),
                      child: const Text('더보기'),
                    ),
                  ],
                ),
                // Planned section (if any)
                if (planned.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      '계획됨',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...planned.map((p) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name, overflow: TextOverflow.ellipsis),
                        subtitle: Text(p.targetDate ?? ''),
                        trailing: Text(
                          '${numberFormat.format(p.amount)}원',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )),
                ],
                // Wishlist section (if any)
                if (wishlist.isNotEmpty) ...[
                  if (planned.isNotEmpty) const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      '구매 목록',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...wishlist.map((w) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(w.name, overflow: TextOverflow.ellipsis),
                        trailing: Text(
                          w.priceRangeText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PrivateSummaryCard extends StatelessWidget {
  final List<Transaction> transactions;

  const _PrivateSummaryCard({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');
    final totalExpense = transactions
        .where((t) => t.type == 'EXPENSE')
        .fold<int>(0, (sum, t) => sum + t.amount);
    final totalIncome = transactions
        .where((t) => t.type == 'INCOME')
        .fold<int>(0, (sum, t) => sum + t.amount);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '개인 거래 요약',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${transactions.length}건',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (totalIncome > 0)
              _buildRow(context, '수입', '${numberFormat.format(totalIncome)}원', Colors.blue),
            if (totalExpense > 0)
              _buildRow(context, '지출', '${numberFormat.format(totalExpense)}원', Colors.red),
            if (transactions.length <= 3) ...[
              const Divider(height: 16),
              ...transactions.map((t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.description,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${t.type == 'EXPENSE' ? '-' : '+'}${numberFormat.format(t.amount)}원',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: t.type == 'EXPENSE' ? Colors.red : Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AiInsightPreviewCard extends StatefulWidget {
  final int year;
  final int month;

  const _AiInsightPreviewCard({required this.year, required this.month});

  @override
  State<_AiInsightPreviewCard> createState() => _AiInsightPreviewCardState();
}

class _AiInsightPreviewCardState extends State<_AiInsightPreviewCard> {
  @override
  void initState() {
    super.initState();
    final bloc = getIt<AiInsightBloc>();
    if (bloc.state is AiInsightInitial) {
      bloc.add(LoadInsights(year: widget.year, month: widget.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<AiInsightBloc, AiInsightState>(
      bloc: getIt<AiInsightBloc>(),
      builder: (context, state) {
        if (state is AiInsightLoaded && state.insights.isNotEmpty) {
          final insight = state.insights.first;
          final (icon, color) = _severityStyle(insight.severity);
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (insight.type == 'SPENDING_CHANGE' || insight.type == 'TIP') {
                  final categoryId = insight.data?['categoryId'];
                  final categoryName = insight.data?['categoryName'];
                  if (categoryId != null) {
                    context.go('/transactions?year=${widget.year}&month=${widget.month}&categoryId=$categoryId&categoryName=${Uri.encodeComponent(categoryName?.toString() ?? '')}');
                    return;
                  }
                } else if (insight.type == 'BUDGET_WARNING' || insight.type == 'BUDGET_ADJUST') {
                  final shell = StatefulNavigationShell.maybeOf(context);
                  if (shell != null) {
                    shell.goBranch(2);
                    return;
                  }
                }
                // PATTERN, POSITIVE, or fallback → no navigation
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'AI 인사이트',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (state.insights.length > 1)
                          Text(
                            '+${state.insights.length - 1}건',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insight.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                insight.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  (IconData, Color) _severityStyle(String severity) {
    return switch (severity) {
      'WARNING' => (Icons.warning_amber_rounded, Colors.orange),
      'POSITIVE' => (Icons.check_circle_outline, Colors.green),
      _ => (Icons.lightbulb_outline, Theme.of(context).colorScheme.primary),
    };
  }
}
