import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/current_week_summary.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_bloc.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_event.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_state.dart';
import 'package:budget_book/features/weekly_budget/presentation/widgets/week_summary_card.dart';
import 'package:budget_book/core/widgets/error_widget.dart';

class WeeklyBudgetPage extends StatelessWidget {
  const WeeklyBudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주간 예산'),
      ),
      body: BlocBuilder<WeeklyBudgetBloc, WeeklyBudgetState>(
        builder: (context, state) {
          return switch (state) {
            WeeklyBudgetInitial() ||
            WeeklyBudgetLoading() =>
              const Center(child: CircularProgressIndicator()),
            WeeklyBudgetLoaded() =>
              _buildContent(context, state),
            WeeklyBudgetError(message: final message) =>
              _buildError(context, message),
          };
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, WeeklyBudgetLoaded state) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        final now = DateTime.now();
        context.read<WeeklyBudgetBloc>()
          ..add(LoadWeeklyOverview(year: now.year, month: now.month))
          ..add(const LoadCurrentWeek());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current week hero card
          if (state.currentWeek != null) ...[
            _buildCurrentWeekHero(context, state.currentWeek!),
            const SizedBox(height: 24),
          ],
          // Weekly overview timeline
          if (state.overview != null) ...[
            Text(
              '${state.overview!.yearMonth} 주간 예산',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...state.overview!.weeks.map((week) {
              final isCurrent = state.currentWeek != null &&
                  week.weekNumber == state.currentWeek!.weekNumber;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child:
                    WeekSummaryCard(weekSummary: week, isCurrentWeek: isCurrent),
              );
            }),
          ],
          if (state.overview == null && state.currentWeek == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '주간 예산 정보가 없습니다',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeekHero(
      BuildContext context, CurrentWeekSummary currentWeek) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat('#,###');

    return Card(
      elevation: 4,
      color: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  '이번 주 (${currentWeek.weekNumber}주차)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${currentWeek.weekStart} ~ ${currentWeek.weekEnd}',
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
            if (currentWeek.groups.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...currentWeek.groups.map((group) {
                final progress = (group.usageRate / 100).clamp(0.0, 1.0);
                final statusColor = group.usageRate > 100
                    ? Colors.red
                    : group.usageRate > 80
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
                            group.groupName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            '${numberFormat.format(group.spentAmount)}원 / ${numberFormat.format(group.budgetAmount)}원',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.15),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(statusColor),
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
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return AppErrorWidget(
      message: message,
      onRetry: () {
        final now = DateTime.now();
        context.read<WeeklyBudgetBloc>()
          ..add(LoadWeeklyOverview(year: now.year, month: now.month))
          ..add(const LoadCurrentWeek());
      },
      showHomeButton: true,
    );
  }
}
