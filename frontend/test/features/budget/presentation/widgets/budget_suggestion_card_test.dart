import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/ai/domain/entities/budget_suggestion.dart';
import 'package:budget_book/features/budget/presentation/widgets/budget_suggestion_card.dart';

void main() {
  const testSuggestions = [
    BudgetSuggestion(
      budgetId: 'b1',
      budgetName: '식비',
      currentAmount: 500000,
      suggestedAmount: 600000,
      avgSpending: 580000,
      reason: '3개월 평균 지출 초과',
    ),
    BudgetSuggestion(
      budgetId: 'b2',
      budgetName: '교통비',
      currentAmount: 200000,
      suggestedAmount: 150000,
      avgSpending: 140000,
      reason: '최근 지출 감소 추세',
    ),
  ];

  Widget buildCard({List<BudgetSuggestion> suggestions = const []}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BudgetSuggestionCard(suggestions: suggestions),
        ),
      ),
    );
  }

  group('BudgetSuggestionCard', () {
    testWidgets('shows nothing when suggestions empty', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('예산 조정 제안'), findsNothing);
    });

    testWidgets('shows title and suggestion names', (tester) async {
      await tester.pumpWidget(buildCard(suggestions: testSuggestions));
      expect(find.text('예산 조정 제안'), findsOneWidget);
      expect(find.text('식비'), findsOneWidget);
      expect(find.text('교통비'), findsOneWidget);
    });

    testWidgets('shows reason text', (tester) async {
      await tester.pumpWidget(buildCard(suggestions: testSuggestions));
      expect(find.text('3개월 평균 지출 초과'), findsOneWidget);
      expect(find.text('최근 지출 감소 추세'), findsOneWidget);
    });

    testWidgets('shows adjust button for each suggestion', (tester) async {
      await tester.pumpWidget(buildCard(suggestions: testSuggestions));
      expect(find.text('조정하기'), findsNWidgets(2));
    });

    testWidgets('shows increase icon for higher suggested amount', (tester) async {
      await tester.pumpWidget(buildCard(
        suggestions: const [
          BudgetSuggestion(
            budgetId: 'b1',
            budgetName: '식비',
            currentAmount: 500000,
            suggestedAmount: 600000,
            avgSpending: 580000,
            reason: '',
          ),
        ],
      ));
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('shows decrease icon for lower suggested amount', (tester) async {
      await tester.pumpWidget(buildCard(
        suggestions: const [
          BudgetSuggestion(
            budgetId: 'b2',
            budgetName: '교통비',
            currentAmount: 200000,
            suggestedAmount: 150000,
            avgSpending: 140000,
            reason: '',
          ),
        ],
      ));
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });
  });
}
