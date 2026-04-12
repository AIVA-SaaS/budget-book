import 'package:budget_book/features/ai/domain/entities/budget_suggestion.dart';

class BudgetSuggestionModel extends BudgetSuggestion {
  const BudgetSuggestionModel({
    required super.budgetId,
    required super.budgetName,
    required super.currentAmount,
    required super.suggestedAmount,
    required super.avgSpending,
    required super.reason,
  });

  factory BudgetSuggestionModel.fromJson(Map<String, dynamic> json) {
    return BudgetSuggestionModel(
      budgetId: json['budgetId'] as String,
      budgetName: json['budgetName'] as String,
      currentAmount: json['currentAmount'] as int,
      suggestedAmount: json['suggestedAmount'] as int,
      avgSpending: json['avgSpending'] as int? ?? 0,
      reason: json['reason'] as String? ?? '',
    );
  }
}
