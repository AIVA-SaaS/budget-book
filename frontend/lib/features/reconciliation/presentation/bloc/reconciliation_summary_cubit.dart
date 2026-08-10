import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';
import 'package:budget_book/features/reconciliation/domain/repositories/reconciliation_repository.dart';

/// 월말 점검 요약만 담당하는 가벼운 cubit.
///
/// `ReconciliationBloc` 을 재사용하지 않는 이유: 그쪽은 스냅샷 목록 + 미기록 항목
/// 목록(최대 200건)까지 함께 불러온다. 분석 탭 상단 카드는 **집계 8개 숫자**만
/// 필요하므로 목록 조회 비용을 지불할 이유가 없다.
///
/// 실패는 상태로 표면화하지 않고 null 로 남긴다 — 카드가 사라질 뿐 분석 탭의
/// 다른 내용에는 영향이 없어야 한다.
class ReconciliationSummaryState extends Equatable {
  final ReconciliationSummary? summary;
  final bool loading;

  const ReconciliationSummaryState({this.summary, this.loading = false});

  @override
  List<Object?> get props => [summary, loading];
}

class ReconciliationSummaryCubit extends Cubit<ReconciliationSummaryState> {
  final ReconciliationRepository repository;

  ReconciliationSummaryCubit({required this.repository})
      : super(const ReconciliationSummaryState());

  /// 마지막으로 요청한 연/월. 같은 달의 중복 in-flight 요청을 막는다.
  int? _pendingYear;
  int? _pendingMonth;

  Future<void> load({required int year, required int month}) async {
    if (state.loading && _pendingYear == year && _pendingMonth == month) return;
    _pendingYear = year;
    _pendingMonth = month;
    emit(ReconciliationSummaryState(summary: state.summary, loading: true));

    final result = await repository.getSummary(year: year, month: month);
    if (isClosed) return;
    // 응답이 도착하는 사이 사용자가 달을 옮겼으면 버린다 (오래된 응답이 최신 달의
    // 숫자를 덮어쓰는 것을 막는다).
    if (_pendingYear != year || _pendingMonth != month) return;

    result.fold(
      (_) => emit(const ReconciliationSummaryState()),
      (data) => emit(ReconciliationSummaryState(summary: data)),
    );
  }
}
