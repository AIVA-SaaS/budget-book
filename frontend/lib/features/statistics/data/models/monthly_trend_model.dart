import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';

class MonthlyTrendModel extends MonthlyTrend {
  const MonthlyTrendModel({
    required super.yearMonth,
    required super.totalIncome,
    required super.totalExpense,
    required super.balance,
  });

  factory MonthlyTrendModel.fromJson(Map<String, dynamic> json) {
    return MonthlyTrendModel(
      yearMonth: json['yearMonth'] as String,
      totalIncome: json['totalIncome'] as int,
      totalExpense: json['totalExpense'] as int,
      balance: json['balance'] as int,
    );
  }
}
