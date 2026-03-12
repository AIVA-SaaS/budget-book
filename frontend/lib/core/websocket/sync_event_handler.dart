import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

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
      case 'BUDGET':
        _refreshBudgets();
      case 'CATEGORY':
        _refreshCategories();
      case 'PAYMENT_METHOD':
        _refreshPaymentMethods();
      case 'CATEGORY_GROUP':
        _refreshCategoryGroups();
      default:
        _logger.w('Unknown entity type: ${event.entityType}');
    }
  }

  void _refreshTransactions() {
    try {
      final now = DateTime.now();
      final bloc = _getIt<TransactionBloc>();
      bloc.add(LoadTransactions(year: now.year, month: now.month));
      _logger.d('Dispatched LoadTransactions refresh');
    } catch (e) {
      _logger.e('Failed to refresh transactions: $e');
    }
  }

  void _refreshBudgets() {
    try {
      final now = DateTime.now();
      final bloc = _getIt<BudgetBloc>();
      bloc.add(LoadBudgets(year: now.year, month: now.month));
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
}
