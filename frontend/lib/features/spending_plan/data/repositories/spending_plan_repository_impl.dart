import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/spending_plan/data/datasources/spending_plan_remote_datasource.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';
import 'package:budget_book/features/spending_plan/domain/repositories/spending_plan_repository.dart';

class SpendingPlanRepositoryImpl implements SpendingPlanRepository {
  final SpendingPlanRemoteDataSource remoteDataSource;

  SpendingPlanRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, SpendingPlanListResponse>> getSpendingPlans({
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    try {
      final result = await remoteDataSource.getSpendingPlans(
        startDate: startDate,
        endDate: endDate,
        status: status,
      );
      return Right(SpendingPlanListResponse(
        plans: result.plans,
        summary: result.summary,
      ));
    } on DioException catch (e) {
      return Left(mapDioError(e, '지출 계획을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('지출 계획을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, SpendingPlan>> createSpendingPlan({
    required String name,
    required int amount,
    required String targetDate,
    String? memo,
    String? categoryId,
    String? paymentMethodId,
    String? budgetId,
    bool isRecurring = false,
    String? frequency,
    String visibility = 'SHARED',
    String? status,
    String? priority,
    int? estimatedMin,
    int? estimatedMax,
    String? tags,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'amount': amount,
        'isRecurring': isRecurring,
        'visibility': visibility,
        if (status != null) 'status': status,
        // targetDate is required for PLANNED but not for WISHLIST
        if (status != 'WISHLIST' && targetDate.isNotEmpty) 'targetDate': targetDate,
        if (memo != null) 'memo': memo,
        if (categoryId != null) 'categoryId': categoryId,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        if (budgetId != null) 'budgetId': budgetId,
        if (frequency != null) 'frequency': frequency,
        if (priority != null) 'priority': priority,
        if (estimatedMin != null) 'estimatedMin': estimatedMin,
        if (estimatedMax != null) 'estimatedMax': estimatedMax,
        if (tags != null) 'tags': tags,
      };
      final result = await remoteDataSource.createSpendingPlan(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '지출 계획을 등록하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('지출 계획을 등록하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, SpendingPlan>> updateSpendingPlan({
    required String id,
    String? name,
    int? amount,
    String? targetDate,
    String? memo,
    bool clearMemo = false,
    String? categoryId,
    bool clearCategoryId = false,
    String? paymentMethodId,
    bool clearPaymentMethodId = false,
    String? budgetId,
    bool clearBudgetId = false,
    bool? isRecurring,
    String? frequency,
    bool clearFrequency = false,
    String? visibility,
  }) async {
    try {
      final data = <String, dynamic>{
        if (name != null) 'name': name,
        if (amount != null) 'amount': amount,
        if (targetDate != null) 'targetDate': targetDate,
        if (memo != null)
          'memo': memo
        else if (clearMemo)
          'memo': null,
        if (categoryId != null)
          'categoryId': categoryId
        else if (clearCategoryId)
          'categoryId': null,
        if (paymentMethodId != null)
          'paymentMethodId': paymentMethodId
        else if (clearPaymentMethodId)
          'paymentMethodId': null,
        if (budgetId != null)
          'budgetId': budgetId
        else if (clearBudgetId)
          'budgetId': null,
        if (isRecurring != null) 'isRecurring': isRecurring,
        if (frequency != null)
          'frequency': frequency
        else if (clearFrequency)
          'frequency': null,
        if (visibility != null) 'visibility': visibility,
      };
      final result = await remoteDataSource.updateSpendingPlan(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '지출 계획을 수정하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('지출 계획을 수정하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSpendingPlan(String id) async {
    try {
      await remoteDataSource.deleteSpendingPlan(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, '지출 계획을 삭제하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('지출 계획을 삭제하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, SpendingPlan>> completePlan({
    required String id,
    String? transactionId,
    int? actualAmount,
  }) async {
    try {
      final data = <String, dynamic>{
        if (transactionId != null) 'transactionId': transactionId,
        if (actualAmount != null) 'actualAmount': actualAmount,
      };
      final result = await remoteDataSource.completePlan(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '계획 완료 처리에 실패했습니다'));
    } catch (e) {
      return const Left(ServerFailure('계획 완료 처리에 실패했습니다'));
    }
  }

  @override
  Future<Either<Failure, SpendingPlan>> skipPlan(String id) async {
    try {
      final result = await remoteDataSource.skipPlan(id);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '계획 건너뛰기에 실패했습니다'));
    } catch (e) {
      return const Left(ServerFailure('계획 건너뛰기에 실패했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<SpendingPlanSuggestion>>> getSuggestions({
    String? categoryId,
    int? amount,
    String? date,
  }) async {
    try {
      final result = await remoteDataSource.getSuggestions(
        categoryId: categoryId,
        amount: amount,
        date: date,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '계획 제안을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('계획 제안을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<SpendingPlan>>> getWishlist() async {
    try {
      final result = await remoteDataSource.getWishlist();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '구매 목록을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('구매 목록을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, SpendingPlan>> assignPlan({
    required String id,
    required String targetDate,
    int? weekNumber,
    String? budgetId,
  }) async {
    try {
      final result = await remoteDataSource.assignPlan(
        id,
        targetDate: targetDate,
        weekNumber: weekNumber,
        budgetId: budgetId,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '계획 배정에 실패했습니다'));
    } catch (e) {
      return const Left(ServerFailure('계획 배정에 실패했습니다'));
    }
  }

  @override
  Future<Either<Failure, SpendingPlan>> completeWithTransaction({
    required String id,
    required int amount,
    required String transactionDate,
    String? description,
    String? categoryId,
    String? paymentMethodId,
  }) async {
    try {
      final result = await remoteDataSource.completeWithTransaction(
        id,
        amount: amount,
        transactionDate: transactionDate,
        description: description,
        categoryId: categoryId,
        paymentMethodId: paymentMethodId,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '계획 완료 처리에 실패했습니다'));
    } catch (e) {
      return const Left(ServerFailure('계획 완료 처리에 실패했습니다'));
    }
  }

  @override
  Future<Either<Failure, SpendingPlan>> linkTransaction({
    required String id,
    required String transactionId,
  }) async {
    try {
      final result = await remoteDataSource.linkTransaction(
        id,
        transactionId: transactionId,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '거래 연결에 실패했습니다'));
    } catch (e) {
      return const Left(ServerFailure('거래 연결에 실패했습니다'));
    }
  }

  @override
  Future<Either<Failure, SpendingPlan>> unlinkTransaction(String id) async {
    try {
      final result = await remoteDataSource.unlinkTransaction(id);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '거래 연결 해제에 실패했습니다'));
    } catch (e) {
      return const Left(ServerFailure('거래 연결 해제에 실패했습니다'));
    }
  }
}
