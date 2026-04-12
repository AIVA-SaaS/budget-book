import 'package:equatable/equatable.dart';

class BudgetSuggestion extends Equatable {
  final String budgetId;
  final String budgetName;
  final int currentAmount;
  final int suggestedAmount;
  final int avgSpending;
  final String reason;

  const BudgetSuggestion({
    required this.budgetId,
    required this.budgetName,
    required this.currentAmount,
    required this.suggestedAmount,
    required this.avgSpending,
    required this.reason,
  });

  int get difference => suggestedAmount - currentAmount;
  bool get isIncrease => suggestedAmount > currentAmount;

  @override
  List<Object?> get props => [
        budgetId, budgetName, currentAmount,
        suggestedAmount, avgSpending, reason,
      ];
}
