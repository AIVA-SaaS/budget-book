import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/features/statistics/domain/entities/period_summary.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_bloc.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_event.dart';
import 'package:budget_book/features/statistics/presentation/bloc/period_summary_state.dart';
import 'package:budget_book/features/statistics/presentation/pages/period_summary_page.dart';

class MockPeriodSummaryBloc
    extends MockBloc<PeriodSummaryEvent, PeriodSummaryState>
    implements PeriodSummaryBloc {}

void main() {
  late MockPeriodSummaryBloc mockBloc;

  setUp(() {
    mockBloc = MockPeriodSummaryBloc();
  });

  Widget buildWidget(PeriodSummaryState state) {
    when(() => mockBloc.state).thenReturn(state);
    return MaterialApp(
      home: BlocProvider<PeriodSummaryBloc>.value(
        value: mockBloc,
        child: const PeriodSummaryPage(),
      ),
    );
  }

  group('PeriodSummaryPage', () {
    testWidgets('shows loading indicator when loading', (tester) async {
      await tester.pumpWidget(buildWidget(const PeriodSummaryLoading()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message on error state', (tester) async {
      await tester
          .pumpWidget(buildWidget(const PeriodSummaryError('테스트 에러')));
      await tester.pump();

      expect(find.text('테스트 에러'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('shows summary cards and tabs when loaded', (tester) async {
      const summary = PeriodSummary(
        dateFrom: '2026-04-01',
        dateTo: '2026-04-07',
        totalIncome: 500000,
        totalExpense: 320000,
        balance: 180000,
        byCategory: [
          PeriodCategoryItem(
            categoryName: '식비',
            amount: 150000,
            count: 12,
            percentage: 46.9,
          ),
        ],
        byBudget: [],
        byPaymentMethod: [],
        byDate: [],
      );

      await tester
          .pumpWidget(buildWidget(const PeriodSummaryLoaded(summary)));
      await tester.pump();

      // AppBar title
      expect(find.text('기간별 기록'), findsOneWidget);

      // Summary cards
      expect(find.text('수입'), findsOneWidget);
      expect(find.text('지출'), findsOneWidget);
      expect(find.text('잔액'), findsOneWidget);

      // Tabs
      expect(find.text('카테고리별'), findsOneWidget);
      expect(find.text('예산별'), findsOneWidget);
      expect(find.text('결제수단별'), findsOneWidget);
      expect(find.text('일별'), findsOneWidget);

      // Category data displayed
      expect(find.text('식비'), findsOneWidget);
    });

    testWidgets('shows initial message when in initial state',
        (tester) async {
      await tester.pumpWidget(buildWidget(const PeriodSummaryInitial()));
      await tester.pump();

      expect(find.text('기간을 선택하면 데이터가 표시됩니다'), findsOneWidget);
    });
  });
}
