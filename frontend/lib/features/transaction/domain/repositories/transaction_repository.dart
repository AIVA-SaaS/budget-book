import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';

abstract class TransactionRepository {
  Future<Either<Failure, PageResponse<Transaction>>> getTransactions({
    int? year,
    int? month,
    String? type,
    String? categoryId,
    String? keyword,
    String? paymentMethodId,
    String? pocketId,
    int? amountMin,
    int? amountMax,
    String? dateFrom,
    String? dateTo,
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

class SuggestionGroup {
  final String description;
  final List<SuggestionPattern> patterns;

  const SuggestionGroup({required this.description, required this.patterns});
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
}
