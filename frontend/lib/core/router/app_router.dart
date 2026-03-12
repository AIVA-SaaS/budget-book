import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/main_shell_page.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/auth/presentation/pages/login_page.dart';
import 'package:budget_book/features/auth/presentation/pages/auth_callback_page.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/pages/couple_page.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/category/presentation/pages/category_page.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_list_page.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_form_page.dart';
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
import 'package:budget_book/core/websocket/websocket_bloc.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated = authState is AuthAuthenticated;
    final isOnLoginPage = state.matchedLocation == '/login';
    final isOnCallbackPage = state.matchedLocation == '/auth/callback';
    final isOnCouplePage = state.matchedLocation == '/couple';

    // Allow callback page to proceed regardless of auth state
    if (isOnCallbackPage) return null;

    if (authState is AuthAuthenticated && isOnLoginPage) {
      // Check if user has a couple
      return authState.user.coupleId != null ? '/home' : '/couple';
    }

    if (authState is AuthAuthenticated) {
      // If no couple and trying to access couple-required pages, redirect to /couple
      if (authState.user.coupleId == null && !isOnCouplePage) {
        return '/couple';
      }
      return null;
    }

    // If not authenticated and not on login page, go to login
    if (!isAuthenticated && !isOnLoginPage) {
      // Allow initial/loading states to proceed without redirecting
      if (authState is AuthInitial || authState is AuthLoading) return null;
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
                return BlocProvider<DashboardBloc>(
                  create: (_) => getIt<DashboardBloc>()
                    ..add(LoadDashboard(year: now.year, month: now.month)),
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
                return BlocProvider<TransactionBloc>(
                  create: (_) => getIt<TransactionBloc>()
                    ..add(LoadTransactions(year: now.year, month: now.month)),
                  child: const TransactionListPage(),
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
                return BlocProvider<BudgetBloc>(
                  create: (_) => getIt<BudgetBloc>()
                    ..add(LoadBudgets(year: now.year, month: now.month)),
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
                    ..add(LoadAllStatistics(year: now.year, month: now.month)),
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
    GoRoute(
      path: '/categories',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => BlocProvider<CategoryBloc>(
        create: (context) =>
            getIt<CategoryBloc>()..add(const LoadCategories()),
        child: const CategoryPage(),
      ),
    ),
    GoRoute(
      path: '/transactions/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<TransactionBloc>(
            create: (_) => getIt<TransactionBloc>(),
          ),
          BlocProvider<CategoryBloc>(
            create: (_) =>
                getIt<CategoryBloc>()..add(const LoadCategories()),
          ),
          BlocProvider<PaymentMethodBloc>(
            create: (_) =>
                getIt<PaymentMethodBloc>()..add(const LoadPaymentMethods()),
          ),
        ],
        child: const TransactionFormPage(),
      ),
    ),
    GoRoute(
      path: '/transactions/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final transactionId = state.pathParameters['id']!;
        return MultiBlocProvider(
          providers: [
            BlocProvider<TransactionBloc>(
              create: (_) => getIt<TransactionBloc>(),
            ),
            BlocProvider<CategoryBloc>(
              create: (_) =>
                  getIt<CategoryBloc>()..add(const LoadCategories()),
            ),
            BlocProvider<PaymentMethodBloc>(
              create: (_) =>
                  getIt<PaymentMethodBloc>()..add(const LoadPaymentMethods()),
            ),
          ],
          child: TransactionFormPage(
            transactionId: transactionId,
          ),
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
        return MultiBlocProvider(
          providers: [
            BlocProvider<BudgetBloc>(
              create: (_) => getIt<BudgetBloc>()
                ..add(LoadBudgets(year: year, month: month)),
            ),
            BlocProvider<CategoryBloc>(
              create: (_) =>
                  getIt<CategoryBloc>()..add(const LoadCategories()),
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
        return MultiBlocProvider(
          providers: [
            BlocProvider<BudgetBloc>(
              create: (_) => getIt<BudgetBloc>()
                ..add(LoadBudgets(year: year, month: month)),
            ),
            BlocProvider<CategoryBloc>(
              create: (_) =>
                  getIt<CategoryBloc>()..add(const LoadCategories()),
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
        return BlocProvider<PaymentMethodBloc>(
          create: (context) => getIt<PaymentMethodBloc>()
            ..add(const LoadPaymentMethods())
            ..add(LoadCardPending(year: now.year, month: now.month)),
          child: const PaymentMethodPage(),
        );
      },
    ),
    GoRoute(
      path: '/category-groups',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => BlocProvider<CategoryGroupBloc>(
        create: (context) =>
            getIt<CategoryGroupBloc>()..add(const LoadCategoryGroups()),
        child: const CategoryGroupPage(),
      ),
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
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<RecurringBloc>(
            create: (_) =>
                getIt<RecurringBloc>()..add(const LoadRecurringTransactions()),
          ),
          BlocProvider<CategoryBloc>(
            create: (_) =>
                getIt<CategoryBloc>()..add(const LoadCategories()),
          ),
          BlocProvider<PaymentMethodBloc>(
            create: (_) =>
                getIt<PaymentMethodBloc>()..add(const LoadPaymentMethods()),
          ),
        ],
        child: const RecurringFormPage(),
      ),
    ),
    GoRoute(
      path: '/recurring/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final recurringId = state.pathParameters['id']!;
        return MultiBlocProvider(
          providers: [
            BlocProvider<RecurringBloc>(
              create: (_) => getIt<RecurringBloc>()
                ..add(const LoadRecurringTransactions()),
            ),
            BlocProvider<CategoryBloc>(
              create: (_) =>
                  getIt<CategoryBloc>()..add(const LoadCategories()),
            ),
            BlocProvider<PaymentMethodBloc>(
              create: (_) =>
                  getIt<PaymentMethodBloc>()..add(const LoadPaymentMethods()),
            ),
          ],
          child: RecurringFormPage(recurringId: recurringId),
        );
      },
    ),
  ],
);
