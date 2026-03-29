import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

class SpendingPlan extends Equatable {
  final String id;
  final String name;
  final int amount;
  final String? targetDate; // yyyy-MM-dd, null for WISHLIST
  final String? memo;
  final String? categoryId;
  final String? categoryName;
  final String? categoryGroupName;
  final String? paymentMethodId;
  final String? paymentMethodName;
  final String? budgetId;
  final String? linkedTransactionId;
  final String status; // WISHLIST, PLANNED, COMPLETED, SKIPPED, OVERDUE
  final int? actualAmount;
  final String? completedDate;
  final bool isRecurring;
  final String? frequency;
  final String visibility;
  final String authorName;
  final String createdAt;
  final String priority; // HIGH, MEDIUM, LOW
  final int? estimatedMin;
  final int? estimatedMax;
  final List<String> tags;
  final int? weekNumber;

  const SpendingPlan({
    required this.id,
    required this.name,
    required this.amount,
    this.targetDate,
    this.memo,
    this.categoryId,
    this.categoryName,
    this.categoryGroupName,
    this.paymentMethodId,
    this.paymentMethodName,
    this.budgetId,
    this.linkedTransactionId,
    required this.status,
    this.actualAmount,
    this.completedDate,
    required this.isRecurring,
    this.frequency,
    required this.visibility,
    required this.authorName,
    required this.createdAt,
    this.priority = 'MEDIUM',
    this.estimatedMin,
    this.estimatedMax,
    this.tags = const [],
    this.weekNumber,
  });

  /// Variance between planned and actual amount (negative = saved, positive = overspent).
  int? get variance =>
      actualAmount != null ? actualAmount! - amount : null;

  /// Whether this plan is a wishlist item (no fixed date).
  bool get isWishlist => status == 'WISHLIST';

  /// Human-readable price range text for wishlist items.
  String get priceRangeText {
    final fmt = NumberFormat('#,###');
    if (estimatedMin != null && estimatedMax != null) {
      return '${fmt.format(estimatedMin)}~${fmt.format(estimatedMax)}원';
    }
    if (amount > 0) return '${fmt.format(amount)}원';
    return '미정';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        amount,
        targetDate,
        memo,
        categoryId,
        categoryName,
        categoryGroupName,
        paymentMethodId,
        paymentMethodName,
        budgetId,
        linkedTransactionId,
        status,
        actualAmount,
        completedDate,
        isRecurring,
        frequency,
        visibility,
        authorName,
        createdAt,
        priority,
        estimatedMin,
        estimatedMax,
        tags,
        weekNumber,
      ];
}

class SpendingPlanSummary extends Equatable {
  final int totalPlanned;
  final int totalCompleted;
  final int totalSkipped;
  final int plannedCount;
  final int completedCount;
  final int overdueCount;

  const SpendingPlanSummary({
    required this.totalPlanned,
    required this.totalCompleted,
    required this.totalSkipped,
    required this.plannedCount,
    required this.completedCount,
    required this.overdueCount,
  });

  int get totalCount => plannedCount + completedCount + overdueCount;

  @override
  List<Object?> get props => [
        totalPlanned,
        totalCompleted,
        totalSkipped,
        plannedCount,
        completedCount,
        overdueCount,
      ];
}

class SpendingPlanSuggestion extends Equatable {
  final String planId;
  final String name;
  final int plannedAmount;
  final double matchScore;

  const SpendingPlanSuggestion({
    required this.planId,
    required this.name,
    required this.plannedAmount,
    required this.matchScore,
  });

  @override
  List<Object?> get props => [planId, name, plannedAmount, matchScore];
}
