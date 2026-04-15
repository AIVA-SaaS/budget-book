import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/ai/presentation/bloc/ai_insight_bloc.dart';
import 'package:budget_book/features/ai/presentation/bloc/ai_insight_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/report/presentation/bloc/report_bloc.dart';
import 'package:budget_book/features/report/presentation/bloc/report_event.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_bloc.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_bloc.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_event.dart';

/// 월 변경 중앙 핸들러.
///
/// MonthCubit의 state 변화를 구독하여 월 의존 BLoC들에 자동으로 reload 이벤트를
/// dispatch. 새 월 의존 BLoC 추가 시 여기에만 등록하면 모든 페이지에서 자동 적용.
///
/// 기존 각 페이지에서 수동으로 `LoadCardSettlementSummary` 등을 dispatch하던
/// 패턴을 제거하여 반복 누락을 원천 차단.
///
/// 앱 최상위(app.dart MaterialApp.router builder) 안에 배치하여 모든 페이지에 적용.
class MonthSyncHandler extends StatelessWidget {
  final Widget child;

  const MonthSyncHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<MonthCubit, MonthState>(
      listenWhen: (prev, curr) => prev != curr,
      listener: (_, monthState) {
        _syncAllMonthDependentBlocs(monthState.year, monthState.month);
      },
      child: child,
    );
  }

  /// 월 의존 BLoC 등록부.
  /// 새 월 의존 BLoC 추가 시 여기에만 추가하면 전체 페이지에서 자동 동기화.
  void _syncAllMonthDependentBlocs(int year, int month) {
    // Budget
    try {
      getIt<BudgetBloc>().add(LoadBudgets(year: year, month: month));
    } catch (_) {}

    // Dashboard
    try {
      getIt<DashboardBloc>().add(LoadDashboard(year: year, month: month));
    } catch (_) {}

    // Payment method card settlement summary
    try {
      getIt<PaymentMethodBloc>().add(
        LoadCardSettlementSummary(year: year, month: month),
      );
    } catch (_) {}

    // Transaction list — 기존 필터(paymentMethodId/categoryId) 유지
    try {
      final txnBloc = getIt<TransactionBloc>();
      txnBloc.add(LoadTransactions(
        year: year,
        month: month,
        categoryId: txnBloc.currentCategoryId,
        paymentMethodId: txnBloc.currentPaymentMethodId,
      ));
    } catch (_) {}

    // Transfer list
    try {
      getIt<TransferBloc>().add(LoadTransfers(year: year, month: month));
    } catch (_) {}

    // Statistics (all tabs)
    try {
      final statBloc = getIt<StatisticsBloc>();
      statBloc.add(LoadAllStatistics(year: year, month: month));
      statBloc.add(LoadPaymentMethodStats(year: year, month: month));
      statBloc.add(LoadYearComparison(year: year, month: month));
    } catch (_) {}

    // Weekly budget overview
    try {
      getIt<WeeklyBudgetBloc>()
          .add(LoadWeeklyOverview(year: year, month: month));
    } catch (_) {}

    // Monthly report
    try {
      getIt<ReportBloc>().add(LoadMonthlyReport(year: year, month: month));
    } catch (_) {}

    // AI insights
    try {
      getIt<AiInsightBloc>().add(LoadInsights(year: year, month: month));
    } catch (_) {}

    // Spending plans — 월의 시작일/다음달 1일 범위로 조회
    try {
      final startDate =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
      final endMonth = month == 12 ? 1 : month + 1;
      final endYear = month == 12 ? year + 1 : year;
      final endDate =
          '${endYear.toString().padLeft(4, '0')}-${endMonth.toString().padLeft(2, '0')}-01';
      getIt<SpendingPlanBloc>().add(
        LoadSpendingPlans(startDate: startDate, endDate: endDate),
      );
    } catch (_) {}
  }
}
