import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/statistics_state.dart';
import 'package:budget_book/features/statistics/presentation/pages/statistics_page.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_summary.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/features/statistics/domain/entities/monthly_trend.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_state.dart';

class MockStatisticsBloc extends MockBloc<StatisticsEvent, StatisticsState>
    implements StatisticsBloc {}

class MockCoupleBloc extends MockBloc<CoupleEvent, CoupleState>
    implements CoupleBloc {}

class FakeStatisticsState extends Fake implements StatisticsState {}

void main() {
  late MockStatisticsBloc mockBloc;

  setUpAll(() {
    registerFallbackValue(const LoadAllStatistics(year: 2026, month: 1));
    registerFallbackValue(FakeStatisticsState());
  });

  setUp(() async {
    mockBloc = MockStatisticsBloc();
    // Register mock CoupleBloc for isCoupleMode()
    await GetIt.instance.reset();
    final mockCoupleBloc = MockCoupleBloc();
    when(() => mockCoupleBloc.state).thenReturn(const CoupleNotLinked());
    GetIt.instance.registerLazySingleton<CoupleBloc>(() => mockCoupleBloc);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<StatisticsBloc>.value(value: mockBloc),
          BlocProvider<MonthCubit>(create: (_) => MonthCubit()),
        ],
        child: const StatisticsPage(),
      ),
    );
  }

  final now = DateTime.now();

  group('StatisticsPage', () {
    testWidgets('shows tab bar with 3 tabs', (tester) async {
      when(() => mockBloc.state).thenReturn(StatisticsState(
        year: now.year,
        month: now.month,
      ));

      await tester.pumpWidget(createTestWidget());

      expect(find.text('통계'), findsOneWidget);
      expect(find.text('요약'), findsOneWidget);
      expect(find.text('카테고리별'), findsOneWidget);
      expect(find.text('추이'), findsOneWidget);
    });

    testWidgets('shows loading indicator when summary is loading',
        (tester) async {
      when(() => mockBloc.state).thenReturn(StatisticsState(
        year: now.year,
        month: now.month,
        summaryLoading: true,
      ));

      await tester.pumpWidget(createTestWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows summary data when loaded', (tester) async {
      when(() => mockBloc.state).thenReturn(StatisticsState(
        year: now.year,
        month: now.month,
        summary: const StatisticsSummary(
          yearMonth: '2026-03',
          totalIncome: 5000000,
          totalExpense: 3200000,
          balance: 1800000,
          transactionCount: 45,
        ),
      ));

      await tester.pumpWidget(createTestWidget());

      expect(find.text('수입'), findsOneWidget);
      expect(find.text('지출'), findsOneWidget);
      expect(find.text('잔액'), findsOneWidget);
      expect(find.textContaining('5,000,000원'), findsOneWidget);
      expect(find.textContaining('3,200,000원'), findsOneWidget);
      expect(find.textContaining('1,800,000원'), findsOneWidget);
      expect(find.text('총 45건의 거래'), findsOneWidget);
    });

    testWidgets('shows category breakdown tab when tapped', (tester) async {
      when(() => mockBloc.state).thenReturn(StatisticsState(
        year: now.year,
        month: now.month,
        categoryStats: const [
          CategoryStatistics(
            category: TransactionCategory(
              id: '1',
              name: '식비',
              type: 'EXPENSE',
              icon: 'restaurant',
              color: '#FF5733',
              groupId: 'g1',
              groupName: '식비',
            ),
            amount: 800000,
            percentage: 25.0,
            transactionCount: 12,
          ),
        ],
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('카테고리별'));
      await tester.pumpAndSettle();

      // In group view (default), shows group name and aggregated stats
      expect(find.text('식비'), findsOneWidget);
      expect(find.textContaining('800,000원'), findsOneWidget);
      expect(find.text('100.0% (12건)'), findsOneWidget);
    });

    testWidgets('shows monthly trend tab when tapped', (tester) async {
      when(() => mockBloc.state).thenReturn(StatisticsState(
        year: now.year,
        month: now.month,
        trends: const [
          MonthlyTrend(
            yearMonth: '2025-10',
            totalIncome: 4500000,
            totalExpense: 3100000,
            balance: 1400000,
          ),
          MonthlyTrend(
            yearMonth: '2025-11',
            totalIncome: 4800000,
            totalExpense: 3400000,
            balance: 1400000,
          ),
        ],
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('추이'));
      await tester.pumpAndSettle();

      // Legend items
      expect(find.text('수입'), findsWidgets);
      expect(find.text('지출'), findsWidgets);
    });

    testWidgets('shows error message when summary has error', (tester) async {
      when(() => mockBloc.state).thenReturn(StatisticsState(
        year: now.year,
        month: now.month,
        summaryError: '통계 요약을 불러오지 못했습니다',
      ));

      await tester.pumpWidget(createTestWidget());

      expect(find.text('통계 요약을 불러오지 못했습니다'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows month navigator with MonthCubit current month',
        (tester) async {
      when(() => mockBloc.state).thenReturn(const StatisticsState(
        year: 2026,
        month: 3,
      ));

      final monthCubit = MonthCubit();
      addTearDown(monthCubit.close);
      monthCubit.changeMonth(2026, 3);

      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<StatisticsBloc>.value(value: mockBloc),
            BlocProvider<MonthCubit>.value(value: monthCubit),
          ],
          child: const StatisticsPage(),
        ),
      ));

      expect(find.text('2026년 3월'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('updates MonthCubit state to previous month when left arrow tapped',
        (tester) async {
      when(() => mockBloc.state).thenReturn(const StatisticsState(
        year: 2026,
        month: 3,
      ));

      // Custom widget with accessible MonthCubit 초기값 2026-3
      final monthCubit = MonthCubit();
      addTearDown(monthCubit.close);
      monthCubit.changeMonth(2026, 3);
      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<StatisticsBloc>.value(value: mockBloc),
            BlocProvider<MonthCubit>.value(value: monthCubit),
          ],
          child: const StatisticsPage(),
        ),
      ));
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      // MonthNavigator는 MonthCubit.state(2026-3) 기준 → 이전 달 2026-2
      expect(monthCubit.state.year, 2026);
      expect(monthCubit.state.month, 2);
    });

    testWidgets('updates MonthCubit state to next month when right arrow tapped',
        (tester) async {
      when(() => mockBloc.state).thenReturn(const StatisticsState(
        year: 2026,
        month: 3,
      ));

      final monthCubit = MonthCubit();
      addTearDown(monthCubit.close);
      monthCubit.changeMonth(2026, 3);
      await tester.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<StatisticsBloc>.value(value: mockBloc),
            BlocProvider<MonthCubit>.value(value: monthCubit),
          ],
          child: const StatisticsPage(),
        ),
      ));
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      // MonthNavigator는 MonthCubit.state(2026-3) 기준 → 다음 달 2026-4
      expect(monthCubit.state.year, 2026);
      expect(monthCubit.state.month, 4);
    });
  });
}
