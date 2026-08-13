import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';

class StatisticsSummaryModel extends StatisticsSummary {
  const StatisticsSummaryModel({
    required super.yearMonth,
    required super.totalIncome,
    required super.totalExpense,
    super.totalTransfer,
    required super.balance,
    required super.transactionCount,
    super.transferCount,
  });

  factory StatisticsSummaryModel.fromJson(Map<String, dynamic> json) {
    return StatisticsSummaryModel(
      yearMonth: json['yearMonth'] as String,
      totalIncome: json['totalIncome'] as int,
      totalExpense: json['totalExpense'] as int,
      // 구 서버 호환 — 필드가 없으면 0.
      totalTransfer: json['totalTransfer'] as int? ?? 0,
      balance: json['balance'] as int,
      transactionCount: json['transactionCount'] as int,
      transferCount: json['transferCount'] as int? ?? 0,
    );
  }
}
