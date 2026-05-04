import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/ai/data/datasources/ai_remote_datasource.dart';
import 'ai_insight_event.dart';
import 'ai_insight_state.dart';

class AiInsightBloc extends Bloc<AiInsightEvent, AiInsightState> {
  final AiRemoteDataSource remoteDataSource;

  AiInsightBloc({required this.remoteDataSource})
      : super(const AiInsightInitial()) {
    on<LoadInsights>(_onLoadInsights);
    on<LoadBudgetSuggestions>(_onLoadBudgetSuggestions);
  }

  Future<void> _onLoadInsights(
    LoadInsights event,
    Emitter<AiInsightState> emit,
  ) async {
    // 회차 12 follow-up — race fix.
    if (state is! AiInsightLoaded) {
      emit(const AiInsightLoading());
    }
    try {
      final response = await remoteDataSource.getInsights(
        event.year,
        event.month,
      );
      emit(AiInsightLoaded(
        insights: response.insights,
        generatedAt: response.generatedAt,
      ));
    } catch (e) {
      if (state is! AiInsightLoaded) {
        emit(const AiInsightError('인사이트를 불러올 수 없습니다'));
      }
    }
  }

  Future<void> _onLoadBudgetSuggestions(
    LoadBudgetSuggestions event,
    Emitter<AiInsightState> emit,
  ) async {
    try {
      final suggestions = await remoteDataSource.getBudgetSuggestions();
      final currentState = state;
      if (currentState is AiInsightLoaded) {
        emit(AiInsightLoaded(
          insights: currentState.insights,
          generatedAt: currentState.generatedAt,
          budgetSuggestions: suggestions,
        ));
      } else {
        emit(AiInsightLoaded(
          insights: const [],
          generatedAt: '',
          budgetSuggestions: suggestions,
        ));
      }
    } catch (e) {
      // Silent fail for budget suggestions — don't overwrite insights
    }
  }
}
