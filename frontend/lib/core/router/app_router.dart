import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/main_shell_page.dart';
import 'package:budget_book/core/websocket/websocket_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/auth/presentation/pages/login_page.dart';
import 'package:budget_book/features/auth/presentation/pages/auth_callback_page.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/pages/couple_page.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_list_page.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_form_page.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_import_page.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_detail_page.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/pages/budget_list_page.dart';
import 'package:budget_book/features/budget/presentation/pages/budget_form_page.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/statistics/presentation/pages/statistics_page.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/pages/category_group_page.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/pages/payment_method_page.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_bloc.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_event.dart';
import 'package:budget_book/features/weekly_budget/presentation/pages/weekly_budget_page.dart';
import 'package:budget_book/features/report/presentation/bloc/report_bloc.dart';
import 'package:budget_book/features/report/presentation/bloc/report_event.dart';
import 'package:budget_book/features/report/presentation/pages/report_page.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_bloc.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_event.dart';
import 'package:budget_book/features/recurring/presentation/pages/recurring_list_page.dart';
import 'package:budget_book/features/recurring/presentation/pages/recurring_form_page.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/home/presentation/pages/dashboard_page.dart';
import 'package:budget_book/features/settings/presentation/pages/settings_page.dart';
import 'package:budget_book/features/settings/presentation/pages/profile_edit_page.dart';
import 'package:budget_book/features/settings/presentation/pages/app_info_page.dart';
import 'package:budget_book/features/settings/presentation/pages/home_config_page.dart';
import 'package:budget_book/features/settings/presentation/pages/asset_management_page.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_event.dart';
import 'package:budget_book/features/pocket/presentation/pages/pocket_page.dart';
import 'package:budget_book/features/pocket/presentation/pages/distribute_wizard_page.dart';
import 'package:budget_book/features/pocket/presentation/pages/pocket_transfer_page.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/transfer/presentation/pages/transfer_list_page.dart';
import 'package:budget_book/features/transfer/presentation/pages/transfer_form_page.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_bloc.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_event.dart';
import 'package:budget_book/features/insurance/presentation/pages/insurance_list_page.dart';
import 'package:budget_book/features/insurance/presentation/pages/insurance_form_page.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_bloc.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_event.dart';
import 'package:budget_book/features/spending_plan/presentation/pages/spending_plan_list_page.dart';
import 'package:budget_book/features/spending_plan/presentation/pages/spending_plan_form_page.dart';
import 'package:budget_book/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:budget_book/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:budget_book/features/admin/presentation/pages/admin_users_page.dart';
import 'package:budget_book/features/admin/presentation/pages/admin_announcements_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adapts a BLoC stream into a [Listenable] for GoRouter.refreshListenable.
class _BlocListenable extends ChangeNotifier {
  late final StreamSubscription _subscription;

  _BlocListenable(Bloc bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Key used to store onboarding completion flag in SharedPreferences.
const String kOnboardingCompleted = 'onboarding_completed';

/// Cached onboarding completion flag.
/// Set by [initOnboardingFlag] at app startup.
bool _onboardingCompleted = false;

/// Must be called before [createAppRouter] to load the cached flag.
Future<void> initOnboardingFlag() async {
  final prefs = await SharedPreferences.getInstance();
  _onboardingCompleted = prefs.getBool(kOnboardingCompleted) ?? false;
}

/// Marks onboarding as completed and updates the cached flag.
/// CRITICAL: The in-memory flag MUST be set synchronously BEFORE async ops,
/// because GoRouter redirect reads it synchronously.
Future<void> markOnboardingCompleted() async {
  _onboardingCompleted = true; // Synchronous — redirect sees this immediately
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kOnboardingCompleted, true);
}

GoRouter createAppRouter(AuthBloc authBloc) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  refreshListenable: _BlocListenable(authBloc),
  redirect: (context, state) {
    final authState = authBloc.state;
    final isAuthenticated = authState is AuthAuthenticated;
    final isOnLoginPage = state.matchedLocation == '/login';
    final isOnCallbackPage = state.matchedLocation == '/auth/callback';
    final isOnCouplePage = state.matchedLocation == '/couple';
    final isOnOnboardingPage = state.matchedLocation == '/onboarding';
    final isOnAdminPage = state.matchedLocation.startsWith('/admin');

    // Allow callback page to proceed regardless of auth state
    if (isOnCallbackPage) return null;

    if (authState is AuthAuthenticated && isOnLoginPage) {
      // Server state is source of truth: if user already has a couple,
      // auto-complete onboarding (handles new-device / cleared-cache case).
      if (!_onboardingCompleted && authState.user.coupleId != null) {
        markOnboardingCompleted();
      }
      if (!_onboardingCompleted) return '/onboarding';
      return authState.user.coupleId != null ? '/home' : '/couple';
    }

    if (authState is AuthAuthenticated) {
      // Server state is source of truth: auto-complete onboarding
      // when the user already has a couple.
      if (!_onboardingCompleted && authState.user.coupleId != null) {
        markOnboardingCompleted();
      }

      // Admin guard: redirect non-admin users away from admin pages
      if (isOnAdminPage && authState.user.role != 'ADMIN') {
        return '/home';
      }

      // Allow onboarding page to pass through
      if (isOnOnboardingPage) return null;

      // If onboarding not completed, redirect to onboarding
      // (except couple page which can be accessed from onboarding)
      if (!_onboardingCompleted && !isOnCouplePage && !isOnAdminPage) {
        return '/onboarding';
      }

      // If no couple and trying to access couple-required pages, redirect to /couple
      // But allow /couple itself, /settings, and /admin to pass through
      if (authState.user.coupleId == null &&
          !isOnCouplePage &&
          !isOnAdminPage &&
          state.matchedLocation != '/settings') {
        return '/couple';
      }
      return null;
    }

    // While auth check is in progress, stay on current page (don't flash login)
    if (authState is AuthLoading || authState is AuthInitial) {
      return null;
    }

    // If not authenticated and not on login page, redirect to login
    if (!isAuthenticated && !isOnLoginPage) {
      return '/login';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/auth/callback',
      builder: (context, state) => AuthCallbackPage(
        accessToken: state.uri.queryParameters['accessToken'],
        refreshToken: state.uri.queryParameters['refreshToken'],
      ),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: '/couple',
      builder: (context, state) => BlocProvider<CoupleBloc>(
        create: (context) =>
            getIt<CoupleBloc>()..add(const LoadCouple()),
        child: const CouplePage(),
      ),
    ),
    // Main shell with bottom navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return BlocProvider<WebSocketBloc>.value(
          value: getIt<WebSocketBloc>(),
          child: MainShellPage(navigationShell: navigationShell),
        );
      },
      branches: [
        // Tab 0: Home/Dashboard
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) {
                final now = DateTime.now();
                getIt<DashboardBloc>()
                    .add(LoadDashboard(year: now.year, month: now.month));
                return BlocProvider<DashboardBloc>.value(
                  value: getIt<DashboardBloc>(),
                  child: const DashboardPage(),
                );
              },
            ),
          ],
        ),
        // Tab 1: Transactions
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) {
                final now = DateTime.now();
                final paymentMethodId = state.uri.queryParameters['paymentMethodId'];
                final paymentMethodName = state.uri.queryParameters['paymentMethodName'];
                getIt<TransactionBloc>()
                    .add(LoadTransactions(
                      year: now.year,
                      month: now.month,
                      paymentMethodId: paymentMethodId,
                    ));
                return BlocProvider<TransactionBloc>.value(
                  value: getIt<TransactionBloc>(),
                  child: TransactionListPage(
                    initialPaymentMethodId: paymentMethodId,
                    initialPaymentMethodName: paymentMethodName,
                  ),
                );
              },
            ),
          ],
        ),
        // Tab 2: Budget
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/budgets',
              builder: (context, state) {
                final now = DateTime.now();
                getIt<BudgetBloc>()
                    .add(LoadBudgets(year: now.year, month: now.month));
                return BlocProvider<BudgetBloc>.value(
                  value: getIt<BudgetBloc>(),
                  child: const BudgetListPage(),
                );
              },
            ),
          ],
        ),
        // Tab 3: Statistics
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/statistics',
              builder: (context, state) {
                final now = DateTime.now();
                return BlocProvider<StatisticsBloc>(
                  create: (_) => getIt<StatisticsBloc>()
                    ..add(LoadAllStatistics(year: now.year, month: now.month))
                    ..add(LoadPaymentMethodStats(year: now.year, month: now.month)),
                  child: const StatisticsPage(),
                );
              },
            ),
          ],
        ),
        // Tab 4: Settings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
      ],
    ),
    // Sub-pages (pushed on top of shell, no bottom nav)
    // IMPORTANT: Use BlocProvider.value() for singleton BLoCs to avoid
    // auto-close on pop which would permanently kill the singleton.
    GoRoute(
      path: '/categories',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/asset-management',
    ),
    GoRoute(
      path: '/transactions/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final type = state.uri.queryParameters['type'];
        final tab = state.uri.queryParameters['tab'];
        final copyFrom = state.extra as Transaction?;
        final dateStr = state.uri.queryParameters['date'];
        final initialPaymentMethodId = state.uri.queryParameters['paymentMethodId'];
        DateTime? initialDate;
        if (dateStr != null) {
          initialDate = DateTime.tryParse(dateStr);
        }
        getIt<CategoryBloc>().add(const LoadCategories());
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        getIt<PocketBloc>().add(const LoadPockets());
        return MultiBlocProvider(
          providers: [
            BlocProvider<TransactionBloc>.value(
              value: getIt<TransactionBloc>(),
            ),
            BlocProvider<CategoryBloc>.value(
              value: getIt<CategoryBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
            BlocProvider<PocketBloc>.value(
              value: getIt<PocketBloc>(),
            ),
            BlocProvider<TransferBloc>.value(
              value: getIt<TransferBloc>(),
            ),
          ],
          child: TransactionFormPage(
            initialType: copyFrom?.type ?? type,
            initialTab: tab,
            copyFrom: copyFrom,
            initialDate: initialDate,
            initialPaymentMethodId: initialPaymentMethodId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/transactions/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final transactionId = state.pathParameters['id']!;
        getIt<CategoryBloc>().add(const LoadCategories());
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        getIt<PocketBloc>().add(const LoadPockets());
        return MultiBlocProvider(
          providers: [
            BlocProvider<TransactionBloc>.value(
              value: getIt<TransactionBloc>(),
            ),
            BlocProvider<CategoryBloc>.value(
              value: getIt<CategoryBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
            BlocProvider<PocketBloc>.value(
              value: getIt<PocketBloc>(),
            ),
          ],
          child: TransactionFormPage(
            transactionId: transactionId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/transactions/import',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TransactionImportPage(),
    ),
    GoRoute(
      path: '/transactions/detail/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final transactionId = state.pathParameters['id']!;
        return BlocProvider<TransactionBloc>.value(
          value: getIt<TransactionBloc>(),
          child: TransactionDetailPage(transactionId: transactionId),
        );
      },
    ),
    GoRoute(
      path: '/budgets/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final year = int.tryParse(
                state.uri.queryParameters['year'] ?? '') ??
            DateTime.now().year;
        final month = int.tryParse(
                state.uri.queryParameters['month'] ?? '') ??
            DateTime.now().month;
        getIt<BudgetBloc>().add(LoadBudgets(year: year, month: month));
        getIt<CategoryBloc>().add(const LoadCategories());
        getIt<PocketBloc>().add(const LoadPockets());
        return MultiBlocProvider(
          providers: [
            BlocProvider<BudgetBloc>.value(
              value: getIt<BudgetBloc>(),
            ),
            BlocProvider<CategoryBloc>.value(
              value: getIt<CategoryBloc>(),
            ),
            BlocProvider<PocketBloc>.value(
              value: getIt<PocketBloc>(),
            ),
          ],
          child: BudgetFormPage(year: year, month: month),
        );
      },
    ),
    GoRoute(
      path: '/budgets/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final year = int.tryParse(
                state.uri.queryParameters['year'] ?? '') ??
            DateTime.now().year;
        final month = int.tryParse(
                state.uri.queryParameters['month'] ?? '') ??
            DateTime.now().month;
        getIt<BudgetBloc>().add(LoadBudgets(year: year, month: month));
        getIt<CategoryBloc>().add(const LoadCategories());
        getIt<PocketBloc>().add(const LoadPockets());
        return MultiBlocProvider(
          providers: [
            BlocProvider<BudgetBloc>.value(
              value: getIt<BudgetBloc>(),
            ),
            BlocProvider<CategoryBloc>.value(
              value: getIt<CategoryBloc>(),
            ),
            BlocProvider<PocketBloc>.value(
              value: getIt<PocketBloc>(),
            ),
          ],
          child: BudgetFormPage(
            budgetId: state.pathParameters['id'],
            year: year,
            month: month,
          ),
        );
      },
    ),
    GoRoute(
      path: '/payment-methods',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final now = DateTime.now();
        getIt<PaymentMethodBloc>()
          ..add(const LoadPaymentMethods())
          ..add(LoadCardPending(year: now.year, month: now.month));
        return BlocProvider<PaymentMethodBloc>.value(
          value: getIt<PaymentMethodBloc>(),
          child: const PaymentMethodPage(),
        );
      },
    ),
    GoRoute(
      path: '/category-groups',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
        return BlocProvider<CategoryGroupBloc>.value(
          value: getIt<CategoryGroupBloc>(),
          child: const CategoryGroupPage(),
        );
      },
    ),
    GoRoute(
      path: '/weekly-budgets',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final now = DateTime.now();
        return BlocProvider<WeeklyBudgetBloc>(
          create: (_) => getIt<WeeklyBudgetBloc>()
            ..add(LoadWeeklyOverview(year: now.year, month: now.month))
            ..add(const LoadCurrentWeek()),
          child: const WeeklyBudgetPage(),
        );
      },
    ),
    GoRoute(
      path: '/reports',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final now = DateTime.now();
        return BlocProvider<ReportBloc>(
          create: (_) => getIt<ReportBloc>()
            ..add(LoadMonthlyReport(year: now.year, month: now.month))
            ..add(LoadWeeklyReport(
                year: now.year, month: now.month, week: 1)),
          child: const ReportPage(),
        );
      },
    ),
    GoRoute(
      path: '/recurring',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => BlocProvider<RecurringBloc>(
        create: (_) =>
            getIt<RecurringBloc>()..add(const LoadRecurringTransactions()),
        child: const RecurringListPage(),
      ),
    ),
    GoRoute(
      path: '/recurring/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<CategoryBloc>().add(const LoadCategories());
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        return MultiBlocProvider(
          providers: [
            BlocProvider<RecurringBloc>(
              create: (_) => getIt<RecurringBloc>()
                ..add(const LoadRecurringTransactions()),
            ),
            BlocProvider<CategoryBloc>.value(
              value: getIt<CategoryBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
          ],
          child: const RecurringFormPage(),
        );
      },
    ),
    GoRoute(
      path: '/recurring/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final recurringId = state.pathParameters['id']!;
        getIt<CategoryBloc>().add(const LoadCategories());
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        return MultiBlocProvider(
          providers: [
            BlocProvider<RecurringBloc>(
              create: (_) => getIt<RecurringBloc>()
                ..add(const LoadRecurringTransactions()),
            ),
            BlocProvider<CategoryBloc>.value(
              value: getIt<CategoryBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
          ],
          child: RecurringFormPage(recurringId: recurringId),
        );
      },
    ),
    // Profile Edit
    GoRoute(
      path: '/settings/profile-edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProfileEditPage(),
    ),
    // Home Config
    GoRoute(
      path: '/settings/home-config',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const HomeConfigPage(),
    ),
    // App Info
    GoRoute(
      path: '/settings/app-info',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AppInfoPage(),
    ),
    // Asset Management (unified category + payment method + pocket management)
    GoRoute(
      path: '/asset-management',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<CategoryBloc>().add(const LoadCategories());
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        getIt<PocketBloc>().add(const LoadPockets());
        getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
        return MultiBlocProvider(
          providers: [
            BlocProvider<CategoryBloc>.value(
              value: getIt<CategoryBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
            BlocProvider<PocketBloc>.value(
              value: getIt<PocketBloc>(),
            ),
            BlocProvider<CategoryGroupBloc>.value(
              value: getIt<CategoryGroupBloc>(),
            ),
          ],
          child: const AssetManagementPage(),
        );
      },
    ),
    // Money Pockets
    GoRoute(
      path: '/pockets',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<PocketBloc>().add(const LoadPockets());
        return BlocProvider<PocketBloc>.value(
          value: getIt<PocketBloc>(),
          child: const PocketPage(),
        );
      },
    ),
    GoRoute(
      path: '/pockets/distribute',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<PocketBloc>().add(const LoadPockets());
        return BlocProvider<PocketBloc>.value(
          value: getIt<PocketBloc>(),
          child: const DistributeWizardPage(),
        );
      },
    ),
    GoRoute(
      path: '/pocket-transfers',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<PocketBloc>().add(const LoadPockets());
        getIt<PocketTransferBloc>().add(const LoadPocketTransfers());
        return MultiBlocProvider(
          providers: [
            BlocProvider<PocketBloc>.value(
              value: getIt<PocketBloc>(),
            ),
            BlocProvider<PocketTransferBloc>.value(
              value: getIt<PocketTransferBloc>(),
            ),
          ],
          child: const PocketTransferPage(),
        );
      },
    ),
    // Transfers (payment method to payment method)
    GoRoute(
      path: '/transfers',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final now = DateTime.now();
        getIt<TransferBloc>()
            .add(LoadTransfers(year: now.year, month: now.month));
        return BlocProvider<TransferBloc>.value(
          value: getIt<TransferBloc>(),
          child: const TransferListPage(),
        );
      },
    ),
    GoRoute(
      path: '/transfers/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        return MultiBlocProvider(
          providers: [
            BlocProvider<TransferBloc>.value(
              value: getIt<TransferBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
          ],
          child: const TransferFormPage(),
        );
      },
    ),
    GoRoute(
      path: '/transfers/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final transferId = state.pathParameters['id']!;
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        return MultiBlocProvider(
          providers: [
            BlocProvider<TransferBloc>.value(
              value: getIt<TransferBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
          ],
          child: TransferFormPage(transferId: transferId),
        );
      },
    ),
    // Spending Plans
    GoRoute(
      path: '/spending-plans',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final now = DateTime.now();
        final startDate =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        final endDate =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
        getIt<SpendingPlanBloc>().add(LoadSpendingPlans(
          startDate: startDate,
          endDate: endDate,
        ));
        return BlocProvider<SpendingPlanBloc>.value(
          value: getIt<SpendingPlanBloc>(),
          child: const SpendingPlanListPage(),
        );
      },
    ),
    GoRoute(
      path: '/spending-plans/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<CategoryBloc>().add(const LoadCategories());
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        final now = DateTime.now();
        getIt<BudgetBloc>().add(LoadBudgets(year: now.year, month: now.month));
        return MultiBlocProvider(
          providers: [
            BlocProvider<SpendingPlanBloc>.value(
              value: getIt<SpendingPlanBloc>(),
            ),
            BlocProvider<CategoryBloc>.value(
              value: getIt<CategoryBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
            BlocProvider<BudgetBloc>.value(
              value: getIt<BudgetBloc>(),
            ),
          ],
          child: const SpendingPlanFormPage(),
        );
      },
    ),
    GoRoute(
      path: '/spending-plans/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final planId = state.pathParameters['id']!;
        getIt<CategoryBloc>().add(const LoadCategories());
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        final now = DateTime.now();
        getIt<BudgetBloc>().add(LoadBudgets(year: now.year, month: now.month));
        return MultiBlocProvider(
          providers: [
            BlocProvider<SpendingPlanBloc>.value(
              value: getIt<SpendingPlanBloc>(),
            ),
            BlocProvider<CategoryBloc>.value(
              value: getIt<CategoryBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
            BlocProvider<BudgetBloc>.value(
              value: getIt<BudgetBloc>(),
            ),
          ],
          child: SpendingPlanFormPage(planId: planId),
        );
      },
    ),
    // Insurances
    GoRoute(
      path: '/insurances',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final now = DateTime.now();
        getIt<InsuranceBloc>()
          ..add(const LoadInsurances())
          ..add(LoadInsuranceSummary(year: now.year, month: now.month));
        return BlocProvider<InsuranceBloc>.value(
          value: getIt<InsuranceBloc>(),
          child: const InsuranceListPage(),
        );
      },
    ),
    GoRoute(
      path: '/insurances/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        getIt<CategoryBloc>().add(const LoadCategories());
        return MultiBlocProvider(
          providers: [
            BlocProvider<InsuranceBloc>.value(
              value: getIt<InsuranceBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
            BlocProvider<CategoryBloc>.value(
              value: getIt<CategoryBloc>(),
            ),
          ],
          child: const InsuranceFormPage(),
        );
      },
    ),
    GoRoute(
      path: '/insurances/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final insuranceId = state.pathParameters['id']!;
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        getIt<CategoryBloc>().add(const LoadCategories());
        return MultiBlocProvider(
          providers: [
            BlocProvider<InsuranceBloc>.value(
              value: getIt<InsuranceBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
            BlocProvider<CategoryBloc>.value(
              value: getIt<CategoryBloc>(),
            ),
          ],
          child: InsuranceFormPage(insuranceId: insuranceId),
        );
      },
    ),
    // Admin pages
    GoRoute(
      path: '/admin',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AdminDashboardPage(),
    ),
    GoRoute(
      path: '/admin/users',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AdminUsersPage(),
    ),
    GoRoute(
      path: '/admin/announcements',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AdminAnnouncementsPage(),
    ),
  ],
);
