import 'package:equatable/equatable.dart';

class StatisticsSummary extends Equatable {
  final String yearMonth;
  final int totalIncome;
  final int totalExpense;
  final int balance;
  final int transactionCount;

  const StatisticsSummary({
    required this.yearMonth,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.transactionCount,
  });

  @override
  List<Object?> get props =>
      [yearMonth, totalIncome, totalExpense, balance, transactionCount];
}
