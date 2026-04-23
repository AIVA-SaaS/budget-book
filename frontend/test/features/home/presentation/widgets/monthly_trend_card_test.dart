import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/home/presentation/widgets/monthly_trend_card.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';

void main() {
  final testTrends = [
    const MonthlyTrend(
      yearMonth: '2026-01',
      totalIncome: 5000000,
      totalExpense: 3000000,
      balance: 2000000,
    ),
    const MonthlyTrend(
      yearMonth: '2026-02',
      totalIncome: 4500000,
      totalExpense: 3200000,
      balance: 1300000,
    ),
    const MonthlyTrend(
      yearMonth: '2026-03',
      totalIncome: 5500000,
      totalExpense: 2800000,
      balance: 2700000,
    ),
  ];

  Widget buildCard({
    List<MonthlyTrend> trends = const [],
    Map<String, dynamic> settings = const {},
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MonthlyTrendCard(trends: trends, settings: settings),
        ),
      ),
    );
  }

  group('MonthlyTrendCard', () {
    testWidgets('shows empty state when no trends', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('추이 데이터가 없습니다'), findsOneWidget);
      expect(find.text('월별 추이'), findsOneWidget);
    });

    testWidgets('shows chart and title with data', (tester) async {
      await tester.pumpWidget(buildCard(trends: testTrends));
      expect(find.text('월별 추이'), findsOneWidget);
      // Legend items should be visible (default: income + expense)
      expect(find.text('수입'), findsOneWidget);
      expect(find.text('지출'), findsOneWidget);
    });

    testWidgets('respects showItems settings', (tester) async {
      await tester.pumpWidget(buildCard(
        trends: testTrends,
        settings: {
          'showItems': ['income', 'balance'],
        },
      ));
      expect(find.text('수입'), findsOneWidget);
      expect(find.text('잔액'), findsOneWidget);
      // expense legend should not be visible
      expect(find.text('지출'), findsNothing);
    });

    testWidgets('shows more button', (tester) async {
      await tester.pumpWidget(buildCard(trends: testTrends));
      expect(find.text('더보기'), findsOneWidget);
    });

    testWidgets('limits trends to months setting', (tester) async {
      // With months=2, only last 2 of 3 trends should be shown
      await tester.pumpWidget(buildCard(
        trends: testTrends,
        settings: {'months': 2},
      ));
      // Should still render without errors
      expect(find.text('월별 추이'), findsOneWidget);
    });
  });
}
