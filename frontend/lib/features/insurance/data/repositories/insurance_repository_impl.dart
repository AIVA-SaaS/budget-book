import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/insurance/data/datasources/insurance_remote_datasource.dart';
import 'package:budget_book/features/insurance/domain/entities/insurance.dart';
import 'package:budget_book/features/insurance/domain/repositories/insurance_repository.dart';

class InsuranceRepositoryImpl implements InsuranceRepository {
  final InsuranceRemoteDataSource remoteDataSource;

  InsuranceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Insurance>>> getInsurances({
    bool? active,
  }) async {
    try {
      final result = await remoteDataSource.getInsurances(active: active);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '보험 목록을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('보험 목록을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, Insurance>> createInsurance({
    required String name,
    String? insurer,
    required String insuranceType,
    required int premiumAmount,
    int? paymentDay,
    String? paymentCycle,
    String? paymentMethodId,
    String? categoryId,
    String? startDate,
    String? endDate,
    String? memo,
    String? visibility,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'insuranceType': insuranceType,
        'premiumAmount': premiumAmount,
        if (insurer != null) 'insurer': insurer,
        if (paymentDay != null) 'paymentDay': paymentDay,
        if (paymentCycle != null) 'paymentCycle': paymentCycle,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        if (categoryId != null) 'categoryId': categoryId,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (memo != null) 'memo': memo,
        if (visibility != null) 'visibility': visibility,
      };
      final result = await remoteDataSource.createInsurance(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '보험을 등록하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('보험을 등록하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, Insurance>> updateInsurance({
    required String id,
    String? name,
    String? insurer,
    bool clearInsurer = false,
    String? insuranceType,
    int? premiumAmount,
    int? paymentDay,
    bool clearPaymentDay = false,
    String? paymentCycle,
    String? paymentMethodId,
    bool clearPaymentMethodId = false,
    String? categoryId,
    bool clearCategoryId = false,
    String? startDate,
    bool clearStartDate = false,
    String? endDate,
    bool clearEndDate = false,
    String? memo,
    bool clearMemo = false,
    bool? isActive,
    String? visibility,
  }) async {
    try {
      final data = <String, dynamic>{
        if (name != null) 'name': name,
        if (insurer != null)
          'insurer': insurer
        else if (clearInsurer)
          'insurer': null,
        if (insuranceType != null) 'insuranceType': insuranceType,
        if (premiumAmount != null) 'premiumAmount': premiumAmount,
        if (paymentDay != null)
          'paymentDay': paymentDay
        else if (clearPaymentDay)
          'paymentDay': null,
        if (paymentCycle != null) 'paymentCycle': paymentCycle,
        if (paymentMethodId != null)
          'paymentMethodId': paymentMethodId
        else if (clearPaymentMethodId)
          'paymentMethodId': null,
        if (categoryId != null)
          'categoryId': categoryId
        else if (clearCategoryId)
          'categoryId': null,
        if (startDate != null)
          'startDate': startDate
        else if (clearStartDate)
          'startDate': null,
        if (endDate != null)
          'endDate': endDate
        else if (clearEndDate)
          'endDate': null,
        if (memo != null)
          'memo': memo
        else if (clearMemo)
          'memo': null,
        if (isActive != null) 'isActive': isActive,
        if (visibility != null) 'visibility': visibility,
      };
      final result = await remoteDataSource.updateInsurance(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '보험을 수정하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('보험을 수정하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInsurance(String id) async {
    try {
      await remoteDataSource.deleteInsurance(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, '보험을 삭제하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('보험을 삭제하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, InsuranceSummary>> getInsuranceSummary({
    required int year,
    required int month,
  }) async {
    try {
      final result = await remoteDataSource.getInsuranceSummary(
        year: year,
        month: month,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '보험 요약을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('보험 요약을 불러오지 못했습니다'));
    }
  }
}
