import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/budget/domain/repositories/budget_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final StatisticsRepository statisticsRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;

  DashboardBloc({
    required this.statisticsRepository,
    required this.transactionRepository,
    required this.budgetRepository,
  }) : super(const DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard);
  }

  Future<void> _onLoadDashboard(
    LoadDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoading());

    // Load all data in parallel
    final futureResults = await Future.wait<dynamic>([
      statisticsRepository.getSummary(
        year: event.year,
        month: event.month,
      ),
      transactionRepository.getTransactions(
        year: event.year,
        month: event.month,
        size: 5,
      ),
      budgetRepository.getBudgetSummary(
        year: event.year,
        month: event.month,
      ),
    ]);

    final summaryResult =
        futureResults[0] as Either<Failure, StatisticsSummary>;
    final transactionResult =
        futureResults[1] as Either<Failure, PageResponse<Transaction>>;
    final budgetResult =
        futureResults[2] as Either<Failure, BudgetSummary>;

    StatisticsSummary? summary;
    String? summaryError;
    List<Transaction> recentTransactions = [];
    String? transactionsError;
    BudgetSummary? budgetSummary;
    String? budgetError;

    summaryResult.fold(
      (failure) => summaryError = failure.message,
      (data) => summary = data,
    );

    transactionResult.fold(
      (failure) => transactionsError = failure.message,
      (page) => recentTransactions = page.content,
    );

    budgetResult.fold(
      (failure) => budgetError = failure.message,
      (data) => budgetSummary = data,
    );

    emit(DashboardLoaded(
      year: event.year,
      month: event.month,
      summary: summary,
      recentTransactions: recentTransactions,
      budgetSummary: budgetSummary,
      summaryError: summaryError,
      transactionsError: transactionsError,
      budgetError: budgetError,
    ));
  }
}
