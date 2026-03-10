import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/di/injection.dart';
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
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/statistics/presentation/pages/statistics_page.dart';

final appRouter = GoRouter(
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
      path: '/home',
      builder: (context, state) {
        final now = DateTime.now();
        return MultiBlocProvider(
          providers: [
            BlocProvider<TransactionBloc>(
              create: (_) => getIt<TransactionBloc>()
                ..add(LoadTransactions(year: now.year, month: now.month)),
            ),
          ],
          child: const TransactionListPage(),
        );
      },
    ),
    GoRoute(
      path: '/couple',
      builder: (context, state) => BlocProvider<CoupleBloc>(
        create: (context) =>
            getIt<CoupleBloc>()..add(const LoadCouple()),
        child: const CouplePage(),
      ),
    ),
    GoRoute(
      path: '/categories',
      builder: (context, state) => BlocProvider<CategoryBloc>(
        create: (context) =>
            getIt<CategoryBloc>()..add(const LoadCategories()),
        child: const CategoryPage(),
      ),
    ),
    GoRoute(
      path: '/transactions/create',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<TransactionBloc>(
            create: (_) => getIt<TransactionBloc>(),
          ),
          BlocProvider<CategoryBloc>(
            create: (_) =>
                getIt<CategoryBloc>()..add(const LoadCategories()),
          ),
        ],
        child: const TransactionFormPage(),
      ),
    ),
    GoRoute(
      path: '/transactions/edit/:id',
      builder: (context, state) {
        // The transaction will be passed via extra
        return MultiBlocProvider(
          providers: [
            BlocProvider<TransactionBloc>(
              create: (_) => getIt<TransactionBloc>(),
            ),
            BlocProvider<CategoryBloc>(
              create: (_) =>
                  getIt<CategoryBloc>()..add(const LoadCategories()),
            ),
          ],
          child: TransactionFormPage(
            transaction: state.extra as dynamic,
          ),
        );
      },
    ),
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
    GoRoute(
      path: '/budgets/create',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final year = extra?['year'] as int? ?? DateTime.now().year;
        final month = extra?['month'] as int? ?? DateTime.now().month;
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
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final budget = extra?['budget'] as Budget?;
        final year = extra?['year'] as int? ?? DateTime.now().year;
        final month = extra?['month'] as int? ?? DateTime.now().month;
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
            budget: budget,
            year: year,
            month: month,
          ),
        );
      },
    ),
  ],
);
