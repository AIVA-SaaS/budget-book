import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/icon_picker.dart';
import 'package:budget_book/core/widgets/color_picker.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_settlement.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_settlement_bloc.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_settlement_event.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_settlement_state.dart';

class WeeklySettlementPage extends StatefulWidget {
  const WeeklySettlementPage({super.key});

  @override
  State<WeeklySettlementPage> createState() => _WeeklySettlementPageState();
}

class _WeeklySettlementPageState extends State<WeeklySettlementPage> {
  late int _year;
  late int _month;
  final Map<int, Set<String>> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _onMonthChanged(({int year, int month}) value) {
    setState(() {
      _year = value.year;
      _month = value.month;
      _selectedItems.clear();
    });
    context
        .read<WeeklySettlementBloc>()
        .add(LoadSettlements(year: _year, month: _month));
  }

  void _toggleItem(int weekNumber, String budgetId) {
    setState(() {
      final weekSet = _selectedItems.putIfAbsent(weekNumber, () => {});
      if (weekSet.contains(budgetId)) {
        weekSet.remove(budgetId);
      } else {
        weekSet.add(budgetId);
      }
    });
  }

  void _selectAllPending(WeeklySettlementWeek week) {
    setState(() {
      final pendingIds = week.items
          .where((item) => !item.isSettled)
          .map((item) => item.budgetId)
          .toSet();
      _selectedItems[week.weekNumber] = pendingIds;
    });
  }

  void _settleSelected(int weekNumber) {
    final selected = _selectedItems[weekNumber];
    if (selected == null || selected.isEmpty) return;
    context.read<WeeklySettlementBloc>().add(SettleItems(
          budgetIds: selected.toList(),
          weekNumber: weekNumber,
          year: _year,
          month: _month,
        ));
    setState(() {
      _selectedItems.remove(weekNumber);
    });
  }

  void _unsettleItem(String budgetId, int weekNumber) {
    context.read<WeeklySettlementBloc>().add(UnsettleItems(
          budgetIds: [budgetId],
          weekNumber: weekNumber,
          year: _year,
          month: _month,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주간 정산'),
      ),
      body: Column(
        children: [
          MonthNavigator(
            year: _year,
            month: _month,
            onMonthChanged: _onMonthChanged,
          ),
          Expanded(
            child:
                BlocBuilder<WeeklySettlementBloc, WeeklySettlementState>(
              builder: (context, state) {
                return switch (state) {
                  SettlementInitial() ||
                  SettlementLoading() =>
                    const Center(child: CircularProgressIndicator()),
                  SettlementLoaded(overview: final overview) =>
                    _buildContent(context, overview),
                  SettlementError(message: final message) =>
                    AppErrorWidget(
                      message: message,
                      onRetry: () {
                        context.read<WeeklySettlementBloc>().add(
                            LoadSettlements(year: _year, month: _month));
                      },
                      showHomeButton: true,
                    ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WeeklySettlementOverview overview) {
    if (overview.weeks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                '정산 정보가 없습니다',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context
            .read<WeeklySettlementBloc>()
            .add(LoadSettlements(year: _year, month: _month));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: overview.weeks.length,
        itemBuilder: (context, index) {
          return _WeekSettlementCard(
            week: overview.weeks[index],
            selectedIds: _selectedItems[overview.weeks[index].weekNumber] ?? {},
            onToggleItem: _toggleItem,
            onSelectAllPending: _selectAllPending,
            onSettleSelected: _settleSelected,
            onUnsettleItem: _unsettleItem,
          );
        },
      ),
    );
  }
}

class _WeekSettlementCard extends StatefulWidget {
  final WeeklySettlementWeek week;
  final Set<String> selectedIds;
  final void Function(int weekNumber, String budgetId) onToggleItem;
  final void Function(WeeklySettlementWeek week) onSelectAllPending;
  final void Function(int weekNumber) onSettleSelected;
  final void Function(String budgetId, int weekNumber) onUnsettleItem;

  const _WeekSettlementCard({
    required this.week,
    required this.selectedIds,
    required this.onToggleItem,
    required this.onSelectAllPending,
    required this.onSettleSelected,
    required this.onUnsettleItem,
  });

  @override
  State<_WeekSettlementCard> createState() => _WeekSettlementCardState();
}

class _WeekSettlementCardState extends State<_WeekSettlementCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final week = widget.week;
    final hasPendingItems = week.items.any((item) => !item.isSettled);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    week.isFullySettled
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: week.isFullySettled
                        ? Colors.green
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${week.weekNumber}주차',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${week.weekStart} ~ ${week.weekEnd}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${CurrencyFormatter.format(week.totalSpent)}원',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1),
            ...week.items.map((item) {
              final isSelected =
                  widget.selectedIds.contains(item.budgetId);
              return _SettlementItemTile(
                item: item,
                isSelected: isSelected,
                onToggle: () =>
                    widget.onToggleItem(week.weekNumber, item.budgetId),
                onUnsettle: () =>
                    widget.onUnsettleItem(item.budgetId, week.weekNumber),
              );
            }),
            if (hasPendingItems)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            widget.onSelectAllPending(week),
                        child: const Text('전체 선택'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: widget.selectedIds.isNotEmpty
                            ? () => widget.onSettleSelected(week.weekNumber)
                            : null,
                        child: const Text('선택 정산'),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _SettlementItemTile extends StatelessWidget {
  final WeeklySettlementItem item;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onUnsettle;

  const _SettlementItemTile({
    required this.item,
    required this.isSelected,
    required this.onToggle,
    required this.onUnsettle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSettled = item.isSettled;

    return InkWell(
      onTap: isSettled ? null : onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Checkbox or settled indicator
            if (isSettled)
              const Icon(Icons.check_circle, color: Colors.green, size: 20)
            else
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            const SizedBox(width: 12),
            // Category icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: parseHexColor(item.categoryColor).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                resolveIcon(item.categoryIcon),
                size: 18,
                color: parseHexColor(item.categoryColor),
              ),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSettled
                          ? theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)
                          : null,
                      decoration:
                          isSettled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (isSettled && item.settledAt != null)
                    Text(
                      '정산일: ${item.settledAt}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ),
            // Amount
            Text(
              '${CurrencyFormatter.format(item.spentAmount)}원',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSettled
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                    : null,
              ),
            ),
            // Unsettle button for settled items
            if (isSettled) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.undo, size: 18),
                onPressed: onUnsettle,
                tooltip: '정산 취소',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
