import 'package:equatable/equatable.dart';

sealed class ReconciliationEvent extends Equatable {
  const ReconciliationEvent();

  @override
  List<Object?> get props => [];
}

/// 해당 월의 스냅샷 목록 + 요약을 **함께** 로드한다.
///
/// 목록과 요약을 별도 이벤트로 분리하면 두 값이 서로 다른 달을 가리키는 순간이 생긴다
/// (원자적 로딩 원칙 — `add(A); add(B)` 금지).
class LoadReconciliations extends ReconciliationEvent {
  final int year;
  final int month;

  const LoadReconciliations({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class CreateReconciliation extends ReconciliationEvent {
  final String yearMonth;
  final String? label;
  final List<String> transactionIds;
  final List<String> transferIds;

  const CreateReconciliation({
    required this.yearMonth,
    this.label,
    this.transactionIds = const [],
    this.transferIds = const [],
  });

  @override
  List<Object?> get props => [yearMonth, label, transactionIds, transferIds];
}

class RenameReconciliation extends ReconciliationEvent {
  final String id;
  final String label;

  const RenameReconciliation({required this.id, required this.label});

  @override
  List<Object?> get props => [id, label];
}

/// 스냅샷에서 항목을 제외한다 (제외된 항목은 미기록으로 복귀).
class RemoveReconciliationItems extends ReconciliationEvent {
  final String id;
  final List<String> itemIds;

  const RemoveReconciliationItems({required this.id, required this.itemIds});

  @override
  List<Object?> get props => [id, itemIds];
}

class DeleteReconciliation extends ReconciliationEvent {
  final String id;

  const DeleteReconciliation(this.id);

  @override
  List<Object?> get props => [id];
}

/// 스냅샷 상세(항목) 펼치기. 이미 로드된 스냅샷은 재요청하지 않는다.
class LoadReconciliationDetail extends ReconciliationEvent {
  final String id;

  const LoadReconciliationDetail(this.id);

  @override
  List<Object?> get props => [id];
}
