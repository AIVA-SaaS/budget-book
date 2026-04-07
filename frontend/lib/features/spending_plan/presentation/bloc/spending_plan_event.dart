import 'package:equatable/equatable.dart';

sealed class SpendingPlanEvent extends Equatable {
  const SpendingPlanEvent();

  @override
  List<Object?> get props => [];
}

class LoadSpendingPlans extends SpendingPlanEvent {
  final String? startDate;
  final String? endDate;
  final String? status;

  const LoadSpendingPlans({this.startDate, this.endDate, this.status});

  @override
  List<Object?> get props => [startDate, endDate, status];
}

class CreateSpendingPlan extends SpendingPlanEvent {
  final String name;
  final int amount;
  final String targetDate;
  final String? memo;
  final String? categoryId;
  final String? paymentMethodId;
  final String? budgetId;
  final bool isRecurring;
  final String? frequency;
  final String visibility;
  final String? status; // WISHLIST or PLANNED (default)
  final String? priority; // HIGH, MEDIUM, LOW
  final int? estimatedMin;
  final int? estimatedMax;
  final String? tags; // comma-separated

  const CreateSpendingPlan({
    required this.name,
    required this.amount,
    required this.targetDate,
    this.memo,
    this.categoryId,
    this.paymentMethodId,
    this.budgetId,
    this.isRecurring = false,
    this.frequency,
    this.visibility = 'SHARED',
    this.status,
    this.priority,
    this.estimatedMin,
    this.estimatedMax,
    this.tags,
  });

  @override
  List<Object?> get props => [
        name,
        amount,
        targetDate,
        memo,
        categoryId,
        paymentMethodId,
        budgetId,
        isRecurring,
        frequency,
        visibility,
        status,
        priority,
        estimatedMin,
        estimatedMax,
        tags,
      ];
}

class UpdateSpendingPlan extends SpendingPlanEvent {
  final String id;
  final String? name;
  final int? amount;
  final String? targetDate;
  final String? memo;
  final bool clearMemo;
  final String? categoryId;
  final bool clearCategoryId;
  final String? paymentMethodId;
  final bool clearPaymentMethodId;
  final String? budgetId;
  final bool clearBudgetId;
  final bool? isRecurring;
  final String? frequency;
  final bool clearFrequency;
  final String? visibility;

  const UpdateSpendingPlan({
    required this.id,
    this.name,
    this.amount,
    this.targetDate,
    this.memo,
    this.clearMemo = false,
    this.categoryId,
    this.clearCategoryId = false,
    this.paymentMethodId,
    this.clearPaymentMethodId = false,
    this.budgetId,
    this.clearBudgetId = false,
    this.isRecurring,
    this.frequency,
    this.clearFrequency = false,
    this.visibility,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        amount,
        targetDate,
        memo,
        clearMemo,
        categoryId,
        clearCategoryId,
        paymentMethodId,
        clearPaymentMethodId,
        budgetId,
        clearBudgetId,
        isRecurring,
        frequency,
        clearFrequency,
        visibility,
      ];
}

class DeleteSpendingPlan extends SpendingPlanEvent {
  final String id;

  const DeleteSpendingPlan(this.id);

  @override
  List<Object?> get props => [id];
}

class SkipPlan extends SpendingPlanEvent {
  final String id;

  const SkipPlan(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadWishlist extends SpendingPlanEvent {
  const LoadWishlist();
}

class AssignPlan extends SpendingPlanEvent {
  final String planId;
  final String targetDate;
  final int? weekNumber;
  final String? budgetId;

  const AssignPlan({
    required this.planId,
    required this.targetDate,
    this.weekNumber,
    this.budgetId,
  });

  @override
  List<Object?> get props => [planId, targetDate, weekNumber, budgetId];
}

class CompleteWithTransaction extends SpendingPlanEvent {
  final String planId;
  final int amount;
  final String transactionDate;
  final String? description;
  final String? categoryId;
  final String? paymentMethodId;

  const CompleteWithTransaction({
    required this.planId,
    required this.amount,
    required this.transactionDate,
    this.description,
    this.categoryId,
    this.paymentMethodId,
  });

  @override
  List<Object?> get props => [
        planId,
        amount,
        transactionDate,
        description,
        categoryId,
        paymentMethodId,
      ];
}

class LinkTransaction extends SpendingPlanEvent {
  final String planId;
  final String transactionId;

  const LinkTransaction({
    required this.planId,
    required this.transactionId,
  });

  @override
  List<Object?> get props => [planId, transactionId];
}

class UnlinkTransaction extends SpendingPlanEvent {
  final String planId;

  const UnlinkTransaction({required this.planId});

  @override
  List<Object?> get props => [planId];
}
