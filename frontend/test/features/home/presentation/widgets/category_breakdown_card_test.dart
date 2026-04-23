import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/home/presentation/widgets/category_breakdown_card.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';

void main() {
  final testStats = [
    const CategoryStatistics(
      category: TransactionCategory(
        id: 'cat-1',
        name: '식비',
        type: 'EXPENSE',
        groupId: 'g-1',
        groupName: '생활비',
      ),
      amount: 500000,
      percentage: 50.0,
      transactionCount: 20,
    ),
    const CategoryStatistics(
      category: TransactionCategory(
        id: 'cat-2',
        name: '교통비',
        type: 'EXPENSE',
        groupId: 'g-2',
        groupName: '이동',
      ),
      amount: 300000,
      percentage: 30.0,
      transactionCount: 10,
    ),
    const CategoryStatistics(
      category: TransactionCategory(
        id: 'cat-3',
        name: '문화생활',
        type: 'EXPENSE',
        groupId: 'g-3',
        groupName: '여가',
      ),
      amount: 200000,
      percentage: 20.0,
      transactionCount: 5,
    ),
  ];

  Widget buildCard({
    List<CategoryStatistics> stats = const [],
    Map<String, dynamic> settings = const {},
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CategoryBreakdownCard(
            categoryStats: stats,
            settings: settings,
          ),
        ),
      ),
    );
  }

  group('CategoryBreakdownCard', () {
    testWidgets('shows empty state when no stats', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('카테고리별 현황'), findsOneWidget);
      expect(find.textContaining('내역이 없습니다'), findsOneWidget);
    });

    testWidgets('shows title and category names with data', (tester) async {
      await tester.pumpWidget(buildCard(stats: testStats));
      expect(find.text('카테고리별 현황'), findsOneWidget);
      // Category names should appear in the legend
      expect(find.text('식비'), findsOneWidget);
      expect(find.text('교통비'), findsOneWidget);
      expect(find.text('문화생활'), findsOneWidget);
    });

    testWidgets('shows more button', (tester) async {
      await tester.pumpWidget(buildCard(stats: testStats));
      expect(find.text('더보기'), findsOneWidget);
    });

    testWidgets('respects count setting to limit categories', (tester) async {
      await tester.pumpWidget(buildCard(
        stats: testStats,
        settings: {'count': 2},
      ));
      // Should show only top 2 categories
      expect(find.text('식비'), findsOneWidget);
      expect(find.text('교통비'), findsOneWidget);
      expect(find.text('문화생활'), findsNothing);
    });

    testWidgets('shows expense empty message by default', (tester) async {
      await tester.pumpWidget(buildCard(
        settings: {'type': 'EXPENSE'},
      ));
      expect(find.text('이번 달 지출 내역이 없습니다'), findsOneWidget);
    });

    testWidgets('shows income empty message when type=INCOME', (tester) async {
      await tester.pumpWidget(buildCard(
        settings: {'type': 'INCOME'},
      ));
      expect(find.text('이번 달 수입 내역이 없습니다'), findsOneWidget);
    });
  });
}
