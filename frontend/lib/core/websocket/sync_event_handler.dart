import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';

import 'sync_event.dart';

/// Routes incoming [SyncEvent]s to the appropriate feature BLoC
/// to trigger data refresh.
class SyncEventHandler {
  final GetIt _getIt;
  final Logger _logger = Logger();

  SyncEventHandler({GetIt? getIt}) : _getIt = getIt ?? GetIt.instance;

  /// Handle a sync event by dispatching refresh events to feature BLoCs.
  ///
  /// [currentUserId] is used to skip events authored by the current user,
  /// preventing duplicate updates from our own changes.
  void handle(SyncEvent event, String currentUserId) {
    // Skip events authored by self to avoid duplicate updates
    if (event.authorId == currentUserId) {
      _logger.d('Skipping self-authored sync event: ${event.entityType}');
      return;
    }

    _logger.i(
      'Handling sync event: ${event.entityType} ${event.type} '
      'from ${event.authorId}',
    );

    switch (event.entityType) {
      case 'TRANSACTION':
        _refreshTransactions();
        _refreshPaymentMethods();
        _refreshDashboard();
      case 'BUDGET':
        _refreshBudgets();
        _refreshDashboard();
      case 'CATEGORY':
        _refreshCategories();
        // 카테고리 이름/그룹 변경은 통계 breakdown·거래 목록·대시보드의
        // 카테고리 표시에 영향 → 의존 화면 함께 갱신.
        refreshCategoryDependents();
      case 'PAYMENT_METHOD':
        _refreshPaymentMethods();
      case 'CATEGORY_GROUP':
        _refreshCategoryGroups();
        // 그룹 변경은 카테고리의 그룹 표시에도 영향.
        _refreshCategories();
        refreshCategoryDependents();
      case 'POCKET':
        _refreshPockets();
        _refreshDashboard();
      case 'POCKET_TRANSFER':
        _refreshPockets();
        _refreshPocketTransfers();
        _refreshDashboard();
      case 'TRANSFER':
        // CARD_SETTLEMENT_CREATED 이벤트는 Transaction.paid_at 도 업데이트하므로
        // Transaction BLoC 도 함께 갱신 (거래내역 페이지의 미결제 표시 반영)
        _refreshTransactions();
        _refreshTransfers();
        _refreshPaymentMethods();
        _refreshDashboard();
      default:
        _logger.w('Unknown entity type: ${event.entityType}');
    }
  }

  void _refreshTransactions() {
    try {
      // 회차 12 P2 Phase A (2026-05-03) — `now.year/month` 강제 사용 회귀 fix.
      // 사용자가 보던 month (MonthCubit) 유지. 이전: partner 가 거래 추가 시
      // 사용자 4월 보는 중에도 5월로 list reset.
      final monthState = _getIt<MonthCubit>().state;
      // 회차 9 — WebSocket sync 시 currentFilter 보존. server-side 변경 시
      // list 가 필터 reset 되지 않도록.
      final bloc = _getIt<TransactionBloc>();
      // 2026-07-27 — 필드 수동 나열로 needsReviewOnly 가 빠져 파트너 변경 sync 시
      // "확인/입력 필요만 보기" 필터가 풀리던 버그 fix. fromFilter 로 VO 전체 전달.
      bloc.add(LoadTransactions.fromFilter(
        monthState.year,
        monthState.month,
        bloc.currentFilter,
      ));
      _logger.d('Dispatched LoadTransactions refresh');
    } catch (e) {
      _logger.e('Failed to refresh transactions: $e');
    }
  }

  void _refreshBudgets() {
    try {
      // 회차 12 P2 Phase A — MonthCubit 사용 (사용자가 보던 month 유지).
      final monthState = _getIt<MonthCubit>().state;
      final bloc = _getIt<BudgetBloc>();
      bloc.add(LoadBudgets(year: monthState.year, month: monthState.month));
      _logger.d('Dispatched LoadBudgets refresh');
    } catch (e) {
      _logger.e('Failed to refresh budgets: $e');
    }
  }

  void _refreshCategories() {
    try {
      final bloc = _getIt<CategoryBloc>();
      bloc.add(const LoadCategories());
      _logger.d('Dispatched LoadCategories refresh');
    } catch (e) {
      _logger.e('Failed to refresh categories: $e');
    }
  }

  void _refreshPaymentMethods() {
    try {
      final bloc = _getIt<PaymentMethodBloc>();
      bloc.add(const LoadPaymentMethods());
      _logger.d('Dispatched LoadPaymentMethods refresh');
    } catch (e) {
      _logger.e('Failed to refresh payment methods: $e');
    }
  }

  void _refreshCategoryGroups() {
    try {
      final bloc = _getIt<CategoryGroupBloc>();
      bloc.add(const LoadCategoryGroups());
      _logger.d('Dispatched LoadCategoryGroups refresh');
    } catch (e) {
      _logger.e('Failed to refresh category groups: $e');
    }
  }

  void _refreshPockets() {
    try {
      final bloc = _getIt<PocketBloc>();
      bloc.add(const LoadPockets());
      _logger.d('Dispatched LoadPockets refresh');
    } catch (e) {
      _logger.e('Failed to refresh pockets: $e');
    }
  }

  void _refreshPocketTransfers() {
    try {
      final bloc = _getIt<PocketTransferBloc>();
      bloc.add(const LoadPocketTransfers());
      _logger.d('Dispatched LoadPocketTransfers refresh');
    } catch (e) {
      _logger.e('Failed to refresh pocket transfers: $e');
    }
  }

  void _refreshTransfers() {
    try {
      // 회차 12 P2 Phase A — MonthCubit 사용.
      final monthState = _getIt<MonthCubit>().state;
      final bloc = _getIt<TransferBloc>();
      bloc.add(LoadTransfers(year: monthState.year, month: monthState.month));
      _logger.d('Dispatched LoadTransfers refresh');
    } catch (e) {
      _logger.e('Failed to refresh transfers: $e');
    }
  }

  void _refreshDashboard() {
    try {
      // 회차 12 P2 Phase A — MonthCubit 사용.
      final monthState = _getIt<MonthCubit>().state;
      final bloc = _getIt<DashboardBloc>();
      bloc.add(LoadDashboard(year: monthState.year, month: monthState.month));
      _logger.d('Dispatched LoadDashboard refresh');
    } catch (e) {
      _logger.e('Failed to refresh dashboard: $e');
    }
  }

  /// Refreshes views whose displayed data depends on category name / group /
  /// membership: statistics breakdown, transaction list, dashboard.
  ///
  /// Called both from the partner's CATEGORY / CATEGORY_GROUP sync events and
  /// locally after the user's own category/group mutation — the latter is
  /// necessary because self-authored sync events are skipped (see [handle]),
  /// and statistics has no other refresh trigger tied to category changes.
  void refreshCategoryDependents() {
    _refreshStatistics();
    _refreshTransactions();
    _refreshDashboard();
  }

  void _refreshStatistics() {
    try {
      final monthState = _getIt<MonthCubit>().state;
      final bloc = _getIt<StatisticsBloc>();
      bloc.add(LoadAllStatistics(year: monthState.year, month: monthState.month));
      bloc.add(LoadPaymentMethodStats(year: monthState.year, month: monthState.month));
      bloc.add(LoadYearComparison(year: monthState.year, month: monthState.month));
      _logger.d('Dispatched statistics refresh');
    } catch (e) {
      _logger.e('Failed to refresh statistics: $e');
    }
  }
}
