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
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_list_page.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_form_page.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_import_page.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_detail_page.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/pages/budget_form_page.dart';
import 'package:budget_book/features/analysis/presentation/pages/analysis_page.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_event.dart';
import 'package:budget_book/features/statistics/presentation/pages/period_summary_page.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/pages/category_group_page.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/pages/payment_method_page.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_bloc.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_event.dart';
import 'package:budget_book/features/weekly_budget/presentation/pages/weekly_budget_page.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_settlement_bloc.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_settlement_event.dart';
import 'package:budget_book/features/weekly_budget/presentation/pages/weekly_settlement_page.dart';
import 'package:budget_book/features/report/presentation/bloc/report_bloc.dart';
import 'package:budget_book/features/report/presentation/bloc/report_event.dart';
import 'package:budget_book/features/report/presentation/pages/report_page.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_bloc.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_event.dart';
import 'package:budget_book/features/recurring/presentation/pages/recurring_list_page.dart';
import 'package:budget_book/features/recurring/presentation/pages/recurring_form_page.dart';
import 'package:budget_book/features/settings/presentation/pages/settings_page.dart';
import 'package:budget_book/features/settings/presentation/pages/profile_edit_page.dart';
import 'package:budget_book/features/settings/presentation/pages/app_info_page.dart';
import 'package:budget_book/features/settings/presentation/pages/home_config_page.dart';
import 'package:budget_book/features/settings/presentation/pages/asset_management_page.dart';
import 'package:budget_book/features/settings/presentation/pages/partner_management_page.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_event.dart';
import 'package:budget_book/features/pocket/presentation/pages/pocket_page.dart';
import 'package:budget_book/features/pocket/presentation/pages/distribute_wizard_page.dart';
import 'package:budget_book/features/pocket/presentation/pages/pocket_transfer_page.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_state.dart';
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
import 'package:budget_book/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_event.dart';
import 'package:budget_book/features/feedback/presentation/pages/feedback_hub_page.dart';
import 'package:budget_book/features/feedback/presentation/pages/feedback_create_page.dart';
import 'package:budget_book/features/feedback/presentation/pages/feedback_detail_page.dart';
import 'package:budget_book/features/feedback/presentation/pages/release_note_detail_page.dart';
import 'package:budget_book/features/feedback/presentation/pages/admin_feedback_page.dart';
import 'package:budget_book/features/feedback/presentation/pages/admin_release_note_page.dart';
import 'package:budget_book/features/card_settlement/presentation/bloc/card_settlement_bloc.dart';
import 'package:budget_book/features/card_settlement/presentation/pages/card_settlement_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adapts an [AuthBloc] stream into a [Listenable] for
/// GoRouter.refreshListenable.
///
/// IMPORTANT: only notifies on authentication-toggle transitions
/// (authenticated <-> unauthenticated). Re-emitting the same authentication
/// group with a different user payload (e.g. profile/nickname/image update)
/// does NOT trigger a router refresh.
///
/// Reason: notifying on every AuthBloc emit causes GoRouter to rebuild its
/// routerDelegate. When that rebuild races against an in-flight `context.pop()`
/// inside a BlocListener (both fire from the same stream emit), the rebuild
/// can re-apply the pre-pop RouteMatchList — the URL never updates and the
/// previous page is restored ("save → settings flashes in → profile-edit slides
/// back over it" regression).
///
/// The router only cares about coarse auth toggles for its redirect logic;
/// fine-grained user-data changes are not relevant to navigation.
class _BlocListenable extends ChangeNotifier {
  late final StreamSubscription _subscription;
  bool? _wasAuthenticated;

  _BlocListenable(AuthBloc bloc) {
    _wasAuthenticated = _classify(bloc.state);
    _subscription = bloc.stream.listen((state) {
      final isAuth = _classify(state);
      // Skip transient states (Loading/Initial/Error) — they don't change
      // the auth group, only intermediate transitions.
      if (isAuth == null) return;
      if (isAuth != _wasAuthenticated) {
        _wasAuthenticated = isAuth;
        notifyListeners();
      }
    });
  }

  /// Returns:
  /// - `true` if the state represents authenticated session
  /// - `false` if explicitly unauthenticated
  /// - `null` for transient states that should not toggle the listener
  bool? _classify(AuthState state) {
    if (state is AuthAuthenticated) return true;
    if (state is AuthUnauthenticated) return false;
    return null;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// 회차 10 — Tab 1 (분석) navigator key.
/// 분석 sub-page 9개가 Tab 1 의 nested routes 로 들어가 navigator stack 에 push.
/// → BottomNav 유지. URL 은 /analysis/budgets/create 등으로 prefix 변경.
/// 기존 /budgets/create 등 root-level path 는 redirect 으로 backward compat.
final _analysisNavigatorKey = GlobalKey<NavigatorState>();

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
      // Server state is source of truth: with self-couple, coupleId
      // should always exist after signup. Auto-complete onboarding.
      if (!_onboardingCompleted && authState.user.coupleId != null) {
        markOnboardingCompleted();
      }
      if (!_onboardingCompleted) return '/onboarding';
      return '/transactions';
    }

    if (authState is AuthAuthenticated) {
      // Server state is source of truth: auto-complete onboarding
      // when the user already has a couple (including self-couple).
      if (!_onboardingCompleted && authState.user.coupleId != null) {
        markOnboardingCompleted();
      }

      // Admin guard: redirect non-admin users away from admin pages
      if (isOnAdminPage && authState.user.role != 'ADMIN') {
        return '/transactions';
      }

      // Allow onboarding page to pass through
      if (isOnOnboardingPage) return null;

      // If onboarding not completed, redirect to onboarding
      // (except couple page which can be accessed from onboarding)
      if (!_onboardingCompleted && !isOnCouplePage && !isOnAdminPage) {
        return '/onboarding';
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
      builder: (context, state) => BlocProvider<CoupleBloc>.value(
        value: getIt<CoupleBloc>()..add(const LoadCouple()),
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
        // Phase 25 Step 10 — 홈 탭 제거. /home 은 root-level redirect 으로 처리.
        // Tab 0: Transactions (기존 Tab 1)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) {
                final yearParam = state.uri.queryParameters['year'];
                final monthParam = state.uri.queryParameters['month'];
                final paymentMethodId = state.uri.queryParameters['paymentMethodId'];
                final paymentMethodName = state.uri.queryParameters['paymentMethodName'];
                final categoryId = state.uri.queryParameters['categoryId'];
                final categoryName = state.uri.queryParameters['categoryName'];
                // Phase 25 후속 — 예산/분석 에서 그룹 단위 필터 지원
                final categoryGroupId = state.uri.queryParameters['categoryGroupId'];

                // 회차 1 (2026-05-10) — defect C fix.
                // 이전: `paymentMethodId ?? f.paymentMethodId` 등 fallback 으로
                // URL 에 없는 필터를 BLoC currentFilter 에서 carry. stale 감지
                // (hasStaleFilter) 후에도 ?? 로 stale 재적용되어 router 자체가
                // desync 의 한 원인이었음.
                //
                // 새 규칙: URL 에 있는 navigation 성 필터 (paymentMethodId,
                // categoryId, categoryGroupId) 는 URL → BLoC 단방향. URL 에
                // 없으면 명시적 null/empty 전달 (carry over 금지).
                // 사용자가 dialog 로 설정한 컨텐트 필터 (visibility, keyword,
                // dateRange, amountRange, transactionTypes) 는 currentFilter
                // 에서 보존 (URL 에 안 박히므로 BLoC 가 유일 소스).
                final bloc = getIt<TransactionBloc>();
                final transferBloc = getIt<TransferBloc>();
                final hasExplicitParams = yearParam != null ||
                    monthParam != null ||
                    paymentMethodId != null ||
                    categoryId != null ||
                    categoryGroupId != null;
                // URL navigation filter 와 BLoC 의 현재 navigation filter 가
                // 다른지 — UI/BE desync 방지를 위해 항상 동기화.
                final urlPmDiffersFromBloc =
                    bloc.currentPaymentMethodId != paymentMethodId ||
                        (paymentMethodId == null &&
                            bloc.currentPaymentMethodIds.isNotEmpty);
                final urlCatDiffersFromBloc =
                    bloc.currentCategoryId != categoryId ||
                        (categoryId == null &&
                            bloc.currentCategoryIds.isNotEmpty);
                final urlGroupDiffersFromBloc = (categoryGroupId != null
                        ? {categoryGroupId}
                        : <String>{}) !=
                    bloc.currentCategoryGroupIds;
                final hasStaleFilter = !hasExplicitParams &&
                    bloc.state is TransactionLoaded &&
                    (urlPmDiffersFromBloc ||
                        urlCatDiffersFromBloc ||
                        urlGroupDiffersFromBloc);
                if (hasExplicitParams ||
                    bloc.state is TransactionInitial ||
                    hasStaleFilter) {
                  final now = DateTime.now();
                  final loadedState = bloc.state is TransactionLoaded
                      ? bloc.state as TransactionLoaded
                      : null;
                  final year = int.tryParse(yearParam ?? '') ??
                      loadedState?.year ??
                      now.year;
                  final month = int.tryParse(monthParam ?? '') ??
                      loadedState?.month ??
                      now.month;
                  final f = bloc.currentFilter;
                  bloc.add(LoadTransactions(
                    year: year,
                    month: month,
                    // Navigation 성 — URL 만 사용. 없으면 빈 값.
                    categoryId: categoryId,
                    paymentMethodId: paymentMethodId,
                    categoryGroupIds: categoryGroupId != null
                        ? {categoryGroupId}
                        : const {},
                    categoryIds: const {},
                    paymentMethodIds: const {},
                    pocketIds: const {},
                    // Content 필터 — BLoC 보존 (URL 에 박히지 않음).
                    keyword: f.keyword,
                    pocketId: f.pocketId,
                    amountMin: f.amountMin,
                    amountMax: f.amountMax,
                    dateFrom: f.dateFrom,
                    dateTo: f.dateTo,
                    type: f.type,
                    transactionTypes: f.transactionTypes,
                    visibility: f.visibility,
                  ));
                  transferBloc.add(LoadTransfers(year: year, month: month));
                }
                // Also load transfers if TransferBloc hasn't loaded yet
                if (transferBloc.state is TransferInitial) {
                  final now = DateTime.now();
                  transferBloc.add(LoadTransfers(year: now.year, month: now.month));
                }
                return MultiBlocProvider(
                  providers: [
                    BlocProvider<TransactionBloc>.value(value: getIt<TransactionBloc>()),
                    BlocProvider<TransferBloc>.value(value: transferBloc),
                  ],
                  child: TransactionListPage(
                    initialPaymentMethodId: paymentMethodId,
                    initialPaymentMethodName: paymentMethodName,
                    initialCategoryId: categoryId,
                    initialCategoryName: categoryName,
                    initialCategoryGroupId: categoryGroupId,
                  ),
                );
              },
              // 회차 6 — 거래 sub-page 를 ShellRoute branch nested 로 두어
              // BottomNav 유지. 기존 root level GoRoute 4개에서 이전됨.
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) {
                    final type = state.uri.queryParameters['type'];
                    final tab = state.uri.queryParameters['tab'];
                    // 배치 4 D-4 (2026-04-26): state.extra 는 새로고침 유실 → copyFromId query param 권장
                    final copyFrom = state.extra as Transaction?;
                    final copyFromId = state.uri.queryParameters['copyFromId'];
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
                        copyFromId: copyFromId,
                        initialDate: initialDate,
                        initialPaymentMethodId: initialPaymentMethodId,
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: 'edit/:id',
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
                        BlocProvider<TransferBloc>.value(
                          value: getIt<TransferBloc>(),
                        ),
                      ],
                      child: TransactionFormPage(
                        transactionId: transactionId,
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: 'import',
                  builder: (context, state) => const TransactionImportPage(),
                ),
                GoRoute(
                  path: 'detail/:id',
                  builder: (context, state) {
                    final transactionId = state.pathParameters['id']!;
                    return BlocProvider<TransactionBloc>.value(
                      value: getIt<TransactionBloc>(),
                      child: TransactionDetailPage(transactionId: transactionId),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        // Tab 1: Analysis (Phase 25 Step 11 — 분석 탭 신규, A/B 병존)
        // 회차 10 — 분석 sub-page 9개를 Tab 1 nested routes 로 이전.
        // URL prefix `/analysis/` 추가됨. root-level 기존 path 는 redirect 유지.
        StatefulShellBranch(
          navigatorKey: _analysisNavigatorKey,
          routes: [
            GoRoute(
              path: '/analysis',
              builder: (context, state) => const AnalysisPage(),
              routes: [
                GoRoute(
                  path: 'budgets/create',
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
                  path: 'budgets/edit/:id',
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
                  path: 'weekly-budgets',
                  builder: (context, state) {
                    final now = DateTime.now();
                    return BlocProvider<WeeklyBudgetBloc>.value(
                      value: getIt<WeeklyBudgetBloc>()
                        ..add(LoadWeeklyOverview(year: now.year, month: now.month))
                        ..add(const LoadCurrentWeek()),
                      child: const WeeklyBudgetPage(),
                    );
                  },
                ),
                GoRoute(
                  path: 'weekly-budgets/settlement',
                  builder: (context, state) {
                    final now = DateTime.now();
                    return BlocProvider<WeeklySettlementBloc>.value(
                      value: getIt<WeeklySettlementBloc>()
                        ..add(LoadSettlements(year: now.year, month: now.month)),
                      child: const WeeklySettlementPage(),
                    );
                  },
                ),
                GoRoute(
                  path: 'reports',
                  builder: (context, state) {
                    final now = DateTime.now();
                    return BlocProvider<ReportBloc>.value(
                      value: getIt<ReportBloc>()
                        ..add(LoadMonthlyReport(year: now.year, month: now.month))
                        ..add(LoadWeeklyReport(
                            year: now.year, month: now.month, week: 1)),
                      child: const ReportPage(),
                    );
                  },
                ),
                GoRoute(
                  path: 'period-summary',
                  builder: (context, state) {
                    final now = DateTime.now();
                    final dateFrom =
                        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
                    final lastDay = DateTime(now.year, now.month + 1, 0).day;
                    final dateTo =
                        '${now.year}-${now.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
                    return BlocProvider<PeriodSummaryBloc>.value(
                      value: getIt<PeriodSummaryBloc>()
                        ..add(LoadPeriodSummary(dateFrom: dateFrom, dateTo: dateTo)),
                      child: const PeriodSummaryPage(),
                    );
                  },
                ),
                GoRoute(
                  path: 'spending-plans',
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
                  path: 'spending-plans/create',
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
                      child: SpendingPlanFormPage(
                        isWishlist: state.uri.queryParameters['wishlist'] == 'true',
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: 'spending-plans/edit/:id',
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
              ],
            ),
          ],
        ),
        // Phase 25 Step 13/14 — 예산/통계 탭 제거. 분석 탭 안에 통합됨.
        // /budgets, /statistics 진입은 root-level redirect → /analysis 로 이동.
        // Tab 2: Assets (Phase 25 Step 2 — /asset-management 라우트 그대로 유지)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/assets',
              builder: (context, state) {
                final now = DateTime.now();
                getIt<CategoryBloc>().add(const LoadCategories());
                getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
                getIt<PaymentMethodBloc>().add(
                    LoadCardSettlementSummary(year: now.year, month: now.month));
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
          ],
        ),
        // Tab 5: Settings
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

    // Phase 25 Step 10 — 홈 탭 제거 후 redirect.
    // / 와 /home 진입 시 거래 탭으로 이동.
    GoRoute(
      path: '/',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/transactions',
    ),
    GoRoute(
      path: '/home',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/transactions',
    ),
    // Phase 25 Step 13/14 — 예산/통계 탭 제거. 분석 탭으로 통합 redirect.
    // 기존 deep link / 북마크 호환 유지.
    GoRoute(
      path: '/budgets',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/analysis',
    ),
    GoRoute(
      path: '/statistics',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/analysis',
    ),
    GoRoute(
      path: '/categories',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/asset-management',
    ),
    // 회차 6 — /transactions/{create,edit,detail,import} 라우트는
    // ShellRoute Tab 0 의 nested route 로 이동하여 BottomNav 유지.
    // 회차 10 — /budgets/{create,edit/:id}, /weekly-budgets, /weekly-budgets/settlement,
    // /reports, /period-summary, /spending-plans/* 9개는 Tab 1 분석 nested 로 이전.
    // 기존 path 는 redirect 으로 backward compat (deep link / 북마크).
    GoRoute(
      path: '/budgets/create',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) {
        final q = state.uri.query.isNotEmpty ? '?${state.uri.query}' : '';
        return '/analysis/budgets/create$q';
      },
    ),
    GoRoute(
      path: '/budgets/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) {
        final id = state.pathParameters['id']!;
        final q = state.uri.query.isNotEmpty ? '?${state.uri.query}' : '';
        return '/analysis/budgets/edit/$id$q';
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
      redirect: (context, state) {
        final q = state.uri.query.isNotEmpty ? '?${state.uri.query}' : '';
        return '/analysis/weekly-budgets$q';
      },
    ),
    GoRoute(
      path: '/weekly-budgets/settlement',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) {
        final q = state.uri.query.isNotEmpty ? '?${state.uri.query}' : '';
        return '/analysis/weekly-budgets/settlement$q';
      },
    ),
    GoRoute(
      path: '/reports',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) {
        final q = state.uri.query.isNotEmpty ? '?${state.uri.query}' : '';
        return '/analysis/reports$q';
      },
    ),
    GoRoute(
      path: '/period-summary',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) {
        final q = state.uri.query.isNotEmpty ? '?${state.uri.query}' : '';
        return '/analysis/period-summary$q';
      },
    ),
    GoRoute(
      path: '/recurring',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => BlocProvider<RecurringBloc>.value(
        value: getIt<RecurringBloc>()..add(const LoadRecurringTransactions()),
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
            BlocProvider<RecurringBloc>.value(
              value: getIt<RecurringBloc>()
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
            BlocProvider<RecurringBloc>.value(
              value: getIt<RecurringBloc>()
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
    // Partner Management
    GoRoute(
      path: '/settings/partner',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<CoupleBloc>().add(const LoadCouple());
        return BlocProvider<CoupleBloc>.value(
          value: getIt<CoupleBloc>(),
          child: const PartnerManagementPage(),
        );
      },
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
        final yearParam = int.tryParse(state.uri.queryParameters['year'] ?? '');
        final monthParam = int.tryParse(state.uri.queryParameters['month'] ?? '');
        getIt<CategoryBloc>().add(const LoadCategories());
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        if (yearParam != null && monthParam != null) {
          getIt<PaymentMethodBloc>().add(LoadCardSettlementSummary(year: yearParam, month: monthParam));
        }
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
          child: AssetManagementPage(
            initialYear: yearParam,
            initialMonth: monthParam,
          ),
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
    // Card Settlement
    GoRoute(
      path: '/card-settlement',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final cardId = state.uri.queryParameters['cardId'];
        final year = int.tryParse(state.uri.queryParameters['year'] ?? '');
        final month = int.tryParse(state.uri.queryParameters['month'] ?? '');
        getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
        return MultiBlocProvider(
          providers: [
            BlocProvider<CardSettlementBloc>.value(
              value: getIt<CardSettlementBloc>(),
            ),
            BlocProvider<PaymentMethodBloc>.value(
              value: getIt<PaymentMethodBloc>(),
            ),
          ],
          child: CardSettlementPage(
            initialCardId: cardId,
            initialYear: year,
            initialMonth: month,
          ),
        );
      },
    ),
    // Spending Plans — 회차 10 redirect to /analysis/spending-plans/*
    GoRoute(
      path: '/spending-plans',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) {
        final q = state.uri.query.isNotEmpty ? '?${state.uri.query}' : '';
        return '/analysis/spending-plans$q';
      },
    ),
    GoRoute(
      path: '/spending-plans/create',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) {
        final q = state.uri.query.isNotEmpty ? '?${state.uri.query}' : '';
        return '/analysis/spending-plans/create$q';
      },
    ),
    GoRoute(
      path: '/spending-plans/edit/:id',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) {
        final id = state.pathParameters['id']!;
        final q = state.uri.query.isNotEmpty ? '?${state.uri.query}' : '';
        return '/analysis/spending-plans/edit/$id$q';
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
    // Feedback Hub
    GoRoute(
      path: '/feedback-hub',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<FeedbackBloc>().add(const LoadFeedbacks());
        getIt<ReleaseNoteBloc>().add(const LoadReleaseNotes());
        return MultiBlocProvider(
          providers: [
            BlocProvider<FeedbackBloc>.value(
              value: getIt<FeedbackBloc>(),
            ),
            BlocProvider<ReleaseNoteBloc>.value(
              value: getIt<ReleaseNoteBloc>(),
            ),
          ],
          child: const FeedbackHubPage(),
        );
      },
    ),
    GoRoute(
      path: '/feedback/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        return BlocProvider<FeedbackBloc>.value(
          value: getIt<FeedbackBloc>(),
          child: const FeedbackCreatePage(),
        );
      },
    ),
    GoRoute(
      path: '/feedback/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final feedbackId = state.pathParameters['id']!;
        getIt<FeedbackBloc>().add(LoadFeedbackDetail(feedbackId));
        return BlocProvider<FeedbackBloc>.value(
          value: getIt<FeedbackBloc>(),
          child: FeedbackDetailPage(feedbackId: feedbackId),
        );
      },
    ),
    GoRoute(
      path: '/releases/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final releaseId = state.pathParameters['id']!;
        getIt<ReleaseNoteBloc>().add(LoadReleaseNoteDetail(releaseId));
        return BlocProvider<ReleaseNoteBloc>.value(
          value: getIt<ReleaseNoteBloc>(),
          child: ReleaseNoteDetailPage(releaseId: releaseId),
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
    GoRoute(
      path: '/admin/feedback',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<FeedbackBloc>().add(const LoadAdminFeedbacks());
        return BlocProvider<FeedbackBloc>.value(
          value: getIt<FeedbackBloc>(),
          child: const AdminFeedbackPage(),
        );
      },
    ),
    GoRoute(
      path: '/admin/releases',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        getIt<ReleaseNoteBloc>().add(const LoadReleaseNotes());
        return BlocProvider<ReleaseNoteBloc>.value(
          value: getIt<ReleaseNoteBloc>(),
          child: const AdminReleaseNotePage(),
        );
      },
    ),
  ],
);
