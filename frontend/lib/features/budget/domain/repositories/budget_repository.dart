import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';

abstract class BudgetRepository {
  Future<Either<Failure, Budget>> createBudget({
    String? categoryId,
    String? groupId,
    required String yearMonth,
    required int amount,
    String budgetPeriod = 'MONTHLY',
    int? weeklyAmount,
    String? pocketId,
    String periodType = 'MONTHLY',
    DateTime? startDate,
    DateTime? endDate,
    String? endYearMonth,
    String? rowKind,
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
    String? categoryId,
    String? groupId,
    String? yearMonth,
    String? endYearMonth,
  });

  /// Phase 23 PR-X4: 특정 월 OVERRIDE upsert (편한 가계부 패턴).
  Future<Either<Failure, Budget>> upsertMonthOverride({
    String? categoryId,
    String? groupId,
    required String yearMonth,
    required int amount,
    String budgetPeriod = 'MONTHLY',
    int? weeklyAmount,
    String? pocketId,
    String? periodType,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// [cascadeFuture] true 이면 해당 월 이후(템플릿 범위 + overrides) 모두 삭제.
  Future<Either<Failure, void>> deleteBudget(
    String id, {
    bool cascadeFuture = false,
  });

  Future<Either<Failure, BudgetSummary>> getBudgetSummary({
    required int year,
    required int month,
  });

  Future<Either<Failure, List<Budget>>> copyPreviousMonthBudgets({
    required int year,
    required int month,
  });
}
