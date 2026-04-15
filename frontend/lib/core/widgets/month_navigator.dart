import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';

/// Shared month navigation widget.
///
/// 기본 동작: MonthCubit state를 watch하여 year/month 표시.
/// 페이지에서 `year`/`month`를 명시적으로 전달하지 않으면 MonthCubit을 따름.
/// 이를 통해 여러 페이지 간 월 표시가 항상 sync됨.
///
/// `onMonthChanged` 콜백은 기본적으로 MonthCubit.changeMonth()만 호출하면
/// 됨 (MonthSyncHandler가 관련 BLoC reload 자동 처리).
class MonthNavigator extends StatelessWidget {
  /// 표시할 연도. 미지정 시 MonthCubit.state.year 사용.
  final int? year;

  /// 표시할 월. 미지정 시 MonthCubit.state.month 사용.
  final int? month;

  /// 월 변경 콜백. 미지정 시 MonthCubit.changeMonth 자동 호출.
  final ValueChanged<({int year, int month})>? onMonthChanged;

  /// 사용자가 특정 날짜(일)를 선택했을 때 호출. null이면 year/month만 사용.
  final ValueChanged<DateTime>? onDatePicked;

  const MonthNavigator({
    super.key,
    this.year,
    this.month,
    this.onMonthChanged,
    this.onDatePicked,
  });

  @override
  Widget build(BuildContext context) {
    // MonthCubit state를 watch — 다른 페이지에서 월 변경 시 자동 반영
    final monthState = context.watch<MonthCubit>().state;
    final displayYear = year ?? monthState.year;
    final displayMonth = month ?? monthState.month;

    void handleChange(({int year, int month}) ym) {
      if (onMonthChanged != null) {
        onMonthChanged!(ym);
      } else {
        // 기본 동작: MonthCubit만 업데이트 (MonthSyncHandler가 BLoC reload 처리)
        context.read<MonthCubit>().changeMonth(ym.year, ym.month);
      }
    }

    final dateStr =
        DateFormat('yyyy년 M월').format(DateTime(displayYear, displayMonth));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = displayMonth == 1
                  ? (year: displayYear - 1, month: 12)
                  : (year: displayYear, month: displayMonth - 1);
              handleChange(prev);
            },
            tooltip: '이전 달',
          ),
          TextButton(
            onPressed: () async {
              final picked = await showCalendarPickerDialog(
                context: context,
                initialDate: DateTime(displayYear, displayMonth),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030, 12, 31),
              );
              if (picked != null && context.mounted) {
                if (onDatePicked != null) {
                  onDatePicked!(picked);
                }
                handleChange((year: picked.year, month: picked.month));
              }
            },
            child: Text(
              dateStr,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = displayMonth == 12
                  ? (year: displayYear + 1, month: 1)
                  : (year: displayYear, month: displayMonth + 1);
              handleChange(next);
            },
            tooltip: '다음 달',
          ),
        ],
      ),
    );
  }
}
