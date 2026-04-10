import 'package:equatable/equatable.dart';

class PeriodSummary extends Equatable {
  final String dateFrom;
  final String dateTo;
  final int totalIncome;
  final int totalExpense;
  final int balance;
  final List<PeriodCategoryItem> byCategory;
  final List<PeriodBudgetItem> byBudget;
  final List<PeriodPaymentMethodItem> byPaymentMethod;
  final List<PeriodDateItem> byDate;

  const PeriodSummary({
    required this.dateFrom,
    required this.dateTo,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    this.byCategory = const [],
    this.byBudget = const [],
    this.byPaymentMethod = const [],
    this.byDate = const [],
  });

  @override
  List<Object?> get props => [
        dateFrom,
        dateTo,
        totalIncome,
        totalExpense,
        balance,
        byCategory,
        byBudget,
        byPaymentMethod,
        byDate,
      ];
}

class PeriodCategoryItem extends Equatable {
  final String categoryName;
  final int amount;
  final int count;
  final double percentage;

  const PeriodCategoryItem({
    required this.categoryName,
    required this.amount,
    required this.count,
    required this.percentage,
  });

  @override
  List<Object?> get props => [categoryName, amount, count, percentage];
}

class PeriodBudgetItem extends Equatable {
  final String budgetName;
  final int budgetAmount;
  final int spent;
  final int remaining;

  const PeriodBudgetItem({
    required this.budgetName,
    required this.budgetAmount,
    required this.spent,
    required this.remaining,
  });

  @override
  List<Object?> get props => [budgetName, budgetAmount, spent, remaining];
}

class PeriodPaymentMethodItem extends Equatable {
  final String methodName;
  final int amount;
  final int count;

  const PeriodPaymentMethodItem({
    required this.methodName,
    required this.amount,
    required this.count,
  });

  @override
  List<Object?> get props => [methodName, amount, count];
}

class PeriodDateItem extends Equatable {
  final String date;
  final int income;
  final int expense;

  const PeriodDateItem({
    required this.date,
    required this.income,
    required this.expense,
  });

  @override
  List<Object?> get props => [date, income, expense];
}
