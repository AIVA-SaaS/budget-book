import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';
import 'package:budget_book/features/transaction/data/models/transaction_author_model.dart';

class ReconciliationModel extends Reconciliation {
  const ReconciliationModel({
    required super.id,
    required super.yearMonth,
    required super.seq,
    super.label,
    required super.itemCount,
    required super.totalIncome,
    required super.totalExpense,
    required super.totalTransfer,
    required super.reconciledAt,
    required super.reconciledBy,
    super.hasChangedItems,
    super.hasDeletedItems,
  });

  factory ReconciliationModel.fromJson(Map<String, dynamic> json) {
    return ReconciliationModel(
      id: json['id'] as String,
      yearMonth: json['yearMonth'] as String,
      seq: json['seq'] as int,
      label: json['label'] as String?,
      itemCount: json['itemCount'] as int,
      totalIncome: json['totalIncome'] as int,
      totalExpense: json['totalExpense'] as int,
      totalTransfer: json['totalTransfer'] as int,
      reconciledAt: DateTime.parse(json['reconciledAt'] as String),
      reconciledBy: TransactionAuthorModel.fromJson(
          json['reconciledBy'] as Map<String, dynamic>),
      hasChangedItems: json['hasChangedItems'] as bool? ?? false,
      hasDeletedItems: json['hasDeletedItems'] as bool? ?? false,
    );
  }
}

class ReconciliationItemModel extends ReconciliationItem {
  const ReconciliationItemModel({
    required super.itemId,
    required super.itemKind,
    super.refId,
    required super.snapshotAmount,
    required super.snapshotDate,
    super.snapshotDescription,
    required super.snapshotKind,
    super.currentAmount,
    super.currentDate,
    super.changedAfterReconcile,
    super.originDeleted,
  });

  factory ReconciliationItemModel.fromJson(Map<String, dynamic> json) {
    return ReconciliationItemModel(
      itemId: json['itemId'] as String,
      itemKind: json['itemKind'] as String,
      refId: json['refId'] as String?,
      snapshotAmount: json['snapshotAmount'] as int,
      snapshotDate: json['snapshotDate'] as String,
      snapshotDescription: json['snapshotDescription'] as String?,
      snapshotKind: json['snapshotKind'] as String,
      currentAmount: json['currentAmount'] as int?,
      currentDate: json['currentDate'] as String?,
      changedAfterReconcile: json['changedAfterReconcile'] as bool? ?? false,
      originDeleted: json['originDeleted'] as bool? ?? false,
    );
  }
}

class ReconciliationDetailModel extends ReconciliationDetail {
  const ReconciliationDetailModel({
    required super.header,
    required super.items,
  });

  /// 상세 응답은 헤더 필드와 `items` 가 **한 객체에 평평하게** 담겨 온다
  /// (`docs/api-spec.md § Get Reconciliation`).
  factory ReconciliationDetailModel.fromJson(Map<String, dynamic> json) {
    return ReconciliationDetailModel(
      header: ReconciliationModel.fromJson(json),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) =>
              ReconciliationItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReconciliationSummaryModel extends ReconciliationSummary {
  const ReconciliationSummaryModel({
    required super.yearMonth,
    required super.snapshotCount,
    required super.recordedCount,
    required super.unrecordedCount,
    required super.unrecordedIncome,
    required super.unrecordedExpense,
    required super.unrecordedTransfer,
    required super.needsReviewCount,
  });

  factory ReconciliationSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReconciliationSummaryModel(
      yearMonth: json['yearMonth'] as String,
      snapshotCount: json['snapshotCount'] as int,
      recordedCount: json['recordedCount'] as int,
      unrecordedCount: json['unrecordedCount'] as int,
      unrecordedIncome: json['unrecordedIncome'] as int,
      unrecordedExpense: json['unrecordedExpense'] as int,
      unrecordedTransfer: json['unrecordedTransfer'] as int,
      needsReviewCount: json['needsReviewCount'] as int? ?? 0,
    );
  }
}
