import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';

abstract class BudgetRepository {
  Future<Either<Failure, Budget>> createBudget({
    String? categoryId,
    required String yearMonth,
    required int amount,
    String budgetPeriod = 'MONTHLY',
    int? weeklyAmount,
    String? pocketId,
    String periodType = 'MONTHLY',
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Either<Failure, List<Budget>>> getBudgets({
    required int year,
    required int month,
  });

  Future<Either<Failure, Budget>> updateBudget({
    required String id,
    required int amount,
    String? budgetPeriod,
    int? weeklyAmount,
    String? pocketId,
    String? periodType,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Either<Failure, void>> deleteBudget(String id);

  Future<Either<Failure, BudgetSummary>> getBudgetSummary({
    required int year,
    required int month,
  });

  Future<Either<Failure, List<Budget>>> copyPreviousMonthBudgets({
    required int year,
    required int month,
  });
}
