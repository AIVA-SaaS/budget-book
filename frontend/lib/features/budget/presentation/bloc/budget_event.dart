import 'package:equatable/equatable.dart';

sealed class BudgetEvent extends Equatable {
  const BudgetEvent();

  @override
  List<Object?> get props => [];
}

class LoadBudgets extends BudgetEvent {
  final int year;
  final int month;

  const LoadBudgets({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class LoadBudgetSummary extends BudgetEvent {
  final int year;
  final int month;

  const LoadBudgetSummary({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class CreateBudget extends BudgetEvent {
  final String? categoryId;
  final String? groupId;
  final String yearMonth;
  final int amount;
  final String budgetPeriod;
  final int? weeklyAmount;
  final String? pocketId;
  final String periodType;
  final DateTime? startDate;
  final DateTime? endDate;
  /// Phase 23 PR-X4: 템플릿 종료월 (null = 무기한).
  final String? endYearMonth;
  /// Phase 23 PR-X4: 'TEMPLATE' | 'OVERRIDE' (null = backend 기본 TEMPLATE).
  final String? rowKind;

  const CreateBudget({
    this.categoryId,
    this.groupId,
    required this.yearMonth,
    required this.amount,
    this.budgetPeriod = 'MONTHLY',
    this.weeklyAmount,
    this.pocketId,
    this.periodType = 'MONTHLY',
    this.startDate,
    this.endDate,
    this.endYearMonth,
    this.rowKind,
  });

  @override
  List<Object?> get props => [
        categoryId,
        groupId,
        yearMonth,
        amount,
        budgetPeriod,
        weeklyAmount,
        pocketId,
        periodType,
        startDate,
        endDate,
        endYearMonth,
        rowKind,
      ];
}

/// Phase 23 PR-X4: 특정 월 OVERRIDE upsert 이벤트.
class UpsertMonthOverride extends BudgetEvent {
  final String? categoryId;
  final String? groupId;
  final String yearMonth;
  final int amount;
  final String budgetPeriod;
  final int? weeklyAmount;
  final String? pocketId;

  const UpsertMonthOverride({
    this.categoryId,
    this.groupId,
    required this.yearMonth,
    required this.amount,
    this.budgetPeriod = 'MONTHLY',
    this.weeklyAmount,
    this.pocketId,
  });

  @override
  List<Object?> get props => [
        categoryId,
        groupId,
        yearMonth,
        amount,
        budgetPeriod,
        weeklyAmount,
        pocketId,
      ];
}

class UpdateBudget extends BudgetEvent {
  final String id;
  final int amount;
  final String? budgetPeriod;
  final int? weeklyAmount;
  final String? pocketId;
  final String? periodType;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final String? groupId;
  final String? yearMonth;
  /// Phase 23 PR-X4: 템플릿 종료월 수정 (TEMPLATE row 만 반영).
  final String? endYearMonth;

  const UpdateBudget({
    required this.id,
    required this.amount,
    this.budgetPeriod,
    this.weeklyAmount,
    this.pocketId,
    this.periodType,
    this.startDate,
    this.endDate,
    this.categoryId,
    this.groupId,
    this.yearMonth,
    this.endYearMonth,
  });

  @override
  List<Object?> get props => [
        id,
        amount,
        budgetPeriod,
        weeklyAmount,
        pocketId,
        periodType,
        startDate,
        endDate,
        categoryId,
        groupId,
        yearMonth,
        endYearMonth,
      ];
}

class DeleteBudget extends BudgetEvent {
  final String id;
  /// Phase 23 PR-X4: true 면 해당 월 이후 모두 삭제 (템플릿 범위 단축 + 후속 overrides 삭제).
  final bool cascadeFuture;

  const DeleteBudget(this.id, {this.cascadeFuture = false});

  @override
  List<Object?> get props => [id, cascadeFuture];
}

class CopyPreviousMonthBudgets extends BudgetEvent {
  final int year;
  final int month;

  const CopyPreviousMonthBudgets({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}
