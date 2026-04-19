import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 전역 월 상태 (year/month).
/// 모든 월 의존 페이지와 BLoC이 공유하는 단일 소스.
///
/// **⚠ DEPRECATED**: 신규 코드는 [UnifiedPeriodCubit] 를 사용하세요.
/// 이 Cubit 은 호환성을 위한 얇은 alias 이며 향후 회차에 제거됩니다.
/// UnifiedPeriodCubit 은 year/month 뿐 아니라 dateFrom/dateTo/week 까지 포함합니다.
///
/// 사용:
///   - 월 네비게이터에서: `context.read<MonthCubit>().changeMonth(year, month)`
///   - 현재 월 조회: `context.watch<MonthCubit>().state`
///   - 반응형 BLoC 연결: MonthSyncHandler 참조
class MonthState extends Equatable {
  final int year;
  final int month;

  const MonthState({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];

  @override
  String toString() => '$year-$month';
}

class MonthCubit extends Cubit<MonthState> {
  MonthCubit()
      : super(MonthState(
          year: DateTime.now().year,
          month: DateTime.now().month,
        ));

  /// 월 변경. 같은 월이면 emit 생략 (불필요한 reload 방지).
  void changeMonth(int year, int month) {
    if (state.year == year && state.month == month) return;
    emit(MonthState(year: year, month: month));
  }
}
