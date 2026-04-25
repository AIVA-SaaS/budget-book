import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_list_tile.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transfer_list_tile.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// Phase 25 Step 7 — 거래 탭 달력 뷰.
///
/// 일별 수입/지출 마커 표시. 일자 탭 시 바텀시트로 해당 일자의
/// 거래/이체 목록을 노출.
class TransactionCalendarView extends StatefulWidget {
  final int year;
  final int month;
  final List<Transaction> transactions;
  final List<Transfer> transfers;
  final void Function(Transaction)? onTransactionTap;
  final void Function(Transfer)? onTransferTap;

  const TransactionCalendarView({
    super.key,
    required this.year,
    required this.month,
    required this.transactions,
    required this.transfers,
    this.onTransactionTap,
    this.onTransferTap,
  });

  @override
  State<TransactionCalendarView> createState() =>
      _TransactionCalendarViewState();
}

class _TransactionCalendarViewState extends State<TransactionCalendarView> {
  late DateTime _focusedDay = DateTime(widget.year, widget.month, 1);

  /// 일자별 거래 그룹핑 (transactionDate 기준, "yyyy-MM-dd" 형식).
  Map<DateTime, _DaySummary> _groupByDay() {
    final map = <DateTime, _DaySummary>{};
    for (final tx in widget.transactions) {
      final key = _parseDateKey(tx.transactionDate);
      final entry = map.putIfAbsent(key, () => _DaySummary());
      if (tx.type == 'INCOME') {
        entry.income += tx.amount;
      } else if (tx.type == 'EXPENSE') {
        entry.expense += tx.amount;
      }
      entry.transactions.add(tx);
    }
    for (final tr in widget.transfers) {
      final key = _parseDateKey(tr.transferDate);
      final entry = map.putIfAbsent(key, () => _DaySummary());
      entry.transfers.add(tr);
    }
    return map;
  }

  static DateTime _parseDateKey(String yyyymmdd) {
    final parts = yyyymmdd.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = _groupByDay();
    final firstOfMonth = DateTime(widget.year, widget.month, 1);
    final lastOfMonth = DateTime(widget.year, widget.month + 1, 0);

    return SingleChildScrollView(
      child: Column(
        children: [
          TableCalendar<_DaySummary>(
            firstDay: firstOfMonth.subtract(const Duration(days: 365)),
            lastDay: lastOfMonth.add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            currentDay: DateTime.now(),
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            headerVisible: false,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            daysOfWeekHeight: 24,
            rowHeight: 64,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: true,
              cellMargin: const EdgeInsets.all(2),
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              defaultTextStyle: const TextStyle(fontSize: 13),
              weekendTextStyle: TextStyle(
                fontSize: 13,
                color: Colors.red.shade600,
              ),
              outsideTextStyle: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              final summary = byDay[key];
              return summary == null ? const [] : [summary];
            },
            calendarBuilders: CalendarBuilders<_DaySummary>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                final summary = events.first;
                return Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (summary.income > 0)
                        Text(
                          '+${CurrencyFormatter.format(summary.income)}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (summary.expense > 0)
                        Text(
                          '-${CurrencyFormatter.format(summary.expense)}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                );
              },
            ),
            onDaySelected: (selected, focused) {
              setState(() => _focusedDay = focused);
              final key = DateTime(selected.year, selected.month, selected.day);
              final summary = byDay[key];
              _showDayBottomSheet(context, selected, summary);
            },
          ),
        ],
      ),
    );
  }

  void _showDayBottomSheet(
    BuildContext context,
    DateTime day,
    _DaySummary? summary,
  ) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('M월 d일 (E)', 'ko_KR').format(day);
    final hasItems = summary != null &&
        (summary.transactions.isNotEmpty || summary.transfers.isNotEmpty);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        dateLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (summary != null && summary.income > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '+${CurrencyFormatter.format(summary.income)}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (summary != null && summary.expense > 0)
                        Text(
                          '-${CurrencyFormatter.format(summary.expense)}',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: !hasItems
                      ? Center(
                          child: Text(
                            '거래 없음',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            ...summary.transactions.map((tx) =>
                                TransactionListTile(
                                  transaction: tx,
                                  onTap: widget.onTransactionTap == null
                                      ? null
                                      : () {
                                          Navigator.of(ctx).pop();
                                          widget.onTransactionTap!(tx);
                                        },
                                )),
                            ...summary.transfers.map((tr) => TransferListTile(
                                  transfer: tr,
                                  onTap: widget.onTransferTap == null
                                      ? null
                                      : () {
                                          Navigator.of(ctx).pop();
                                          widget.onTransferTap!(tr);
                                        },
                                )),
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

class _DaySummary {
  int income = 0;
  int expense = 0;
  final List<Transaction> transactions = [];
  final List<Transfer> transfers = [];
}
