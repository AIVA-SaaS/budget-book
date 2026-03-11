import 'package:equatable/equatable.dart';

class OverspendCategory extends Equatable {
  final String categoryId;
  final String categoryName;
  final String categoryType;
  final String? categoryIcon;
  final String? categoryColor;
  final int amount;
  final int averageAmount;
  final int deviation;
  final int transactionCount;

  const OverspendCategory({
    required this.categoryId,
    required this.categoryName,
    required this.categoryType,
    this.categoryIcon,
    this.categoryColor,
    required this.amount,
    required this.averageAmount,
    required this.deviation,
    required this.transactionCount,
  });

  @override
  List<Object?> get props => [
        categoryId,
        categoryName,
        categoryType,
        categoryIcon,
        categoryColor,
        amount,
        averageAmount,
        deviation,
        transactionCount,
      ];
}

class DailySpending extends Equatable {
  final String date;
  final String dayOfWeek;
  final int amount;
  final int transactionCount;

  const DailySpending({
    required this.date,
    required this.dayOfWeek,
    required this.amount,
    required this.transactionCount,
  });

  @override
  List<Object?> get props => [date, dayOfWeek, amount, transactionCount];
}

class WeeklyReport extends Equatable {
  final String yearMonth;
  final int weekNumber;
  final String weekStart;
  final String weekEnd;
  final int totalBudget;
  final int totalSpent;
  final int remainingAmount;
  final double usageRate;
  final String status;
  final List<OverspendCategory> topOverspendCategories;
  final List<DailySpending> dailySpending;
  final String peakSpendingDay;

  const WeeklyReport({
    required this.yearMonth,
    required this.weekNumber,
    required this.weekStart,
    required this.weekEnd,
    required this.totalBudget,
    required this.totalSpent,
    required this.remainingAmount,
    required this.usageRate,
    required this.status,
    required this.topOverspendCategories,
    required this.dailySpending,
    required this.peakSpendingDay,
  });

  bool get isOver => status == 'OVER';

  @override
  List<Object?> get props => [
        yearMonth,
        weekNumber,
        weekStart,
        weekEnd,
        totalBudget,
        totalSpent,
        remainingAmount,
        usageRate,
        status,
        topOverspendCategories,
        dailySpending,
        peakSpendingDay,
      ];
}
