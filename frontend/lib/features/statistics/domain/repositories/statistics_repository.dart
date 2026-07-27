import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/period_summary.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';

abstract class StatisticsRepository {
  /// 회차 8 — 모든 필터 지원으로 확장. BE 가 정확한 (filtered) 월 합계 반환.
  /// FE 는 client-side fold 대신 이 응답 그대로 사용해야 한다.
  /// 월 합계. 필터는 거래 목록과 **동일한** [TransactionFilter] VO 로 받는다
  /// (목록과 합계가 서로 다른 필터로 계산되면 "합계 ≠ 행" 불일치가 발생).
  Future<Either<Failure, StatisticsSummary>> getSummary({
    required int year,
    required int month,
    TransactionFilter filter = TransactionFilter.empty,
  });

  Future<Either<Failure, List<CategoryStatistics>>> getCategoryBreakdown({
    required int year,
    required int month,
    String type = 'EXPENSE',
    String visibility = 'ALL',
    String? dateFrom,
    String? dateTo,
  });

  Future<Either<Failure, List<MonthlyTrend>>> getMonthlyTrend({
    int months = 6,
    String visibility = 'ALL',
  });

  Future<Either<Failure, List<PaymentMethodStatistics>>>
      getPaymentMethodStats({
    required int year,
    required int month,
    String visibility = 'ALL',
    String? dateFrom,
    String? dateTo,
  });

  Future<Either<Failure, PeriodSummary>> getPeriodSummary({
    required String dateFrom,
    required String dateTo,
    String? categoryId,
    Set<String> categoryIds = const {},
    Set<String> categoryGroupIds = const {},
    String? paymentMethodId,
    Set<String> paymentMethodIds = const {},
    String? pocketId,
    Set<String> pocketIds = const {},
  });
}
