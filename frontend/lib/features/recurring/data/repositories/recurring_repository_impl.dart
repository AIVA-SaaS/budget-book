import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/recurring/data/datasources/recurring_remote_datasource.dart';
import 'package:budget_book/features/recurring/domain/entities/recurring_transaction.dart';
import 'package:budget_book/features/recurring/domain/repositories/recurring_repository.dart';

class RecurringRepositoryImpl implements RecurringRepository {
  final RecurringRemoteDataSource remoteDataSource;

  RecurringRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<RecurringTransaction>>>
      getRecurringTransactions() async {
    try {
      final result = await remoteDataSource.getRecurringTransactions();
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, '반복 거래를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, RecurringTransaction>> createRecurringTransaction({
    required String type,
    required int amount,
    required String description,
    String? memo,
    required String frequency,
    int? dayOfMonth,
    int? dayOfWeek,
    String? categoryId,
    String? paymentMethodId,
  }) async {
    try {
      final data = <String, dynamic>{
        'type': type,
        'amount': amount,
        'description': description,
        'frequency': frequency,
        if (memo != null) 'memo': memo,
        if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
        if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
        if (categoryId != null) 'categoryId': categoryId,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
      };
      final result = await remoteDataSource.createRecurringTransaction(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, '반복 거래를 생성하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, RecurringTransaction>> updateRecurringTransaction({
    required String id,
    int? amount,
    String? description,
    String? memo,
    String? categoryId,
    String? paymentMethodId,
    int? dayOfMonth,
    int? dayOfWeek,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{
        if (amount != null) 'amount': amount,
        if (description != null) 'description': description,
        if (memo != null) 'memo': memo,
        if (categoryId != null) 'categoryId': categoryId,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
        if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
        if (isActive != null) 'isActive': isActive,
      };
      final result =
          await remoteDataSource.updateRecurringTransaction(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(_mapDioError(e, '반복 거래를 수정하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRecurringTransaction(String id) async {
    try {
      await remoteDataSource.deleteRecurringTransaction(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e, '반복 거래를 삭제하지 못했습니다'));
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
