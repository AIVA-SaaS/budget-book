import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/payment_method/data/datasources/payment_method_remote_datasource.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/domain/entities/card_pending.dart';
import 'package:budget_book/features/payment_method/domain/repositories/payment_method_repository.dart';

class PaymentMethodRepositoryImpl implements PaymentMethodRepository {
  final PaymentMethodRemoteDataSource remoteDataSource;

  PaymentMethodRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<PaymentMethod>>> getPaymentMethods() async {
    try {
      final result = await remoteDataSource.getPaymentMethods();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to load payment methods'));
    } catch (e) {
      return Left(const ServerFailure('Failed to load payment methods'));
    }
  }

  @override
  Future<Either<Failure, PaymentMethod>> createPaymentMethod({
    required String name,
    required String type,
    int? settlementDay,
    int? closingDay,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'type': type,
        if (settlementDay != null) 'settlementDay': settlementDay,
        if (closingDay != null) 'closingDay': closingDay,
      };
      final result = await remoteDataSource.createPaymentMethod(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to create payment method'));
    } catch (e) {
      return Left(const ServerFailure('Failed to create payment method'));
    }
  }

  @override
  Future<Either<Failure, PaymentMethod>> updatePaymentMethod({
    required String id,
    String? name,
    int? settlementDay,
    int? closingDay,
    bool? isActive,
    int? displayOrder,
  }) async {
    try {
      final data = <String, dynamic>{
        if (name != null) 'name': name,
        if (settlementDay != null) 'settlementDay': settlementDay,
        if (closingDay != null) 'closingDay': closingDay,
        if (isActive != null) 'isActive': isActive,
        if (displayOrder != null) 'displayOrder': displayOrder,
      };
      final result = await remoteDataSource.updatePaymentMethod(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to update payment method'));
    } catch (e) {
      return Left(const ServerFailure('Failed to update payment method'));
    }
  }

  @override
  Future<Either<Failure, void>> deletePaymentMethod(String id) async {
    try {
      await remoteDataSource.deletePaymentMethod(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to delete payment method'));
    } catch (e) {
      return Left(const ServerFailure('Failed to delete payment method'));
    }
  }

  @override
  Future<Either<Failure, List<CardPending>>> getCardPending(
      int year, int month) async {
    try {
      final result = await remoteDataSource.getCardPending(year, month);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, 'Failed to load card pending info'));
    } catch (e) {
      return Left(const ServerFailure('Failed to load card pending info'));
    }
  }

}
