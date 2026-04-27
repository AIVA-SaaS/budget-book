import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';

abstract class TransactionRepository {
  Future<Either<Failure, PageResponse<Transaction>>> getTransactions({
    int? year,
    int? month,
    String? type,
    Set<String> transactionTypes,
    String? categoryId,
    Set<String> categoryIds = const {},
    Set<String> categoryGroupIds = const {},
    String? keyword,
    String? paymentMethodId,
    Set<String> paymentMethodIds = const {},
    String? pocketId,
    Set<String> pocketIds = const {},
    int? amountMin,
    int? amountMax,
    String? dateFrom,
    String? dateTo,
    String? visibility,
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
  });

  Future<Either<Failure, void>> deleteTransaction(String id);

  Future<Either<Failure, List<SuggestionGroup>>> getSuggestions(String query);
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
  final String? categoryIcon;
  final String? categoryColor;
  final String? paymentMethodId;
  final String? paymentMethodName;
  final int count;

  const SuggestionPattern({
    this.categoryId,
    this.categoryName,
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
