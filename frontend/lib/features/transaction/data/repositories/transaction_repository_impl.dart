import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transaction/data/datasources/transaction_remote_datasource.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource remoteDataSource;

  TransactionRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PageResponse<Transaction>>> getTransactions({
    int? year,
    int? month,
    String? type,
    String? categoryId,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final result = await remoteDataSource.getTransactions(
        year: year,
        month: month,
        type: type,
        categoryId: categoryId,
        page: page,
        size: size,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to load transactions'));
    }
  }

  @override
  Future<Either<Failure, Transaction>> getTransaction(String id) async {
    try {
      final result = await remoteDataSource.getTransaction(id);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to load transaction'));
    }
  }

  @override
  Future<Either<Failure, Transaction>> createTransaction({
    required String type,
    required int amount,
    required String description,
    String? categoryId,
    required String transactionDate,
    String? memo,
    String? paymentMethodId,
    String? pocketId,
  }) async {
    try {
      final data = <String, dynamic>{
        'type': type,
        'amount': amount,
        'description': description,
        'transactionDate': transactionDate,
        if (categoryId != null) 'categoryId': categoryId,
        if (memo != null) 'memo': memo,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        if (pocketId != null) 'pocketId': pocketId,
      };
      final result = await remoteDataSource.createTransaction(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to create transaction'));
    }
  }

  @override
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
  }) async {
    try {
      final data = <String, dynamic>{
        if (amount != null) 'amount': amount,
        if (description != null) 'description': description,
        if (categoryId != null) 'categoryId': categoryId,
        if (transactionDate != null) 'transactionDate': transactionDate,
        if (memo != null) 'memo': memo else if (clearMemo) 'memo': null,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        if (pocketId != null) 'pocketId': pocketId,
      };
      final result = await remoteDataSource.updateTransaction(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to update transaction'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(String id) async {
    try {
      await remoteDataSource.deleteTransaction(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e, 'Failed to delete transaction'));
    }
  }

  Failure _mapDioError(DioException e, String defaultMessage) {
    final errorData = e.response?.data?['error'];
    return ServerFailure(
      errorData?['message'] as String? ?? defaultMessage,
      errorData?['code'] as String?,
      e.response?.statusCode,
    );
  }
}
