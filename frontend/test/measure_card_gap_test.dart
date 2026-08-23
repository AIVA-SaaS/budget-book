// 계측 전용(일회성 대조군) — 카드형 목록의 "항목 사이" 실측.
// 사용자 지표 = 텍스트↔텍스트. 부수 지표 = 카드 테두리↔테두리.
// 실행: flutter test test/measure_card_gap_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/presentation/widgets/category_breakdown_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/monthly_trend_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/payment_method_stats_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/summary_tab.dart';
import 'package:budget_book/features/statistics/presentation/widgets/year_comparison_tab.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';

Rect _rect(Element e) {
  final ro = e.renderObject! as RenderBox;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

/// 카드 i 안 텍스트 최하단 → 카드 i+1 안 텍스트 최상단.
void _report(String label, double w) {
  final cards = find.byType(Card).evaluate().toList();
  if (cards.length < 2) {
    // ignore: avoid_print
    print('MEASURE|$label|w=$w|Card=${cards.length}|사이 측정 불가');
    return;
  }
  final rects = cards.map(_rect).toList();
  for (var i = 0; i < cards.length - 1; i++) {
    final borderGap = rects[i + 1].top - rects[i].bottom;
    // ★Card 의 RenderBox 는 자기 margin 을 **포함**한다 → 위 값은 보이는 테두리가 아니다.
    // 보이는 표면 = Card 안쪽 첫 Material.
    double? visibleGap;
    final aMat = find
        .descendant(
            of: find.byWidget(cards[i].widget), matching: find.byType(Material))
        .evaluate();
    final bMat = find
        .descendant(
            of: find.byWidget(cards[i + 1].widget),
            matching: find.byType(Material))
        .evaluate();
    if (aMat.isNotEmpty && bMat.isNotEmpty) {
      visibleGap = _rect(bMat.first).top - _rect(aMat.first).bottom;
    }
    final aTexts = find
        .descendant(
            of: find.byWidget(cards[i].widget), matching: find.byType(Text))
        .evaluate()
        .map(_rect)
        .toList();
    final bTexts = find
        .descendant(
            of: find.byWidget(cards[i + 1].widget), matching: find.byType(Text))
        .evaluate()
        .map(_rect)
        .toList();
    if (aTexts.isEmpty || bTexts.isEmpty) continue;
    final aBottom = aTexts.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
    final bTop = bTexts.map((r) => r.top).reduce((a, b) => a < b ? a : b);
    // ignore: avoid_print
    print('MEASURE|$label|w=$w|#$i→#${i + 1}'
        '|텍스트사이=${(bTop - aBottom).toStringAsFixed(1)}'
        '|상자사이=${borderGap.toStringAsFixed(1)}'
        '|보이는테두리사이=${visibleGap?.toStringAsFixed(1) ?? "?"}'
        '|카드높이=${rects[i].height.toStringAsFixed(1)}');
  }
}

Widget _wrap(double w, Widget child) => MaterialApp(
      theme: AppTheme.responsive(AppTheme.light, w),
      home: Scaffold(body: BbScaleScope(width: w, child: child)),
    );

const _cat = TransactionCategory(
    id: 'c1', name: '점심', type: 'EXPENSE', groupId: 'g1', groupName: '식비');
const _cat2 = TransactionCategory(
    id: 'c2', name: '지하철', type: 'EXPENSE', groupId: 'g2', groupName: '교통');
const _cat3 = TransactionCategory(
    id: 'c3', name: '영화', type: 'EXPENSE', groupId: 'g3', groupName: '문화');

const _stats = [
  CategoryStatistics(
      category: _cat, amount: 320000, percentage: 52.1, transactionCount: 14),
  CategoryStatistics(
      category: _cat2, amount: 180000, percentage: 29.3, transactionCount: 9),
  CategoryStatistics(
      category: _cat3, amount: 114000, percentage: 18.6, transactionCount: 3),
];

const _pmStats = [
  PaymentMethodStatistics(
      paymentMethodId: 'p1',
      paymentMethodName: '신한카드',
      paymentMethodType: 'CREDIT_CARD',
      totalAmount: 1500000,
      transactionCount: 20,
      percentage: 65.2),
  PaymentMethodStatistics(
      paymentMethodId: 'p2',
      paymentMethodName: '현금',
      paymentMethodType: 'CASH',
      totalAmount: 800000,
      transactionCount: 11,
      percentage: 34.8),
  PaymentMethodStatistics(
      paymentMethodId: 'p3',
      paymentMethodName: '카카오뱅크',
      paymentMethodType: 'DEBIT_CARD',
      totalAmount: 300000,
      transactionCount: 5,
      percentage: 13.0),
];

const _sum = StatisticsSummary(
    yearMonth: '2026-08',
    totalIncome: 4200000,
    totalExpense: 2600000,
    balance: 1600000,
    transactionCount: 88);
const _prevSum = StatisticsSummary(
    yearMonth: '2025-08',
    totalIncome: 3900000,
    totalExpense: 2900000,
    balance: 1000000,
    transactionCount: 74);

void main() {
  for (final w in [390.0, 960.0]) {
    testWidgets('통계>카테고리별(그룹) w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_wrap(
          w,
          CategoryBreakdownTab(
            categoryStats: _stats,
            onTypeChanged: (_) {},
            year: 2026,
            month: 8,
          )));
      await t.pump(const Duration(seconds: 1));
      _report('통계>카테고리별', w);
    });

    testWidgets('통계>결제수단별 w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_wrap(
          w,
          const PaymentMethodStatsTab(
              stats: _pmStats, isLoading: false, year: 2026, month: 8)));
      await t.pump(const Duration(seconds: 1));
      _report('통계>결제수단별', w);
    });

    testWidgets('통계>전년비교 w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_wrap(
          w,
          const YearComparisonTab(
              currentYear: _sum, previousYear: _prevSum, year: 2026, month: 8)));
      await t.pump(const Duration(seconds: 1));
      _report('통계>전년비교', w);
    });

    testWidgets('통계>추이 w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_wrap(
          w,
          const MonthlyTrendTab(trends: [
            MonthlyTrend(
                yearMonth: '2026-06',
                totalIncome: 3800000,
                totalExpense: 2500000,
                balance: 1300000),
            MonthlyTrend(
                yearMonth: '2026-07',
                totalIncome: 4000000,
                totalExpense: 2700000,
                balance: 1300000),
            MonthlyTrend(
                yearMonth: '2026-08',
                totalIncome: 4200000,
                totalExpense: 2600000,
                balance: 1600000),
          ])));
      await t.pump(const Duration(seconds: 1));
      _report('통계>추이', w);
    });

    testWidgets('요약탭(SummaryTab) w=$w', (t) async {
      await t.binding.setSurfaceSize(Size(w, 2400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_wrap(w, const SummaryTab(summary: _sum)));
      await t.pump(const Duration(seconds: 1));
      _report('요약탭', w);
    });
  }
}

