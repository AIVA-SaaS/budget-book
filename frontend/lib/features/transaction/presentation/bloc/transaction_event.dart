import 'package:equatable/equatable.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';

sealed class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactions extends TransactionEvent {
  final int year;
  final int month;
  final String? keyword;
  final String? categoryId;
  final Set<String> categoryIds;
  final Set<String> categoryGroupIds;
  final String? paymentMethodId;
  final Set<String> paymentMethodIds;
  final String? pocketId;
  final Set<String> pocketIds;
  final int? amountMin;
  final int? amountMax;
  final String? scrollToDate;
  final String? dateFrom;
  final String? dateTo;
  final String? type;
  final Set<String> transactionTypes;
  final String? visibility;
  /// V61 (2026-05-06) — true 면 needs_review=true 거래만 (확인/입력 필요만 보기).
  final bool? needsReviewOnly;

  const LoadTransactions({
    required this.year,
    required this.month,
    this.keyword,
    this.categoryId,
    this.categoryIds = const {},
    this.categoryGroupIds = const {},
    this.paymentMethodId,
    this.paymentMethodIds = const {},
    this.pocketId,
    this.pocketIds = const {},
    this.amountMin,
    this.amountMax,
    this.scrollToDate,
    this.dateFrom,
    this.dateTo,
    this.type,
    this.transactionTypes = const {},
    this.visibility,
    this.needsReviewOnly,
  });

  /// 필터 VO 전체를 드롭 없이 전파하는 단일 진입점.
  /// MonthSyncHandler 등 외부 consumer 가 개별 필드를 수동 나열하다 한 필드를
  /// 빠뜨리는 사고(2026-04-15 "월 이동 후 필터 drop" 인시던트, transactionTypes·
  /// needsReviewOnly 누락으로 재발)를 원천 차단한다. 새 필터 추가 시 TransactionFilter
  /// 와 LoadTransactions 생성자만 고치면 이 팩토리는 자동으로 전체를 전달한다.
  factory LoadTransactions.fromFilter(
    int year,
    int month,
    TransactionFilter f, {
    String? scrollToDate,
    bool clearDateRange = false,
  }) {
    return LoadTransactions(
      year: year,
      month: month,
      keyword: f.keyword,
      categoryId: f.categoryId,
      categoryIds: f.categoryIds,
      categoryGroupIds: f.categoryGroupIds,
      paymentMethodId: f.paymentMethodId,
      paymentMethodIds: f.paymentMethodIds,
      pocketId: f.pocketId,
      pocketIds: f.pocketIds,
      amountMin: f.amountMin,
      amountMax: f.amountMax,
      // 월 이동 시 특정 월에 종속된 명시적 기간 필터는 해제(페이지 내비게이터와 동일 규칙).
      dateFrom: clearDateRange ? null : f.dateFrom,
      dateTo: clearDateRange ? null : f.dateTo,
      type: f.type,
      transactionTypes: f.transactionTypes,
      visibility: f.visibility,
      needsReviewOnly: f.needsReviewOnly,
      scrollToDate: scrollToDate,
    );
  }

  @override
  List<Object?> get props => [
        year,
        month,
        keyword,
        categoryId,
        categoryIds,
        categoryGroupIds,
        paymentMethodId,
        paymentMethodIds,
        pocketId,
        pocketIds,
        amountMin,
        amountMax,
        scrollToDate,
        dateFrom,
        dateTo,
        type,
        transactionTypes,
        visibility,
        needsReviewOnly,
      ];
}

class CreateTransaction extends TransactionEvent {
  final String type;
  final int amount;
  final String description;
  final String? categoryId;
  final String transactionDate;
  final String? memo;
  final String? paymentMethodId;
  final String? pocketId;
  /// V61 (2026-05-06) — 확인/입력 필요 플래그.
  final bool needsReview;

  const CreateTransaction({
    required this.type,
    required this.amount,
    required this.description,
    this.categoryId,
    required this.transactionDate,
    this.memo,
    this.paymentMethodId,
    this.pocketId,
    this.needsReview = false,
  });

  @override
  List<Object?> get props =>
      [type, amount, description, categoryId, transactionDate, memo, paymentMethodId, pocketId, needsReview];
}

class UpdateTransaction extends TransactionEvent {
  final String id;
  final int? amount;
  final String? description;
  final String? categoryId;
  final String? transactionDate;
  final String? memo;
  final bool clearMemo;
  final String? paymentMethodId;
  final String? pocketId;
  /// V61 (2026-05-06) — null 이면 미변경, true/false 면 토글.
  final bool? needsReview;

  const UpdateTransaction({
    required this.id,
    this.amount,
    this.description,
    this.categoryId,
    this.transactionDate,
    this.memo,
    this.clearMemo = false,
    this.paymentMethodId,
    this.pocketId,
    this.needsReview,
  });

  @override
  List<Object?> get props =>
      [id, amount, description, categoryId, transactionDate, memo, clearMemo, paymentMethodId, pocketId, needsReview];
}

class LoadMoreTransactions extends TransactionEvent {
  const LoadMoreTransactions();
}

class DeleteTransaction extends TransactionEvent {
  final String id;

  const DeleteTransaction(this.id);

  @override
  List<Object?> get props => [id];
}
