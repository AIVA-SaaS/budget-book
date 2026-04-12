import 'package:equatable/equatable.dart';

sealed class AiInsightEvent extends Equatable {
  const AiInsightEvent();

  @override
  List<Object?> get props => [];
}

class LoadInsights extends AiInsightEvent {
  final int year;
  final int month;

  const LoadInsights({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class LoadBudgetSuggestions extends AiInsightEvent {
  const LoadBudgetSuggestions();
}
