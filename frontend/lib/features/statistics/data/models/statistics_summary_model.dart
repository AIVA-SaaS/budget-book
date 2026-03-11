import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';

class StatisticsSummaryModel extends StatisticsSummary {
  const StatisticsSummaryModel({
    required super.yearMonth,
    required super.totalIncome,
    required super.totalExpense,
    required super.balance,
    required super.transactionCount,
  });

  factory StatisticsSummaryModel.fromJson(Map<String, dynamic> json) {
    return StatisticsSummaryModel(
      yearMonth: json['yearMonth'] as String,
      totalIncome: json['totalIncome'] as int,
      totalExpense: json['totalExpense'] as int,
      balance: json['balance'] as int,
      transactionCount: json['transactionCount'] as int,
    );
  }
}
