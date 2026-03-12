import 'package:equatable/equatable.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';

sealed class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  final int year;
  final int month;
  final StatisticsSummary? summary;
  final List<Transaction> recentTransactions;
  final BudgetSummary? budgetSummary;
  final String? summaryError;
  final String? transactionsError;
  final String? budgetError;

  const DashboardLoaded({
    required this.year,
    required this.month,
    this.summary,
    this.recentTransactions = const [],
    this.budgetSummary,
    this.summaryError,
    this.transactionsError,
    this.budgetError,
  });

  @override
  List<Object?> get props => [
        year,
        month,
        summary,
        recentTransactions,
        budgetSummary,
        summaryError,
        transactionsError,
        budgetError,
      ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
