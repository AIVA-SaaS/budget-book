import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:budget_book/core/reconciliation/reconciliation_scope.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_list_tile.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transfer_list_tile.dart';
import 'package:budget_book/core/widgets/reconciled_badge.dart';
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

  /// 일자 시트에서 **그 날짜로 거래 추가** 진입. 인자는 선택된 일자.
  ///
  /// URL 조립을 여기서 하지 않는 이유: 거래 추가 URL 은 상위 페이지의
  /// `_buildCreateTransactionUrl` 단일 소스가 만든다(필터된 결제수단 전파가 그 헬퍼에
  /// 걸려 있어, 위젯이 직접 push 하면 필터 propagation 이 끊긴다 — 목록 모드의
  /// `_DateHeader.onAddTap` 과 같은 규약).
  final void Function(DateTime)? onAddTap;

  const TransactionCalendarView({
    super.key,
    required this.year,
    required this.month,
    required this.transactions,
    required this.transfers,
    this.onTransactionTap,
    this.onTransferTap,
    this.onAddTap,
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
      entry.transferTotal += tr.amount;
    }
    return map;
  }

  /// 부모(list page)가 새 year/month 를 전달하면 달력 본문을 해당 월로 재동기화.
  /// State 는 위젯 재빌드 시 재사용되므로 didUpdateWidget 없이는 _focusedDay 가
  /// 최초 월에 고정되어, 월 이동(MonthNavigator/MonthCubit) 후에도 달력이 옛 월을
  /// 계속 렌더하는 drift 가 발생한다.
  @override
  void didUpdateWidget(covariant TransactionCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.month != widget.month) {
      _focusedDay = DateTime(widget.year, widget.month, 1);
    }
  }

  static DateTime _parseDateKey(String yyyymmdd) {
    final parts = yyyymmdd.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// 셀 1칸: 날짜 숫자(상단) + 수입/지출/이체 금액(하단)을 한 Column 에 세로로 쌓는다.
  /// 기존 markerBuilder 오버레이 방식은 중앙 정렬된 날짜 숫자와 금액이 겹쳐(날짜 침범)
  /// 3줄(수입/지출/이체) 표시 시 레이아웃이 깨졌다. 셀 전체를 직접 그려 겹침을 제거.
  Widget _dayCell(
    DateTime day,
    _DaySummary? summary,
    ThemeData theme, {
    bool isToday = false,
    bool isOutside = false,
  }) {
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final Color numberColor = isOutside
        ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
        : isToday
            ? theme.colorScheme.primary
            : isWeekend
                ? Colors.red.shade600
                : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // V65 — 그 날 항목이 모두 정산됐으면 날짜 옆에 점 하나.
          // 금액 3줄 레이아웃(PR #271/#272) 을 침범하지 않도록 날짜 Row 안에만 그린다.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 18,
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    color: numberColor,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (!isOutside && summary != null && summary.isFullyReconciled)
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: ReconciledBadge(compact: true),
                ),
            ],
          ),
          // 인접월 날짜(isOutside)에는 금액을 그리지 않는다(해당 월 데이터만 매핑됨).
          if (!isOutside && summary != null) ...[
            const SizedBox(height: 1),
            if (summary.income > 0)
              _amountLine('+', summary.income, Colors.blue.shade700),
            if (summary.expense > 0)
              _amountLine('-', summary.expense, Colors.red.shade700),
            if (summary.transfers.isNotEmpty)
              _amountLine('⇄', summary.transferTotal, Colors.grey.shade600),
          ],
        ],
      ),
    );
  }

  Widget _amountLine(String prefix, int amount, Color color) {
    // 전체 금액(쉼표 포맷)을 그대로 노출하되, 좁은 셀 폭을 넘으면 잘림(ellipsis) 대신
    // FittedBox 로 글자를 축소해 정확한 숫자를 항상 읽을 수 있게 한다.
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          '$prefix${CurrencyFormatter.format(amount)}',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 9,
            height: 1.2,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
            // 월 이동은 MonthNavigator(MonthCubit) 단일 소스로 일원화. 달력 자체 가로
            // 스와이프를 허용하면 페이지 월과 MonthCubit/데이터 월이 어긋나 drift 가
            // 재발하므로 스와이프 제스처를 비활성화한다.
            availableGestures: AvailableGestures.none,
            headerVisible: false,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            daysOfWeekHeight: 24,
            // 날짜(18) + 수입/지출/이체 3줄(각 ~11) + 여백을 겹침 없이 담기 위한 높이.
            rowHeight: 74,
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: true,
              cellMargin: EdgeInsets.all(1),
            ),
            calendarBuilders: CalendarBuilders<_DaySummary>(
              defaultBuilder: (context, day, _) => _dayCell(
                day,
                byDay[DateTime(day.year, day.month, day.day)],
                theme,
              ),
              todayBuilder: (context, day, _) => _dayCell(
                day,
                byDay[DateTime(day.year, day.month, day.day)],
                theme,
                isToday: true,
              ),
              outsideBuilder: (context, day, _) => _dayCell(
                day,
                byDay[DateTime(day.year, day.month, day.day)],
                theme,
                isOutside: true,
              ),
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
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
                      if (widget.onAddTap != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _addForDay(ctx, day),
                          icon: const Icon(Icons.add),
                          iconSize: 20,
                          tooltip: '이 날짜에 거래 추가',
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: !hasItems
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '거래 없음',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              // 빈 날은 헤더의 + 아이콘만으로는 눈에 잘 안 띈다.
                              // 시트가 FAB 을 가리므로(모달 배리어) 추가 진입이 시트
                              // 안에 반드시 있어야 한다.
                              if (widget.onAddTap != null) ...[
                                const SizedBox(height: 12),
                                FilledButton.tonalIcon(
                                  onPressed: () => _addForDay(ctx, day),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('이 날짜에 거래 추가'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            ...summary.transactions
                                .map((tx) => TransactionListTile(
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

  /// 시트를 먼저 닫고 상위 콜백으로 넘긴다(항목 탭 경로와 동일 규약).
  /// 닫지 않으면 폼에서 돌아왔을 때 옛 데이터가 담긴 시트가 그대로 남는다.
  void _addForDay(BuildContext sheetContext, DateTime day) {
    Navigator.of(sheetContext).pop();
    widget.onAddTap!(day);
  }
}

class _DaySummary {
  int income = 0;
  int expense = 0;
  int transferTotal = 0;
  final List<Transaction> transactions = [];
  final List<Transfer> transfers = [];

  /// 그 날의 **정산 대상** 항목(거래+이체)이 전부 정산됐는지. 달력 셀의 정산 점 표시 조건.
  ///
  /// 두 스트림을 함께 보는 게 중요하다 — 거래만 검사하면 미정산 이체가 있는 날도
  /// "정산 완료" 로 보인다. 대상 판정은 ReconciliationScope 단일 소스 (잔액 수정 제외 —
  /// 빼지 않으면 잔액 수정이 있는 날은 완료 점이 영영 뜨지 않는다).
  bool get isFullyReconciled => ReconciliationScope.allReconciled(
        transactions: transactions,
        transfers: transfers,
      );
}
