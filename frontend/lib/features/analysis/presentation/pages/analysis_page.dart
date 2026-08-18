import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/bb_tab.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';
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
          // 2026-08-18 — 타이틀 '분석' 은 하단 네비 라벨과 중복이다
          // (`main_shell_page.dart` NavigationDestination(label: '분석')).
          // TabBar 가 이미 위치를 말하므로 툴바 줄을 통째로 회수한다(−56dp).
          // 같은 기법을 `statistics_page` 가 이미 쓰고 있다.
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          bottom: TabBar(
            tabs: [
              bbTab(context,
                  icon: Icons.account_balance_wallet_outlined, label: '예산'),
              bbTab(context, icon: Icons.bar_chart_outlined, label: '통계'),
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
