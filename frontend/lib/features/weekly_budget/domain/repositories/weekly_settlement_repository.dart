import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/weekly_budget/domain/entities/weekly_settlement.dart';

abstract class WeeklySettlementRepository {
  Future<Either<Failure, WeeklySettlementOverview>> getSettlements(
      int year, int month);
  Future<Either<Failure, void>> settle(List<String> budgetIds, int weekNumber);
  Future<Either<Failure, void>> unsettle(
      List<String> budgetIds, int weekNumber);
}
