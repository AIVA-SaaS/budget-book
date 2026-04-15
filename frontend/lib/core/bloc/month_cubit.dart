import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 전역 월 상태 (year/month).
/// 모든 월 의존 페이지와 BLoC이 공유하는 단일 소스.
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
