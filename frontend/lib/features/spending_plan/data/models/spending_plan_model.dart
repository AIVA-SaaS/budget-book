import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';

class SpendingPlanModel extends SpendingPlan {
  const SpendingPlanModel({
    required super.id,
    required super.name,
    required super.amount,
    required super.targetDate,
    super.memo,
    super.categoryId,
    super.categoryName,
    super.categoryGroupName,
    super.paymentMethodId,
    super.paymentMethodName,
    super.budgetId,
    super.linkedTransactionId,
    required super.status,
    super.actualAmount,
    super.completedDate,
    required super.isRecurring,
    super.frequency,
    required super.visibility,
    required super.authorName,
    required super.createdAt,
  });

  factory SpendingPlanModel.fromJson(Map<String, dynamic> json) {
    // Category can be a nested object or flat fields
    final category = json['category'] as Map<String, dynamic>?;
    final paymentMethod = json['paymentMethod'] as Map<String, dynamic>?;

    return SpendingPlanModel(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: json['amount'] as int,
      targetDate: json['targetDate'] as String,
      memo: json['memo'] as String?,
      categoryId: category?['id'] as String? ?? json['categoryId'] as String?,
      categoryName: category?['name'] as String? ?? json['categoryName'] as String?,
      categoryGroupName:
          category?['groupName'] as String? ?? json['categoryGroupName'] as String?,
      paymentMethodId: paymentMethod?['id'] as String? ??
          json['paymentMethodId'] as String?,
      paymentMethodName: paymentMethod?['name'] as String? ??
          json['paymentMethodName'] as String?,
      budgetId: json['budgetId'] as String?,
      linkedTransactionId: json['linkedTransactionId'] as String? ??
          (json['linkedTransaction'] as Map<String, dynamic>?)?['id'] as String?,
      status: json['status'] as String,
      actualAmount: json['actualAmount'] as int?,
      completedDate: json['completedDate'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? false,
      frequency: json['frequency'] as String?,
      visibility: json['visibility'] as String? ?? 'SHARED',
      authorName: json['authorName'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class SpendingPlanSummaryModel extends SpendingPlanSummary {
  const SpendingPlanSummaryModel({
    required super.totalPlanned,
    required super.totalCompleted,
    required super.totalSkipped,
    required super.plannedCount,
    required super.completedCount,
    required super.overdueCount,
  });

  factory SpendingPlanSummaryModel.fromJson(Map<String, dynamic> json) {
    return SpendingPlanSummaryModel(
      totalPlanned: json['totalPlanned'] as int? ?? 0,
      totalCompleted: json['totalCompleted'] as int? ?? 0,
      totalSkipped: json['totalSkipped'] as int? ?? 0,
      plannedCount: json['plannedCount'] as int? ?? 0,
      completedCount: json['completedCount'] as int? ?? 0,
      overdueCount: json['overdueCount'] as int? ?? 0,
    );
  }
}

class SpendingPlanSuggestionModel extends SpendingPlanSuggestion {
  const SpendingPlanSuggestionModel({
    required super.planId,
    required super.name,
    required super.plannedAmount,
    required super.matchScore,
  });

  factory SpendingPlanSuggestionModel.fromJson(Map<String, dynamic> json) {
    return SpendingPlanSuggestionModel(
      planId: json['planId'] as String,
      name: json['name'] as String,
      plannedAmount: json['plannedAmount'] as int,
      matchScore: (json['matchScore'] as num).toDouble(),
    );
  }
}
