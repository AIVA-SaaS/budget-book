import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/widgets/budget_alert_widget.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

void main() {
  late MockDashboardBloc mockDashboardBloc;

  setUp(() {
    mockDashboardBloc = MockDashboardBloc();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<DashboardBloc>.value(
          value: mockDashboardBloc,
          child: const BudgetAlertWidget(),
        ),
      ),
    );
  }

  group('BudgetAlertWidget', () {
    testWidgets('shows nothing when state is not DashboardLoaded',
        (tester) async {
      when(() => mockDashboardBloc.state).thenReturn(const DashboardLoading());
      await tester.pumpWidget(createTestWidget());
      expect(find.byType(BudgetAlertWidget), findsOneWidget);
      // Should render empty SizedBox
      expect(find.text('예산 알림'), findsNothing);
    });

    testWidgets('shows nothing when no budget summary', (tester) async {
      when(() => mockDashboardBloc.state).thenReturn(const DashboardLoaded(
        year: 2026,
        month: 3,
        summary: StatisticsSummary(
          yearMonth: '2026-03',
          totalIncome: 5000000,
          totalExpense: 3000000,
          balance: 2000000,
          transactionCount: 10,
        ),
        budgetSummary: null,
        recentTransactions: <Transaction>[],
      ));
      await tester.pumpWidget(createTestWidget());
      expect(find.text('예산 알림'), findsNothing);
    });

    testWidgets('shows alert cards for items >= 80% usage', (tester) async {
      when(() => mockDashboardBloc.state).thenReturn(const DashboardLoaded(
        year: 2026,
        month: 3,
        summary: StatisticsSummary(
          yearMonth: '2026-03',
          totalIncome: 5000000,
          totalExpense: 3000000,
          balance: 2000000,
          transactionCount: 10,
        ),
        budgetSummary: BudgetSummary(
          yearMonth: '2026-03',
          totalBudget: 1000000,
          totalSpent: 850000,
          items: [
            BudgetSummaryItem(
              category: TransactionCategory(
                id: '1',
                name: '식비',
                type: 'EXPENSE',
              ),
              budgetAmount: 500000,
              spentAmount: 450000,
              remainingAmount: 50000,
              usageRate: 90.0,
            ),
            BudgetSummaryItem(
              category: TransactionCategory(
                id: '2',
                name: '교통비',
                type: 'EXPENSE',
              ),
              budgetAmount: 200000,
              spentAmount: 250000,
              remainingAmount: -50000,
              usageRate: 125.0,
            ),
            BudgetSummaryItem(
              category: TransactionCategory(
                id: '3',
                name: '문화',
                type: 'EXPENSE',
              ),
              budgetAmount: 300000,
              spentAmount: 150000,
              remainingAmount: 150000,
              usageRate: 50.0,
            ),
          ],
        ),
        recentTransactions: <Transaction>[],
      ));
      await tester.pumpWidget(createTestWidget());

      // Should show alert title
      expect(find.text('예산 알림'), findsOneWidget);

      // Should show cards for 식비 (90%) and 교통비 (125%), not 문화 (50%)
      expect(find.text('식비'), findsOneWidget);
      expect(find.text('교통비'), findsOneWidget);
      expect(find.text('문화'), findsNothing);

      // Should show status labels
      expect(find.text('주의'), findsOneWidget); // 90%
      expect(find.text('초과'), findsOneWidget); // 125%
    });

    testWidgets('shows nothing when all items are below 80%',
        (tester) async {
      when(() => mockDashboardBloc.state).thenReturn(const DashboardLoaded(
        year: 2026,
        month: 3,
        summary: StatisticsSummary(
          yearMonth: '2026-03',
          totalIncome: 5000000,
          totalExpense: 1000000,
          balance: 4000000,
          transactionCount: 5,
        ),
        budgetSummary: BudgetSummary(
          yearMonth: '2026-03',
          totalBudget: 1000000,
          totalSpent: 300000,
          items: [
            BudgetSummaryItem(
              category: TransactionCategory(
                id: '1',
                name: '식비',
                type: 'EXPENSE',
              ),
              budgetAmount: 500000,
              spentAmount: 200000,
              remainingAmount: 300000,
              usageRate: 40.0,
            ),
          ],
        ),
        recentTransactions: <Transaction>[],
      ));
      await tester.pumpWidget(createTestWidget());
      expect(find.text('예산 알림'), findsNothing);
    });
  });
}
