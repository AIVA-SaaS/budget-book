import 'package:equatable/equatable.dart';

import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';

/// 정산 스냅샷 헤더.
///
/// 소계(`totalIncome` 등)는 **BE 가 조회자 게이팅 후 계산해 내려준 값**이다.
/// FE 에서 항목을 다시 더해 표시하면 파트너 개인 항목이 섞이거나 이중 합산되어
/// "합계 ≠ 보이는 행" 불일치가 난다 → 재계산 금지, 표시만 한다.
class Reconciliation extends Equatable {
  final String id;
  final String yearMonth;

  /// 월 내 회차 (1부터). UI 에 "N차" 로 표시.
  final int seq;
  final String? label;
  final int itemCount;
  final int totalIncome;
  final int totalExpense;
  final int totalTransfer;
  final DateTime reconciledAt;
  final TransactionAuthor reconciledBy;

  /// 정산 후 원본 금액/날짜가 바뀐 항목이 하나라도 있으면 true (⚠ 표시).
  final bool hasChangedItems;

  /// 원본이 삭제된 항목이 하나라도 있으면 true.
  final bool hasDeletedItems;

  const Reconciliation({
    required this.id,
    required this.yearMonth,
    required this.seq,
    this.label,
    required this.itemCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalTransfer,
    required this.reconciledAt,
    required this.reconciledBy,
    this.hasChangedItems = false,
    this.hasDeletedItems = false,
  });

  /// 표시용 이름. 라벨이 없으면 회차로 대체한다.
  String get displayName => (label?.isNotEmpty ?? false) ? label! : '$seq차';

  @override
  List<Object?> get props => [
        id,
        yearMonth,
        seq,
        label,
        itemCount,
        totalIncome,
        totalExpense,
        totalTransfer,
        reconciledAt,
        reconciledBy,
        hasChangedItems,
        hasDeletedItems,
      ];
}

/// 스냅샷 상세 (헤더 + 항목).
class ReconciliationDetail extends Equatable {
  final Reconciliation header;
  final List<ReconciliationItem> items;

  const ReconciliationDetail({required this.header, required this.items});

  @override
  List<Object?> get props => [header, items];
}

/// 스냅샷 항목. 정산 당시 값(`snapshot*`)과 현재 원본 값(`current*`)을 함께 갖는다.
class ReconciliationItem extends Equatable {
  /// 스냅샷 항목 id (제외 요청에 사용 — 원본 거래 id 가 아니다).
  final String itemId;

  /// `TRANSACTION` | `TRANSFER`
  final String itemKind;

  /// 원본 거래/이체 id. 원본이 삭제되면 null.
  final String? refId;
  final int snapshotAmount;
  final String snapshotDate;
  final String? snapshotDescription;
  final String snapshotKind;
  final int? currentAmount;
  final String? currentDate;

  /// 금액/날짜가 정산 당시와 다르면 true.
  final bool changedAfterReconcile;
  final bool originDeleted;

  const ReconciliationItem({
    required this.itemId,
    required this.itemKind,
    this.refId,
    required this.snapshotAmount,
    required this.snapshotDate,
    this.snapshotDescription,
    required this.snapshotKind,
    this.currentAmount,
    this.currentDate,
    this.changedAfterReconcile = false,
    this.originDeleted = false,
  });

  bool get isTransfer => itemKind == 'TRANSFER';

  @override
  List<Object?> get props => [
        itemId,
        itemKind,
        refId,
        snapshotAmount,
        snapshotDate,
        snapshotDescription,
        snapshotKind,
        currentAmount,
        currentDate,
        changedAfterReconcile,
        originDeleted,
      ];
}

/// 월말 누락 점검 요약.
class ReconciliationSummary extends Equatable {
  final String yearMonth;
  final int snapshotCount;
  final int recordedCount;
  final int unrecordedCount;
  final int unrecordedIncome;
  final int unrecordedExpense;
  final int unrecordedTransfer;

  /// 미기록 항목 중 "확인/입력 필요" 로 마킹된 거래 수 (정산 확정 경고에 사용).
  final int needsReviewCount;

  const ReconciliationSummary({
    required this.yearMonth,
    required this.snapshotCount,
    required this.recordedCount,
    required this.unrecordedCount,
    required this.unrecordedIncome,
    required this.unrecordedExpense,
    required this.unrecordedTransfer,
    required this.needsReviewCount,
  });

  /// 그 달의 모든 항목이 정산됐는지 ("정산 완료" 배지 조건).
  bool get isFullyReconciled => unrecordedCount == 0 && recordedCount > 0;

  @override
  List<Object?> get props => [
        yearMonth,
        snapshotCount,
        recordedCount,
        unrecordedCount,
        unrecordedIncome,
        unrecordedExpense,
        unrecordedTransfer,
        needsReviewCount,
      ];
}
