import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_summary_cubit.dart';
import 'package:budget_book/features/reconciliation/presentation/widgets/reconciliation_summary_card.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/pages/budget_list_page.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/statistics/presentation/pages/statistics_page.dart';

/// Phase 25 Step 11 — 분석 탭 신규.
///
/// **현재 단계**: v1.0 의 BudgetListPage + StatisticsPage 를 TabBar 로 묶어
/// 단일 진입점으로 노출 (A/B 병존). 기존 [예산][통계] 탭은 그대로 유지.
///
/// **다음 단계 (후속 PR)**: 두 페이지의 핵심 섹션을 단일 페이지로 통합 예정
/// (BudgetSummaryCard, 카테고리 지출, 월별 추이, 결제수단 도넛, 전년 비교 등).
class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('분석'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: '예산'),
              Tab(icon: Icon(Icons.bar_chart_outlined), text: '통계'),
            ],
          ),
        ),
        // 회차 12 follow-up (2026-05-04) — 사용자 요구 반영.
        // 이전: TabBar 아래의 각 sub-tab 안에 MonthNavigator (예산은 월간/주간
        // SegmentedButton 아래) → 가독성 떨어짐.
        // 신규: TabBar 바로 아래에 단일 MonthNavigator. 예산/통계 두 sub-tab
        // 공유. MonthCubit 단일 source 라 sync 자동.
        body: const Column(
          children: [
            MonthNavigator(),
            // 월말 점검 (2026-08-10) — 예산/통계 두 sub-tab 이 공유하는 위치.
            // 그 달의 미기록 건수를 한눈에 보여주고, 누르면 거래 탭 정산 뷰로
            // **보고 있던 달 그대로** 이동한다.
            _ReconciliationSummarySection(),
            Expanded(
              child: TabBarView(
                children: [
                  _BudgetTabWrapper(),
                  _StatisticsTabWrapper(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 월말 점검 카드 영역.
///
/// 달 이동은 [MonthCubit] 이 단일 소스이므로 그 값을 그대로 따른다(월 변경 시
/// 재조회는 `MonthSyncHandler` 가 담당). 탭에 들어올 때마다 한 번 더 요청하는 이유는
/// 사용자가 거래 탭에서 정산을 기록하고 돌아왔을 때 숫자가 옛것으로 남지 않게 하기
/// 위해서다 — 통계/예산 wrapper 도 같은 방식으로 진입 시 로드한다.
///
/// 요약이 없으면(미조회·실패) 아무것도 그리지 않는다. 분석 탭의 다른 내용이
/// 이 카드 때문에 밀리거나 빈 카드가 남는 일이 없어야 한다.
class _ReconciliationSummarySection extends StatelessWidget {
  const _ReconciliationSummarySection();

  @override
  Widget build(BuildContext context) {
    final monthState = context.watch<MonthCubit>().state;
    final cubit = getIt<ReconciliationSummaryCubit>()
      ..load(year: monthState.year, month: monthState.month);

    return BlocProvider<ReconciliationSummaryCubit>.value(
      value: cubit,
      child: BlocBuilder<ReconciliationSummaryCubit, ReconciliationSummaryState>(
        builder: (context, state) {
          final summary = state.summary;
          if (summary == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: ReconciliationSummaryCard(
              summary: summary,
              year: monthState.year,
              month: monthState.month,
            ),
          );
        },
      ),
    );
  }
}

/// 예산 탭 wrapper — BudgetListPage 를 자체 AppBar 없이 노출.
class _BudgetTabWrapper extends StatelessWidget {
  const _BudgetTabWrapper();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BudgetBloc>.value(
      value: getIt<BudgetBloc>()
        ..add(LoadBudgets(
          year: DateTime.now().year,
          month: DateTime.now().month,
        )),
      child: const BudgetListPage(showAppBar: false, showMonthNavigator: false),
    );
  }
}

/// 통계 탭 wrapper — StatisticsPage 를 자체 AppBar 없이 노출.
class _StatisticsTabWrapper extends StatelessWidget {
  const _StatisticsTabWrapper();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // singleton bloc 은 BlocProvider.value 사용. (create 패턴은 dispose 시
    // close() 호출되어 singleton 이 dead 상태로 다음 진입 시 회색화면 회귀)
    return BlocProvider<StatisticsBloc>.value(
      value: getIt<StatisticsBloc>()
        ..add(LoadAllStatistics(year: now.year, month: now.month))
        ..add(LoadPaymentMethodStats(year: now.year, month: now.month)),
      child: const StatisticsPage(showAppBar: false, showMonthNavigator: false),
    );
  }
}
