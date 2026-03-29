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
  final List<SpendingPlan>? wishlist;
  final String? operationError;
  final String? operationSuccess;

  const SpendingPlanLoaded({
    required this.plans,
    required this.summary,
    this.wishlist,
    this.operationError,
    this.operationSuccess,
  });

  /// Group plans by target date for timeline display.
  Map<String, List<SpendingPlan>> get groupedByDate {
    final grouped = <String, List<SpendingPlan>>{};
    for (final plan in plans) {
      if (plan.targetDate == null) continue;
      grouped.putIfAbsent(plan.targetDate!, () => []).add(plan);
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

  /// Group wishlist items by priority: HIGH -> MEDIUM -> LOW.
  Map<String, List<SpendingPlan>> get wishlistByPriority {
    final items = wishlist ?? [];
    final grouped = <String, List<SpendingPlan>>{};
    for (final plan in items) {
      grouped.putIfAbsent(plan.priority, () => []).add(plan);
    }
    // Return in priority order
    final result = <String, List<SpendingPlan>>{};
    for (final priority in ['HIGH', 'MEDIUM', 'LOW']) {
      if (grouped.containsKey(priority)) {
        result[priority] = grouped[priority]!;
      }
    }
    return result;
  }

  @override
  List<Object?> get props => [plans, summary, wishlist, operationError, operationSuccess];
}

class SpendingPlanError extends SpendingPlanState {
  final String message;

  const SpendingPlanError(this.message);

  @override
  List<Object?> get props => [message];
}
