import 'package:equatable/equatable.dart';

class GroupSummary extends Equatable {
  final String groupId;
  final String groupName;
  final String budgetType;
  final int totalBudget;
  final int totalSpent;
  final double usageRate;

  const GroupSummary({
    required this.groupId,
    required this.groupName,
    required this.budgetType,
    required this.totalBudget,
    required this.totalSpent,
    required this.usageRate,
  });

  @override
  List<Object?> get props =>
      [groupId, groupName, budgetType, totalBudget, totalSpent, usageRate];
}

class TopCategory extends Equatable {
  final String categoryId;
  final String categoryName;
  final String categoryType;
  final String? categoryIcon;
  final String? categoryColor;
  final int amount;
  final int averageAmount;
  final int deviation;
  final int transactionCount;

  const TopCategory({
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

class MonthComparison extends Equatable {
  final String previousYearMonth;
  final int incomeChange;
  final int expenseChange;
  final double incomeChangeRate;
  final double expenseChangeRate;

  const MonthComparison({
    required this.previousYearMonth,
    required this.incomeChange,
    required this.expenseChange,
    required this.incomeChangeRate,
    required this.expenseChangeRate,
  });

  @override
  List<Object?> get props => [
        previousYearMonth,
        incomeChange,
        expenseChange,
        incomeChangeRate,
        expenseChangeRate,
      ];
}

class CardPendingSummary extends Equatable {
  final int totalPendingAmount;
  final int cardCount;

  const CardPendingSummary({
    required this.totalPendingAmount,
    required this.cardCount,
  });

  @override
  List<Object?> get props => [totalPendingAmount, cardCount];
}

class DayOfWeekPattern extends Equatable {
  final String dayOfWeek;
  final int averageSpending;
  final int totalSpending;
  final int transactionCount;

  const DayOfWeekPattern({
    required this.dayOfWeek,
    required this.averageSpending,
    required this.totalSpending,
    required this.transactionCount,
  });

  @override
  List<Object?> get props =>
      [dayOfWeek, averageSpending, totalSpending, transactionCount];
}

class MonthlyReport extends Equatable {
  final String yearMonth;
  final int totalIncome;
  final int totalExpense;
  final int balance;
  final List<GroupSummary> groupSummaries;
  final List<TopCategory> topCategories;
  final MonthComparison? previousMonthComparison;
  final CardPendingSummary? cardPendingSummary;
  final List<DayOfWeekPattern> dayOfWeekPattern;

  const MonthlyReport({
    required this.yearMonth,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.groupSummaries,
    required this.topCategories,
    this.previousMonthComparison,
    this.cardPendingSummary,
    required this.dayOfWeekPattern,
  });

  @override
  List<Object?> get props => [
        yearMonth,
        totalIncome,
        totalExpense,
        balance,
        groupSummaries,
        topCategories,
        previousMonthComparison,
        cardPendingSummary,
        dayOfWeekPattern,
      ];
}
