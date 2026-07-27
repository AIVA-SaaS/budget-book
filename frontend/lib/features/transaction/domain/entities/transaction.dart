import 'package:equatable/equatable.dart';
import 'transaction_author.dart';
import 'transaction_category.dart';

class Transaction extends Equatable {
  final String id;
  final String coupleId;
  final TransactionAuthor author;
  final TransactionCategory? category;
  final String type;
  final int amount;
  final String description;
  final String? memo;
  final String transactionDate;
  final String? paymentMethodId;
  final String? paymentMethodName;
  final String? paymentMethodType;
  final String? settlementDate;
  final String? pocketId;
  final String? pocketName;
  final String visibility;
  final String? ownerId;
  /// V61 (2026-05-06) — 사용자가 "확인/입력 필요" 로 마킹한 거래.
  final bool needsReview;

  /// V65 (2026-07-27) — 이 거래가 담긴 정산 스냅샷. 미기록이면 전부 null.
  /// Transfer 에도 **같은 3필드**가 있다 (장부 목록이 두 스트림 병합이라 한쪽만 채우면
  /// 이체 배지가 영구 미표시되는 drift 가 난다).
  final String? reconciliationId;
  final int? reconciliationSeq;
  final DateTime? reconciledAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    required this.id,
    required this.coupleId,
    required this.author,
    this.category,
    required this.type,
    required this.amount,
    required this.description,
    this.memo,
    required this.transactionDate,
    this.paymentMethodId,
    this.paymentMethodName,
    this.paymentMethodType,
    this.settlementDate,
    this.pocketId,
    this.pocketName,
    this.visibility = 'SHARED',
    this.ownerId,
    this.needsReview = false,
    this.reconciliationId,
    this.reconciliationSeq,
    this.reconciledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == 'INCOME';
  bool get isExpense => type == 'EXPENSE';
  bool get isAdjustment => type == 'ADJUSTMENT';
  bool get isPrivate => visibility == 'PRIVATE';
  bool get isShared => visibility == 'SHARED';

  /// 정산 스냅샷에 기록된 거래인지 (배지 표시 조건).
  bool get isReconciled => reconciliationId != null;

  @override
  List<Object?> get props => [
        id,
        coupleId,
        author,
        category,
        type,
        amount,
        description,
        memo,
        transactionDate,
        paymentMethodId,
        paymentMethodName,
        paymentMethodType,
        settlementDate,
        pocketId,
        pocketName,
        visibility,
        ownerId,
        needsReview,
        reconciliationId,
        reconciliationSeq,
        reconciledAt,
        createdAt,
        updatedAt,
      ];
}
