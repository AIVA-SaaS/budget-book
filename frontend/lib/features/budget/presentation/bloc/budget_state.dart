import 'package:equatable/equatable.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';

sealed class BudgetState extends Equatable {
  const BudgetState();

  @override
  List<Object?> get props => [];
}

class BudgetInitial extends BudgetState {
  const BudgetInitial();
}

class BudgetLoading extends BudgetState {
  const BudgetLoading();
}

class BudgetLoaded extends BudgetState {
  final List<Budget> budgets;
  final BudgetSummary? summary;
  final int year;
  final int month;
  final String? operationError;
  final String? operationSuccess;

  const BudgetLoaded({
    required this.budgets,
    this.summary,
    required this.year,
    required this.month,
    this.operationError,
    this.operationSuccess,
  });

  int get totalBudget => summary?.totalBudget ?? 0;
  int get totalSpent => summary?.totalSpent ?? 0;

  @override
  List<Object?> get props =>
      [budgets, summary, year, month, operationError, operationSuccess];
}

class BudgetError extends BudgetState {
  final String message;

  const BudgetError(this.message);

  @override
  List<Object?> get props => [message];
}
