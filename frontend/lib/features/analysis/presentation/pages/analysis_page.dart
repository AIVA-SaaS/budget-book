import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:budget_book/core/di/injection.dart';
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
        body: const TabBarView(
          children: [
            _BudgetTabWrapper(),
            _StatisticsTabWrapper(),
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
      child: const BudgetListPage(showAppBar: false),
    );
  }
}

/// 통계 탭 wrapper — StatisticsPage 를 자체 AppBar 없이 노출.
class _StatisticsTabWrapper extends StatelessWidget {
  const _StatisticsTabWrapper();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return BlocProvider<StatisticsBloc>(
      create: (_) => getIt<StatisticsBloc>()
        ..add(LoadAllStatistics(year: now.year, month: now.month))
        ..add(LoadPaymentMethodStats(year: now.year, month: now.month)),
      child: const StatisticsPage(showAppBar: false),
    );
  }
}
