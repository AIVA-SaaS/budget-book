import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_list_tile.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transfer_list_tile.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// Phase 23 PR-X5: Month-view calendar for the 거래 탭 달력 뷰.
///
/// Each day cell shows compressed income (green) and expense (red) totals
/// aggregated from the already-loaded transactions. Tapping a day opens a
/// bottom sheet with that day's transactions + transfers, reusing the
/// same list tiles as the list view.
class TransactionCalendarView extends StatefulWidget {
  final int year;
  final int month;
  final List<Transaction> transactions;
  final List<Transfer> transfers;
  final void Function(DateTime focused) onMonthChanged;

  const TransactionCalendarView({
    super.key,
    required this.year,
    required this.month,
    required this.transactions,
    required this.transfers,
    required this.onMonthChanged,
  });

  @override
  State<TransactionCalendarView> createState() =>
      _TransactionCalendarViewState();
}

class _TransactionCalendarViewState extends State<TransactionCalendarView> {
  DateTime? _selectedDay;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime(widget.year, widget.month, 1);
  }

  @override
  void didUpdateWidget(covariant TransactionCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.month != widget.month) {
      _focusedDay = DateTime(widget.year, widget.month, 1);
      _selectedDay = null;
    }
  }

  /// Aggregates income / expense totals per day-of-month for the currently
  /// loaded transactions. Transfers are intentionally omitted from the
  /// income/expense markers but surfaced in the day bottom sheet.
  Map<int, _DayTotals> _buildDayTotals() {
    final result = <int, _DayTotals>{};
    for (final t in widget.transactions) {
      final date = DateTime.tryParse(t.transactionDate);
      if (date == null) continue;
      if (date.year != widget.year || date.month != widget.month) continue;
      final slot = result.putIfAbsent(date.day, () => _DayTotals());
      if (t.isIncome) {
        slot.income += t.amount;
      } else if (t.isExpense) {
        slot.expense += t.amount;
      }
    }
    return result;
  }

  void _showDaySheet(BuildContext context, DateTime day) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final txs = widget.transactions
        .where((t) => t.transactionDate == dateStr)
        .toList();
    final tfs =
        widget.transfers.where((t) => t.transferDate == dateStr).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          DateFormat('M월 d일 (E)', 'ko').format(day),
                          style: Theme.of(ctx)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push('/transactions/create?date=$dateStr');
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('추가'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: (txs.isEmpty && tfs.isEmpty)
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                '기록된 거래가 없습니다',
                                style: TextStyle(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          )
                        : ListView(
                            controller: controller,
                            children: [
                              ...txs.map(
                                (t) => TransactionListTile(
                                  transaction: t,
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    context.push(
                                      '/transactions/detail/${t.id}',
                                    );
                                  },
                                ),
                              ),
                              ...tfs.map(
                                (t) => TransferListTile(
                                  transfer: t,
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    context
                                        .push('/transfers/edit/${t.id}');
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayTotals = _buildDayTotals();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 88),
      child: Column(
        children: [
          TableCalendar<void>(
            firstDay: DateTime(2000, 1, 1),
            lastDay: DateTime(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                _selectedDay != null && isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _showDaySheet(context, selected);
            },
            onPageChanged: (focused) {
              _focusedDay = focused;
              widget.onMonthChanged(focused);
            },
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              cellMargin: const EdgeInsets.all(2),
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) =>
                  _buildCell(context, day, dayTotals[day.day], isToday: false),
              todayBuilder: (context, day, _) =>
                  _buildCell(context, day, dayTotals[day.day], isToday: true),
              selectedBuilder: (context, day, _) => _buildCell(
                context,
                day,
                dayTotals[day.day],
                isSelected: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    DateTime day,
    _DayTotals? totals, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    final inMonth =
        day.year == widget.year && day.month == widget.month;
    final dayColor = isSelected
        ? theme.colorScheme.onPrimary
        : (!inMonth
            ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
            : theme.colorScheme.onSurface);

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: isSelected
          ? BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            )
          : (isToday
              ? BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                )
              : null),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dayColor,
            ),
          ),
          if (totals != null) ...[
            if (totals.income > 0)
              Text(
                '+${_compact(totals.income)}',
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            if (totals.expense > 0)
              Text(
                '-${_compact(totals.expense)}',
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ],
      ),
    );
  }

  String _compact(int amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(0)}천만';
    if (amount >= 10000) return '${(amount / 10000).toStringAsFixed(0)}만';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}천';
    return CurrencyFormatter.format(amount);
  }
}

class _DayTotals {
  int income = 0;
  int expense = 0;
}
