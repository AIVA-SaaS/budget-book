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
  });

  Future<Either<Failure, Transaction>> updateTransaction({
    required String id,
    int? amount,
    String? description,
    String? categoryId,
    String? transactionDate,
    String? memo,
    bool clearMemo = false,
  });

  Future<Either<Failure, void>> deleteTransaction(String id);
}
