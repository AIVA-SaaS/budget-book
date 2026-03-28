import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';

/// Response containing both plans list and summary for a date range.
class SpendingPlanListResponse {
  final List<SpendingPlan> plans;
  final SpendingPlanSummary summary;

  const SpendingPlanListResponse({
    required this.plans,
    required this.summary,
  });
}

abstract class SpendingPlanRepository {
  Future<Either<Failure, SpendingPlanListResponse>> getSpendingPlans({
    String? startDate,
    String? endDate,
    String? status,
  });

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
  });

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
  });

  Future<Either<Failure, void>> deleteSpendingPlan(String id);

  Future<Either<Failure, SpendingPlan>> completePlan({
    required String id,
    String? transactionId,
    int? actualAmount,
  });

  Future<Either<Failure, SpendingPlan>> skipPlan(String id);

  Future<Either<Failure, List<SpendingPlanSuggestion>>> getSuggestions({
    String? categoryId,
    int? amount,
    String? date,
  });
}
