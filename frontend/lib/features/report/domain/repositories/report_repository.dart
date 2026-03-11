import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/report/domain/entities/weekly_report.dart';
import 'package:budget_book/features/report/domain/entities/monthly_report.dart';

abstract class ReportRepository {
  Future<Either<Failure, WeeklyReport>> getWeeklyReport(
      int year, int month, int week);
  Future<Either<Failure, MonthlyReport>> getMonthlyReport(int year, int month);
}
