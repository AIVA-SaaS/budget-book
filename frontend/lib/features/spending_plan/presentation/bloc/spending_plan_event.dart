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

class CompletePlan extends SpendingPlanEvent {
  final String id;
  final String? transactionId;
  final int? actualAmount;

  const CompletePlan({
    required this.id,
    this.transactionId,
    this.actualAmount,
  });

  @override
  List<Object?> get props => [id, transactionId, actualAmount];
}

class SkipPlan extends SpendingPlanEvent {
  final String id;

  const SkipPlan(this.id);

  @override
  List<Object?> get props => [id];
}
