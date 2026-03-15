import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';

abstract class StatisticsRepository {
  Future<Either<Failure, StatisticsSummary>> getSummary({
    required int year,
    required int month,
  });

  Future<Either<Failure, List<CategoryStatistics>>> getCategoryBreakdown({
    required int year,
    required int month,
    String type = 'EXPENSE',
  });

  Future<Either<Failure, List<MonthlyTrend>>> getMonthlyTrend({
    int months = 6,
  });

  Future<Either<Failure, List<PaymentMethodStatistics>>>
      getPaymentMethodStats({
    required int year,
    required int month,
  });
}
