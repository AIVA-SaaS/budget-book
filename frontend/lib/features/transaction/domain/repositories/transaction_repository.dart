import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';

abstract class TransactionRepository {
  /// 거래 목록 조회.
  ///
  /// 필터는 개별 파라미터가 아니라 [TransactionFilter] VO 하나로 받는다.
  /// bloc → repository → datasource 3-hop 마다 필드를 나열하면 hop 당 누락 기회가
  /// 생기고, 실제로 "필터 drop" 인시던트가 4회 재발했다. 새 필터 추가 시
  /// [TransactionFilter] 와 `toQueryParams()` 두 곳만 고치면 전 구간에 반영된다.
  Future<Either<Failure, PageResponse<Transaction>>> getTransactions({
    int? year,
    int? month,
    TransactionFilter filter = TransactionFilter.empty,
    int page = 0,
    int size = 20,
  });

  Future<Either<Failure, Transaction>> getTransaction(String id);

  Future<Either<Failure, Transaction>> createTransaction({
    required String type,
    required int amount,
    required String description,
    String? categoryId,
    required String transactionDate,
    String? memo,
    String? paymentMethodId,
    String? pocketId,
    bool needsReview = false,
  });

  Future<Either<Failure, Transaction>> updateTransaction({
    required String id,
    int? amount,
    String? description,
    String? categoryId,
    String? transactionDate,
    String? memo,
    bool clearMemo = false,
    String? paymentMethodId,
    String? pocketId,
    bool? needsReview,
  });

  Future<Either<Failure, void>> deleteTransaction(String id);

  Future<Either<Failure, List<SuggestionGroup>>> getSuggestions(
    String query, {
    String? type,
  });
}

/// Suggestion group from /transactions/suggestions endpoint.
///
/// **Equatable** by [description] only — fetch 응답이 새로 도착해도 같은 description
/// 의 expand state 를 보존하기 위함. patterns 의 변경(횟수 증감 등)은 무시.
class SuggestionGroup {
  final String description;
  final List<SuggestionPattern> patterns;

  const SuggestionGroup({required this.description, required this.patterns});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuggestionGroup && other.description == description;

  @override
  int get hashCode => description.hashCode;
}

class SuggestionPattern {
  final String? categoryId;
  final String? categoryName;
  // 회차 12 follow-up — 카테고리 표시 통일 ("$groupName > $categoryName")
  final String? categoryGroupName;
  final String? categoryIcon;
  final String? categoryColor;
  final String? paymentMethodId;
  final String? paymentMethodName;
  final int count;

  const SuggestionPattern({
    this.categoryId,
    this.categoryName,
    this.categoryGroupName,
    this.categoryIcon,
    this.categoryColor,
    this.paymentMethodId,
    this.paymentMethodName,
    required this.count,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuggestionPattern &&
          other.categoryId == categoryId &&
          other.paymentMethodId == paymentMethodId;

  @override
  int get hashCode => Object.hash(categoryId, paymentMethodId);
}
