import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/budget/domain/repositories/budget_repository.dart';
import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';
import 'package:budget_book/features/reconciliation/domain/repositories/reconciliation_repository.dart';
import 'package:budget_book/features/home/data/home_config_service.dart';
import 'package:budget_book/features/home/domain/entities/dashboard_widget_config.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final StatisticsRepository statisticsRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;
  final ReconciliationRepository reconciliationRepository;

  DashboardBloc({
    required this.statisticsRepository,
    required this.transactionRepository,
    required this.budgetRepository,
    required this.reconciliationRepository,
  }) : super(const DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard);
  }

  /// Whether the month-end review widget is switched on.
  ///
  /// The summary endpoint scans a whole month of transactions + transfers, so it
  /// is only worth calling when the card is actually rendered. The widget ships
  /// default OFF, meaning most users pay nothing for this feature.
  Future<bool> _isReconciliationWidgetEnabled() async {
    try {
      final configs = await HomeConfigService().loadConfig();
      return configs
          .any((c) => c.id == kReconciliationWidgetId && c.enabled);
    } catch (_) {
      return false;
    }
  }

  Future<int> _getRecentCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Search for any key ending with _dashboard_recent_count
      final keys = prefs.getKeys().where((k) => k.endsWith('_dashboard_recent_count'));
      if (keys.isNotEmpty) {
        final val = prefs.getString(keys.first);
        if (val != null) return int.tryParse(val) ?? 5;
      }
    } catch (_) {}
    return 5;
  }

  Future<void> _onLoadDashboard(
    LoadDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      // 회차 12 follow-up — race fix. 기존 Loaded 가 있으면 Loading skip.
      if (state is! DashboardLoaded) {
        emit(const DashboardLoading());
      }

      // Gate the reconciliation call on the widget being enabled (see
      // _isReconciliationWidgetEnabled). Resolved before Future.wait so the
      // request joins the same parallel batch instead of running after it.
      final wantsReconciliation = await _isReconciliationWidgetEnabled();

      // Load all data in parallel
      final futureResults = await Future.wait<dynamic>([
        statisticsRepository.getSummary(
          year: event.year,
          month: event.month,
        ),
        transactionRepository.getTransactions(
          year: event.year,
          month: event.month,
          size: await _getRecentCount(),
        ),
        budgetRepository.getBudgetSummary(
          year: event.year,
          month: event.month,
        ),
        statisticsRepository.getPaymentMethodStats(
          year: event.year,
          month: event.month,
        ),
        statisticsRepository.getMonthlyTrend(months: 6),
        statisticsRepository.getCategoryBreakdown(
          year: event.year,
          month: event.month,
          type: 'EXPENSE',
        ),
        if (wantsReconciliation)
          reconciliationRepository.getSummary(
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
      final pmStatsResult =
          futureResults[3] as Either<Failure, List<PaymentMethodStatistics>>;
      final trendResult =
          futureResults[4] as Either<Failure, List<MonthlyTrend>>;
      final categoryResult =
          futureResults[5] as Either<Failure, List<CategoryStatistics>>;
      // Index 6 exists only when the widget is on — the list is built with a
      // collection-if above, so never index it unconditionally.
      final reconciliationResult = wantsReconciliation
          ? futureResults[6] as Either<Failure, ReconciliationSummary>
          : null;

      StatisticsSummary? summary;
      String? summaryError;
      List<Transaction> recentTransactions = [];
      String? transactionsError;
      BudgetSummary? budgetSummary;
      String? budgetError;
      List<PaymentMethodStatistics> pmStats = [];
      List<MonthlyTrend> monthlyTrends = [];
      List<CategoryStatistics> categoryStats = [];

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

      pmStatsResult.fold(
        (failure) => {}, // silently ignore
        (data) => pmStats = data,
      );

      trendResult.fold(
        (failure) => {}, // silently ignore - widget won't show
        (data) => monthlyTrends = data,
      );

      categoryResult.fold(
        (failure) => {}, // silently ignore - widget won't show
        (data) => categoryStats = data,
      );

      ReconciliationSummary? reconciliationSummary;
      reconciliationResult?.fold(
        (failure) => {}, // silently ignore - widget won't show
        (data) => reconciliationSummary = data,
      );

      emit(DashboardLoaded(
        year: event.year,
        month: event.month,
        summary: summary,
        recentTransactions: recentTransactions,
        budgetSummary: budgetSummary,
        paymentMethodStats: pmStats,
        monthlyTrends: monthlyTrends,
        categoryStats: categoryStats,
        reconciliationSummary: reconciliationSummary,
        summaryError: summaryError,
        transactionsError: transactionsError,
        budgetError: budgetError,
      ));
    } catch (_) {
      emit(const DashboardError('예기치 않은 오류가 발생했습니다'));
    }
  }
}
