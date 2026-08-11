import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/widgets/month_year_picker_dialog.dart';

/// Shared month navigation widget.
///
/// 기본 동작: MonthCubit state를 watch하여 year/month 표시.
/// 페이지에서 `year`/`month`를 명시적으로 전달하지 않으면 MonthCubit을 따름.
/// 이를 통해 여러 페이지 간 월 표시가 항상 sync됨.
///
/// `onMonthChanged` 콜백은 기본적으로 MonthCubit.changeMonth()만 호출하면
/// 됨 (MonthSyncHandler가 관련 BLoC reload 자동 처리).
///
/// ## 이 위젯이 월 이동 UI 의 유일한 진입점이다 (2026-08-11)
///
/// 페이지가 자체 월 헤더를 만들면 여기 개선이 그 화면에만 빠진다 — 실제로
/// 홈 대시보드가 그랬다(`_MonthHeader`, 눌러도 팝업이 없음). 하네스 `navigation_state`
/// 4회 재발의 한 축이라 `month_navigator_single_source_guard_test.dart` 가
/// "자체 월 헤더 금지" 를 소스 스캔으로 막는다.
class MonthNavigator extends StatelessWidget {
  /// 표시할 연도. 미지정 시 MonthCubit.state.year 사용.
  final int? year;

  /// 표시할 월. 미지정 시 MonthCubit.state.month 사용.
  final int? month;

  /// 월 변경 콜백. 미지정 시 MonthCubit.changeMonth 자동 호출.
  final ValueChanged<({int year, int month})>? onMonthChanged;

  /// 사용자가 특정 날짜(일)를 선택했을 때 호출. null이면 year/month만 사용.
  ///
  /// 이 콜백을 주면 피커가 **일 그리드로 진입**한다(기존 사용감 유지). 주지 않으면
  /// **월 그리드로 진입**해 달 선택이 1탭으로 끝난다. 실제 사용처는 거래 목록 1곳뿐이다.
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

    final now = DateTime.now();
    final isCurrentMonth = displayYear == now.year && displayMonth == now.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // "오늘" 버튼이 오른쪽 끝에 붙으므로, 같은 폭을 왼쪽에 비워 가운데 날짜의
          // 좌우 대칭을 유지한다.
          const SizedBox(width: 48),
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
          // 고정 폭 4칸(스페이서 + 화살표 2 + 오늘) 192 를 빼면 좁은 화면·큰 글꼴 배율에서
          // 여유가 많지 않다. 넘치면 잘라서 표시한다.
          Flexible(
            child: TextButton(
              onPressed: () async {
                final picked = await showMonthYearPickerDialog(
                  context: context,
                  initialYear: displayYear,
                  initialMonth: displayMonth,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030, 12, 31),
                  allowDaySelection: onDatePicked != null,
                );
                if (picked == null || !context.mounted) return;
                if (picked.day != null) {
                  onDatePicked!(picked.date);
                }
                handleChange((year: picked.year, month: picked.month));
              },
              child: Text(
                dateStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
          IconButton(
            icon: const Icon(Icons.today),
            // 이번 달을 보고 있으면 누를 이유가 없다 — 비활성으로 상태를 드러낸다.
            onPressed: isCurrentMonth
                ? null
                : () => handleChange((year: now.year, month: now.month)),
            tooltip: '이번 달로',
          ),
        ],
      ),
    );
  }
}
