import 'package:equatable/equatable.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';

sealed class SpendingPlanState extends Equatable {
  const SpendingPlanState();

  @override
  List<Object?> get props => [];
}

class SpendingPlanInitial extends SpendingPlanState {
  const SpendingPlanInitial();
}

class SpendingPlanLoading extends SpendingPlanState {
  const SpendingPlanLoading();
}

class SpendingPlanLoaded extends SpendingPlanState {
  final List<SpendingPlan> plans;
  final SpendingPlanSummary summary;
  final String? operationError;
  final String? operationSuccess;

  const SpendingPlanLoaded({
    required this.plans,
    required this.summary,
    this.operationError,
    this.operationSuccess,
  });

  /// Group plans by target date for timeline display.
  Map<String, List<SpendingPlan>> get groupedByDate {
    final grouped = <String, List<SpendingPlan>>{};
    for (final plan in plans) {
      grouped.putIfAbsent(plan.targetDate, () => []).add(plan);
    }
    // Sort dates ascending
    final sortedKeys = grouped.keys.toList()..sort();
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  List<SpendingPlan> get plannedPlans =>
      plans.where((p) => p.status == 'PLANNED').toList();

  List<SpendingPlan> get completedPlans =>
      plans.where((p) => p.status == 'COMPLETED').toList();

  List<SpendingPlan> get skippedPlans =>
      plans.where((p) => p.status == 'SKIPPED').toList();

  List<SpendingPlan> get overduePlans =>
      plans.where((p) => p.status == 'OVERDUE').toList();

  @override
  List<Object?> get props => [plans, summary, operationError, operationSuccess];
}

class SpendingPlanError extends SpendingPlanState {
  final String message;

  const SpendingPlanError(this.message);

  @override
  List<Object?> get props => [message];
}
