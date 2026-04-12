import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/features/ai/data/datasources/ai_remote_datasource.dart';
import 'package:budget_book/features/ai/data/models/ai_insight_model.dart';
import 'package:budget_book/features/ai/data/models/budget_suggestion_model.dart';
import 'package:budget_book/features/ai/presentation/bloc/ai_insight_bloc.dart';
import 'package:budget_book/features/ai/presentation/bloc/ai_insight_event.dart';
import 'package:budget_book/features/ai/presentation/bloc/ai_insight_state.dart';

class MockAiRemoteDataSource extends Mock implements AiRemoteDataSource {}

void main() {
  late MockAiRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockAiRemoteDataSource();
  });

  const testInsightsResponse = AiInsightsResponseModel(
    insights: [
      AiInsightModel(
        type: 'SPENDING_PATTERN',
        title: '식비 지출 증가',
        description: '지난달 대비 식비가 20% 증가했습니다.',
        severity: 'WARNING',
      ),
      AiInsightModel(
        type: 'TIP',
        title: '절약 팁',
        description: '자동 이체를 활용하면 절약할 수 있습니다.',
        severity: 'INFO',
      ),
    ],
    generatedAt: '2026-04-07T12:00:00Z',
  );

  group('AiInsightBloc', () {
    blocTest<AiInsightBloc, AiInsightState>(
      'emits [Loading, Loaded] when LoadInsights succeeds',
      build: () {
        when(() => mockDataSource.getInsights(2026, 4))
            .thenAnswer((_) async => testInsightsResponse);
        return AiInsightBloc(remoteDataSource: mockDataSource);
      },
      act: (bloc) => bloc.add(const LoadInsights(year: 2026, month: 4)),
      expect: () => [
        const AiInsightLoading(),
        isA<AiInsightLoaded>()
            .having((s) => s.insights.length, 'insights count', 2)
            .having((s) => s.insights[0].title, 'first title', '식비 지출 증가')
            .having((s) => s.generatedAt, 'generatedAt', '2026-04-07T12:00:00Z'),
      ],
      verify: (_) {
        verify(() => mockDataSource.getInsights(2026, 4)).called(1);
      },
    );

    blocTest<AiInsightBloc, AiInsightState>(
      'emits [Loading, Error] when LoadInsights fails',
      build: () {
        when(() => mockDataSource.getInsights(2026, 4))
            .thenThrow(Exception('Network error'));
        return AiInsightBloc(remoteDataSource: mockDataSource);
      },
      act: (bloc) => bloc.add(const LoadInsights(year: 2026, month: 4)),
      expect: () => [
        const AiInsightLoading(),
        const AiInsightError('인사이트를 불러올 수 없습니다'),
      ],
    );

    blocTest<AiInsightBloc, AiInsightState>(
      'emits [Loading, Loaded] with empty insights when API returns none',
      build: () {
        when(() => mockDataSource.getInsights(2026, 4))
            .thenAnswer((_) async => const AiInsightsResponseModel(
                  insights: [],
                  generatedAt: '2026-04-07T12:00:00Z',
                ));
        return AiInsightBloc(remoteDataSource: mockDataSource);
      },
      act: (bloc) => bloc.add(const LoadInsights(year: 2026, month: 4)),
      expect: () => [
        const AiInsightLoading(),
        isA<AiInsightLoaded>()
            .having((s) => s.insights, 'insights', isEmpty),
      ],
    );

    blocTest<AiInsightBloc, AiInsightState>(
      'LoadBudgetSuggestions adds suggestions to existing loaded state',
      build: () {
        when(() => mockDataSource.getBudgetSuggestions()).thenAnswer(
          (_) async => const [
            BudgetSuggestionModel(
              budgetId: 'b1',
              budgetName: '식비',
              currentAmount: 500000,
              suggestedAmount: 600000,
              avgSpending: 580000,
              reason: '3개월 평균 초과',
            ),
          ],
        );
        return AiInsightBloc(remoteDataSource: mockDataSource);
      },
      seed: () => const AiInsightLoaded(
        insights: [],
        generatedAt: '2026-04-07T12:00:00Z',
      ),
      act: (bloc) => bloc.add(const LoadBudgetSuggestions()),
      expect: () => [
        isA<AiInsightLoaded>()
            .having((s) => s.budgetSuggestions.length, 'suggestions count', 1)
            .having((s) => s.budgetSuggestions.first.budgetName, 'name', '식비')
            .having((s) => s.generatedAt, 'generatedAt', '2026-04-07T12:00:00Z'),
      ],
    );

    blocTest<AiInsightBloc, AiInsightState>(
      'LoadBudgetSuggestions silent fail does not change state',
      build: () {
        when(() => mockDataSource.getBudgetSuggestions())
            .thenThrow(Exception('Network error'));
        return AiInsightBloc(remoteDataSource: mockDataSource);
      },
      seed: () => const AiInsightLoaded(
        insights: [],
        generatedAt: '2026-04-07T12:00:00Z',
      ),
      act: (bloc) => bloc.add(const LoadBudgetSuggestions()),
      expect: () => [], // No state change on error
    );
  });
}
