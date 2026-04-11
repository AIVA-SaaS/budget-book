import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/ai/data/datasources/ai_remote_datasource.dart';
import 'ai_insight_event.dart';
import 'ai_insight_state.dart';

class AiInsightBloc extends Bloc<AiInsightEvent, AiInsightState> {
  final AiRemoteDataSource remoteDataSource;

  AiInsightBloc({required this.remoteDataSource})
      : super(const AiInsightInitial()) {
    on<LoadInsights>(_onLoadInsights);
  }

  Future<void> _onLoadInsights(
    LoadInsights event,
    Emitter<AiInsightState> emit,
  ) async {
    emit(const AiInsightLoading());
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
      emit(const AiInsightError('인사이트를 불러올 수 없습니다'));
    }
  }
}
