import 'package:equatable/equatable.dart';

import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

sealed class ReconciliationState extends Equatable {
  const ReconciliationState();

  @override
  List<Object?> get props => [];
}

class ReconciliationInitial extends ReconciliationState {
  const ReconciliationInitial();
}

class ReconciliationLoading extends ReconciliationState {
  const ReconciliationLoading();
}

class ReconciliationLoaded extends ReconciliationState {
  final int year;
  final int month;

  /// 스냅샷 헤더 (최신 회차 먼저).
  final List<Reconciliation> snapshots;

  /// 미기록 건수/소계 요약. BE 가 계산한 값을 그대로 표시한다.
  final ReconciliationSummary summary;

  /// 미기록 항목. **서버 필터(`reconciled=false`)로 받은 목록**이다.
  /// 화면에 로드된 페이지를 클라이언트에서 걸러 만든 것이 아니다 (미로드 페이지 누락 방지).
  final List<Transaction> unrecordedTransactions;
  final List<Transfer> unrecordedTransfers;

  /// 미기록 거래가 더 남아 있는지 (거래만 페이지네이션 대상).
  final bool hasMoreUnrecorded;

  /// 펼쳐진 스냅샷의 항목 캐시 (id → 항목). 펼칠 때 채워진다.
  final Map<String, List<ReconciliationItem>> itemsBySnapshot;

  /// 진행 중인 mutation (버튼 중복 클릭 방지).
  final bool isMutating;

  final String? operationError;
  final String? operationSuccess;

  const ReconciliationLoaded({
    required this.year,
    required this.month,
    required this.snapshots,
    required this.summary,
    this.unrecordedTransactions = const [],
    this.unrecordedTransfers = const [],
    this.hasMoreUnrecorded = false,
    this.itemsBySnapshot = const {},
    this.isMutating = false,
    this.operationError,
    this.operationSuccess,
  });

  ReconciliationLoaded copyWith({
    int? year,
    int? month,
    List<Reconciliation>? snapshots,
    ReconciliationSummary? summary,
    List<Transaction>? unrecordedTransactions,
    List<Transfer>? unrecordedTransfers,
    bool? hasMoreUnrecorded,
    Map<String, List<ReconciliationItem>>? itemsBySnapshot,
    bool? isMutating,
    String? operationError,
    String? operationSuccess,
    bool clearMessages = false,
  }) {
    return ReconciliationLoaded(
      year: year ?? this.year,
      month: month ?? this.month,
      snapshots: snapshots ?? this.snapshots,
      summary: summary ?? this.summary,
      unrecordedTransactions:
          unrecordedTransactions ?? this.unrecordedTransactions,
      unrecordedTransfers: unrecordedTransfers ?? this.unrecordedTransfers,
      hasMoreUnrecorded: hasMoreUnrecorded ?? this.hasMoreUnrecorded,
      itemsBySnapshot: itemsBySnapshot ?? this.itemsBySnapshot,
      isMutating: isMutating ?? this.isMutating,
      operationError: clearMessages ? null : (operationError ?? this.operationError),
      operationSuccess:
          clearMessages ? null : (operationSuccess ?? this.operationSuccess),
    );
  }

  @override
  List<Object?> get props => [
        year,
        month,
        snapshots,
        summary,
        unrecordedTransactions,
        unrecordedTransfers,
        hasMoreUnrecorded,
        itemsBySnapshot,
        isMutating,
        operationError,
        operationSuccess,
      ];
}

class ReconciliationError extends ReconciliationState {
  final String message;

  const ReconciliationError(this.message);

  @override
  List<Object?> get props => [message];
}
