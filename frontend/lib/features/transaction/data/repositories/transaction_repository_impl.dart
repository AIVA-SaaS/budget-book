import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/transaction/data/datasources/transaction_remote_datasource.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource remoteDataSource;

  TransactionRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PageResponse<Transaction>>> getTransactions({
    int? year,
    int? month,
    TransactionFilter filter = TransactionFilter.empty,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final result = await remoteDataSource.getTransactions(
        year: year,
        month: month,
        filter: filter,
        page: page,
        size: size,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to load transactions'));
    } catch (e) {
      return const Left(ServerFailure('Failed to load transactions'));
    }
  }

  @override
  Future<Either<Failure, Transaction>> getTransaction(String id) async {
    try {
      final result = await remoteDataSource.getTransaction(id);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to load transaction'));
    } catch (e) {
      return const Left(ServerFailure('Failed to load transaction'));
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
    bool needsReview = false,
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
        // V61 (2026-05-06) — false 도 명시적으로 보낸다 (BE default 와 일치하지만 명확성).
        'needsReview': needsReview,
      };
      final result = await remoteDataSource.createTransaction(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to create transaction'));
    } catch (e) {
      return const Left(ServerFailure('Failed to create transaction'));
    }
  }

  @override
  Future<Either<Failure, Transaction>> updateTransaction({
    required String id,
    String? type,
    int? amount,
    String? description,
    String? categoryId,
    String? transactionDate,
    String? memo,
    bool clearMemo = false,
    String? paymentMethodId,
    String? pocketId,
    bool? needsReview,
  }) async {
    try {
      final data = <String, dynamic>{
        // 유형 변경 (수입↔지출). 서버가 카테고리 정합성·정산 기록 여부를 검증한다.
        if (type != null) 'type': type,
        if (amount != null) 'amount': amount,
        if (description != null) 'description': description,
        if (categoryId != null) 'categoryId': categoryId,
        if (transactionDate != null) 'transactionDate': transactionDate,
        if (memo != null) 'memo': memo else if (clearMemo) 'memo': null,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        if (pocketId != null) 'pocketId': pocketId,
        // V61 (2026-05-06) — null 이면 미변경, true/false 면 명시적 토글.
        if (needsReview != null) 'needsReview': needsReview,
      };
      final result = await remoteDataSource.updateTransaction(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to update transaction'));
    } catch (e) {
      return const Left(ServerFailure('Failed to update transaction'));
    }
  }

  @override
  Future<Either<Failure, Transfer>> convertToTransfer({
    required String id,
    required String sourcePaymentMethodId,
    required String destinationPaymentMethodId,
    String? kind,
    int? amount,
    String? transferDate,
    String? description,
    String? memo,
  }) async {
    try {
      final data = <String, dynamic>{
        'sourcePaymentMethodId': sourcePaymentMethodId,
        'destinationPaymentMethodId': destinationPaymentMethodId,
        // 생략한 값은 서버가 원본 거래에서 승계한다 — 여기서 채우지 않는다.
        if (kind != null) 'kind': kind,
        if (amount != null) 'amount': amount,
        if (transferDate != null) 'transferDate': transferDate,
        if (description != null) 'description': description,
        if (memo != null) 'memo': memo,
      };
      final result = await remoteDataSource.convertToTransfer(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to convert transaction to transfer'));
    } catch (e) {
      return const Left(ServerFailure('Failed to convert transaction to transfer'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(String id) async {
    try {
      await remoteDataSource.deleteTransaction(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to delete transaction'));
    } catch (e) {
      return const Left(ServerFailure('Failed to delete transaction'));
    }
  }

  @override
  Future<Either<Failure, List<SuggestionGroup>>> getSuggestions(
    String query, {
    String? type,
  }) async {
    try {
      final data = await remoteDataSource.getSuggestions(query, type: type);
      return Right(data);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to load suggestions'));
    } catch (e) {
      return const Left(ServerFailure('Failed to load suggestions'));
    }
  }
}
