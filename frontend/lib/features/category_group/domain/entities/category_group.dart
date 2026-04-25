import 'package:equatable/equatable.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';

class CategoryGroup extends Equatable {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final String budgetType; // WEEKLY, MONTHLY, NONE
  final int displayOrder;
  final bool isDefault;
  final List<Category> categories;
  final String visibility;
  final String? ownerId;
  final DateTime createdAt;
  /// Phase 25 후속 — EXPENSE/INCOME (그룹의 카테고리 종류).
  final String categoryType;

  const CategoryGroup({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    required this.budgetType,
    required this.displayOrder,
    required this.isDefault,
    required this.categories,
    this.visibility = 'SHARED',
    this.ownerId,
    required this.createdAt,
    this.categoryType = 'EXPENSE',
  });

  bool get isWeekly => budgetType == 'WEEKLY';
  bool get isMonthly => budgetType == 'MONTHLY';
  bool get isPrivate => visibility == 'PRIVATE';
  bool get isShared => visibility == 'SHARED';
  bool get isExpense => categoryType == 'EXPENSE';
  bool get isIncome => categoryType == 'INCOME';

  @override
  List<Object?> get props => [
        id,
        name,
        icon,
        color,
        budgetType,
        displayOrder,
        isDefault,
        categories,
        visibility,
        ownerId,
        createdAt,
        categoryType,
      ];
}
