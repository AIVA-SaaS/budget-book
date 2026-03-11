import 'package:equatable/equatable.dart';

class MonthlyTrend extends Equatable {
  final String yearMonth;
  final int totalIncome;
  final int totalExpense;
  final int balance;

  const MonthlyTrend({
    required this.yearMonth,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  @override
  List<Object?> get props => [yearMonth, totalIncome, totalExpense, balance];
}
