import 'package:equatable/equatable.dart';

sealed class BudgetEvent extends Equatable {
  const BudgetEvent();

  @override
  List<Object?> get props => [];
}

class LoadBudgets extends BudgetEvent {
  final int year;
  final int month;

  const LoadBudgets({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class LoadBudgetSummary extends BudgetEvent {
  final int year;
  final int month;

  const LoadBudgetSummary({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class CreateBudget extends BudgetEvent {
  final String? categoryId;
  final String yearMonth;
  final int amount;
  final String budgetPeriod;
  final int? weeklyAmount;
  final String? pocketId;

  const CreateBudget({
    this.categoryId,
    required this.yearMonth,
    required this.amount,
    this.budgetPeriod = 'MONTHLY',
    this.weeklyAmount,
    this.pocketId,
  });

  @override
  List<Object?> get props =>
      [categoryId, yearMonth, amount, budgetPeriod, weeklyAmount, pocketId];
}

class UpdateBudget extends BudgetEvent {
  final String id;
  final int amount;
  final String? budgetPeriod;
  final int? weeklyAmount;
  final String? pocketId;

  const UpdateBudget({
    required this.id,
    required this.amount,
    this.budgetPeriod,
    this.weeklyAmount,
    this.pocketId,
  });

  @override
  List<Object?> get props => [id, amount, budgetPeriod, weeklyAmount, pocketId];
}

class DeleteBudget extends BudgetEvent {
  final String id;

  const DeleteBudget(this.id);

  @override
  List<Object?> get props => [id];
}

class CopyPreviousMonthBudgets extends BudgetEvent {
  final int year;
  final int month;

  const CopyPreviousMonthBudgets({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}
