import 'package:equatable/equatable.dart';
import 'package:budget_book/features/ai/domain/entities/ai_insight.dart';

sealed class AiInsightState extends Equatable {
  const AiInsightState();

  @override
  List<Object?> get props => [];
}

class AiInsightInitial extends AiInsightState {
  const AiInsightInitial();
}

class AiInsightLoading extends AiInsightState {
  const AiInsightLoading();
}

class AiInsightLoaded extends AiInsightState {
  final List<AiInsight> insights;
  final String generatedAt;

  const AiInsightLoaded({
    required this.insights,
    required this.generatedAt,
  });

  @override
  List<Object?> get props => [insights, generatedAt];
}

class AiInsightError extends AiInsightState {
  final String message;

  const AiInsightError(this.message);

  @override
  List<Object?> get props => [message];
}
