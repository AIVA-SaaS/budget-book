import 'package:equatable/equatable.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';

class Budget extends Equatable {
  final String id;
  final String coupleId;
  final TransactionCategory? category;
  final String? groupId;
  final String? groupName;
  final String yearMonth;
  final int amount;
  final String budgetPeriod;
  final int? weeklyAmount;
  final String? pocketId;
  final String? pocketName;
  final String periodType;
  final DateTime? startDate;
  final DateTime? endDate;
  final String visibility;
  final String? ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    required this.coupleId,
    this.category,
    this.groupId,
    this.groupName,
    required this.yearMonth,
    required this.amount,
    this.budgetPeriod = 'MONTHLY',
    this.weeklyAmount,
    this.pocketId,
    this.pocketName,
    this.periodType = 'MONTHLY',
    this.startDate,
    this.endDate,
    this.visibility = 'SHARED',
    this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display label for this budget target (category, group, or total).
  String get targetLabel {
    if (category != null) return category!.name;
    if (groupName != null) return '$groupName (그룹)';
    return '전체 예산';
  }

  /// For WEEKLY budgets, calculate the effective monthly amount
  /// using pro-rata (weeklyAmount * daysInMonth / 7).
  /// For MONTHLY budgets, returns amount as-is.
  int get effectiveMonthlyAmount {
    if (budgetPeriod != 'WEEKLY' || weeklyAmount == null) return amount;

    // Parse yearMonth to get days in month
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Pro-rata: weeklyAmount * daysInMonth / 7
    return (weeklyAmount! * daysInMonth) ~/ 7;
  }

  bool get isPrivate => visibility == 'PRIVATE';
  bool get isShared => visibility == 'SHARED';

  @override
  List<Object?> get props => [
        id,
        coupleId,
        category,
        groupId,
        groupName,
        yearMonth,
        amount,
        budgetPeriod,
        weeklyAmount,
        pocketId,
        pocketName,
        periodType,
        startDate,
        endDate,
        visibility,
        ownerId,
        createdAt,
        updatedAt,
      ];
}

class BudgetSummary extends Equatable {
  final String yearMonth;
  final int totalBudget;
  final int totalSpent;
  final List<BudgetSummaryItem> items;

  const BudgetSummary({
    required this.yearMonth,
    required this.totalBudget,
    required this.totalSpent,
    required this.items,
  });

  int get remainingAmount => totalBudget - totalSpent;

  int get totalPlanned => items.fold(0, (sum, item) => sum + item.plannedAmount);

  double get usageRate =>
      totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0;

  bool get isOverBudget => totalSpent > totalBudget;

  @override
  List<Object?> get props => [yearMonth, totalBudget, totalSpent, items];
}

class BudgetSummaryItem extends Equatable {
  final TransactionCategory? category;
  final String? groupId;
  final String? groupName;
  final int budgetAmount;
  final int spentAmount;
  final int plannedAmount;
  final int remainingAmount;
  final double usageRate;

  const BudgetSummaryItem({
    this.category,
    this.groupId,
    this.groupName,
    required this.budgetAmount,
    required this.spentAmount,
    this.plannedAmount = 0,
    required this.remainingAmount,
    required this.usageRate,
  });

  bool get isOverBudget => spentAmount > budgetAmount;

  /// Total committed = spent + planned
  int get committedAmount => spentAmount + plannedAmount;

  /// Whether committed (spent + planned) exceeds budget
  bool get isOverCommitted => committedAmount > budgetAmount;

  @override
  List<Object?> get props =>
      [category, groupId, groupName, budgetAmount, spentAmount, plannedAmount, remainingAmount, usageRate];
}
