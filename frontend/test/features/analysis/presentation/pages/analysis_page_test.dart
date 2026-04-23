import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/features/analysis/presentation/pages/analysis_page.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_state.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';

class MockBudgetBloc extends MockBloc<BudgetEvent, BudgetState>
    implements BudgetBloc {}

class MockStatisticsBloc extends MockBloc<StatisticsEvent, StatisticsState>
    implements StatisticsBloc {}

class MockCoupleBloc extends MockBloc<CoupleEvent, CoupleState>
    implements CoupleBloc {}

class FakeStatisticsState extends Fake implements StatisticsState {}

void main() {
  late MockBudgetBloc mockBudgetBloc;
  late MockStatisticsBloc mockStatsBloc;
  late MonthCubit monthCubit;

  setUpAll(() {
    registerFallbackValue(const LoadBudgets(year: 2026, month: 4));
    registerFallbackValue(const LoadAllStatistics(year: 2026, month: 4));
    registerFallbackValue(const LoadMonthlyTrend());
    registerFallbackValue(FakeStatisticsState());
  });

  setUp(() async {
    mockBudgetBloc = MockBudgetBloc();
    mockStatsBloc = MockStatisticsBloc();
    monthCubit = MonthCubit();
    monthCubit.changeMonth(2026, 4);

    await GetIt.instance.reset();
    final mockCoupleBloc = MockCoupleBloc();
    when(() => mockCoupleBloc.state).thenReturn(const CoupleNotLinked());
    GetIt.instance
        .registerLazySingleton<CoupleBloc>(() => mockCoupleBloc);
  });

  tearDown(() async {
    await monthCubit.close();
    await GetIt.instance.reset();
  });

  Widget buildPage() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BudgetBloc>.value(value: mockBudgetBloc),
          BlocProvider<StatisticsBloc>.value(value: mockStatsBloc),
          BlocProvider<MonthCubit>.value(value: monthCubit),
        ],
        child: const AnalysisPage(),
      ),
    );
  }

  const tCategory = TransactionCategory(
    id: 'cat-1',
    name: '식비',
    type: 'EXPENSE',
    icon: 'restaurant',
    color: '#FF5733',
    groupId: 'g1',
    groupName: '식비',
  );

  const tBudgetSummary = BudgetSummary(
    yearMonth: '2026-04',
    totalBudget: 1500000,
    totalSpent: 800000,
    items: [
      BudgetSummaryItem(
        category: tCategory,
        budgetAmount: 500000,
        spentAmount: 520000,
        remainingAmount: -20000,
        usageRate: 104.0,
      ),
    ],
  );

  group('AnalysisPage', () {
    testWidgets('renders period chip row with 월별/주별/연별', (tester) async {
      when(() => mockBudgetBloc.state).thenReturn(
        const BudgetLoaded(budgets: [], year: 2026, month: 4),
      );
      when(() => mockStatsBloc.state).thenReturn(
        const StatisticsState(year: 2026, month: 4),
      );

      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.text('분석'), findsWidgets);
      expect(find.text('월별'), findsOneWidget);
      expect(find.text('주별'), findsOneWidget);
      expect(find.text('연별'), findsOneWidget);
    });

    testWidgets('shows BudgetSummaryCard and 초과 카테고리 pill when summary has items',
        (tester) async {
      when(() => mockBudgetBloc.state).thenReturn(
        const BudgetLoaded(
          budgets: [],
          summary: tBudgetSummary,
          year: 2026,
          month: 4,
        ),
      );
      when(() => mockStatsBloc.state).thenReturn(
        const StatisticsState(year: 2026, month: 4),
      );

      await tester.pumpWidget(buildPage());
      await tester.pump();

      // BudgetSummaryCard
      expect(find.text('이번 달 예산'), findsOneWidget);
      // 초과 pill
      expect(find.textContaining('초과'), findsWidgets);
    });

    testWidgets('shows empty state when no budget summary', (tester) async {
      when(() => mockBudgetBloc.state).thenReturn(
        const BudgetLoaded(budgets: [], year: 2026, month: 4),
      );
      when(() => mockStatsBloc.state).thenReturn(
        const StatisticsState(year: 2026, month: 4),
      );

      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.text('이번 달 예산'), findsOneWidget);
      expect(
          find.textContaining('설정된 예산이 없습니다'), findsOneWidget);
    });

    testWidgets('renders all 4 sections + edit budget button', (tester) async {
      when(() => mockBudgetBloc.state).thenReturn(
        const BudgetLoaded(
          budgets: [],
          summary: tBudgetSummary,
          year: 2026,
          month: 4,
        ),
      );
      when(() => mockStatsBloc.state).thenReturn(
        const StatisticsState(
          year: 2026,
          month: 4,
          categoryStats: [
            CategoryStatistics(
              category: tCategory,
              amount: 520000,
              percentage: 65.0,
              transactionCount: 14,
            ),
          ],
          trends: [
            MonthlyTrend(
              yearMonth: '2026-03',
              totalIncome: 3000000,
              totalExpense: 1800000,
              balance: 1200000,
            ),
            MonthlyTrend(
              yearMonth: '2026-04',
              totalIncome: 3500000,
              totalExpense: 2200000,
              balance: 1300000,
            ),
          ],
          paymentMethodStats: [
            PaymentMethodStatistics(
              paymentMethodId: 'pm-1',
              paymentMethodName: '신한카드',
              totalAmount: 520000,
              transactionCount: 10,
              percentage: 80.0,
            ),
          ],
        ),
      );

      // Use a tall viewport so all sections fit without scrolling.
      tester.view.physicalSize = const Size(400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Section titles
      expect(find.text('이번 달 예산'), findsOneWidget);
      expect(find.text('카테고리별 지출'), findsOneWidget);
      expect(find.text('월별 비교'), findsOneWidget);
      expect(find.text('결제수단별 분포'), findsOneWidget);
      // Edit budget button
      expect(find.byKey(const Key('analysis_edit_budget_button')),
          findsOneWidget);
      expect(find.text('예산 편집'), findsOneWidget);
    });

    testWidgets('period chip change from 월별 to 연별 dispatches LoadMonthlyTrend(12)',
        (tester) async {
      when(() => mockBudgetBloc.state).thenReturn(
        const BudgetLoaded(budgets: [], year: 2026, month: 4),
      );
      when(() => mockStatsBloc.state).thenReturn(
        const StatisticsState(year: 2026, month: 4),
      );

      await tester.pumpWidget(buildPage());
      await tester.pump();

      await tester.tap(find.text('연별'));
      await tester.pump();

      // Check that LoadMonthlyTrend with 12 months was dispatched.
      verify(() => mockStatsBloc.add(any<LoadMonthlyTrend>(that:
          predicate<LoadMonthlyTrend>((e) => e.months == 12)))).called(1);
    });
  });
}
