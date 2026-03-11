import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_overview.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/current_week_summary.dart';

abstract class WeeklyBudgetRepository {
  Future<Either<Failure, WeeklyOverview>> getWeeklyOverview(
      int year, int month);
  Future<Either<Failure, CurrentWeekSummary>> getCurrentWeekSummary();
}
