import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 전역 기간(period) 상태 — year/month + optional date range + optional week.
///
/// [MonthCubit] 의 단일 소스 철학을 확장하여 "월" 뿐 아니라
/// - 임의 날짜 범위 (dateFrom/dateTo)
/// - 주(week) 선택
/// 까지 중앙화한다.
///
/// 과거 인시던트: 월 이동 시 dateRange/필터 drop → navigation_state 재발 방지.
///
/// 모드 규칙:
///   - `dateFrom != null && dateTo != null` → **range 모드**. 연/월 은 dateFrom 에서 파생.
///   - 그 외 → **month 모드**. year/month 로만 조회.
///   - month 모드에서 `changeMonth(y, m)` 호출 시 기존 range 는 자동 `clearRange()`.
///   - range 모드에서 `setDateRange(from, to)` 호출 시 year/month 도 함께 from 기준으로 동기화.
class UnifiedPeriodState extends Equatable {
  final int year;
  final int month;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? week;

  const UnifiedPeriodState({
    required this.year,
    required this.month,
    this.dateFrom,
    this.dateTo,
    this.week,
  });

  bool get isRangeMode => dateFrom != null && dateTo != null;

  /// BE API 호출용 YYYY-MM-DD 포맷 (dateFrom).
  String? get dateFromIso => _fmt(dateFrom);

  /// BE API 호출용 YYYY-MM-DD 포맷 (dateTo).
  String? get dateToIso => _fmt(dateTo);

  static String? _fmt(DateTime? d) {
    if (d == null) return null;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  UnifiedPeriodState copyWith({
    int? year,
    int? month,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? week,
    bool clearRange = false,
    bool clearWeek = false,
  }) {
    return UnifiedPeriodState(
      year: year ?? this.year,
      month: month ?? this.month,
      dateFrom: clearRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearRange ? null : (dateTo ?? this.dateTo),
      week: clearWeek ? null : (week ?? this.week),
    );
  }

  @override
  List<Object?> get props => [year, month, dateFrom, dateTo, week];

  @override
  String toString() => isRangeMode
      ? 'Period[range: $dateFromIso ~ $dateToIso]'
      : 'Period[$year-$month${week != null ? ' w$week' : ''}]';
}

class UnifiedPeriodCubit extends Cubit<UnifiedPeriodState> {
  UnifiedPeriodCubit({int? initialYear, int? initialMonth})
      : super(UnifiedPeriodState(
          year: initialYear ?? DateTime.now().year,
          month: initialMonth ?? DateTime.now().month,
        ));

  /// 월 변경 (month 모드). 기존 date range 는 자동 해제됨.
  void changeMonth(int year, int month) {
    if (state.year == year &&
        state.month == month &&
        state.dateFrom == null &&
        state.dateTo == null) {
      return;
    }
    emit(state.copyWith(year: year, month: month, clearRange: true));
  }

  /// 날짜 범위 지정 (range 모드). year/month 도 from 기준으로 동기화.
  void setDateRange(DateTime from, DateTime to) {
    if (state.dateFrom == from && state.dateTo == to) return;
    emit(state.copyWith(
      year: from.year,
      month: from.month,
      dateFrom: from,
      dateTo: to,
    ));
  }

  /// range 해제 → month 모드 복귀.
  void clearRange() {
    if (!state.isRangeMode) return;
    emit(state.copyWith(clearRange: true));
  }

  /// 주(week) 지정. week 는 month 내 1-based.
  void setWeek(int? week) {
    if (state.week == week) return;
    emit(state.copyWith(week: week, clearWeek: week == null));
  }
}
