import 'package:budget_book/features/report/domain/entities/monthly_report.dart';

class GroupSummaryModel extends GroupSummary {
  const GroupSummaryModel({
    required super.groupId,
    required super.groupName,
    required super.budgetType,
    required super.totalBudget,
    required super.totalSpent,
    required super.usageRate,
  });

  factory GroupSummaryModel.fromJson(Map<String, dynamic> json) {
    return GroupSummaryModel(
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      budgetType: json['budgetType'] as String,
      totalBudget: json['totalBudget'] as int,
      totalSpent: json['totalSpent'] as int,
      usageRate: (json['usageRate'] as num).toDouble(),
    );
  }
}

class TopCategoryModel extends TopCategory {
  const TopCategoryModel({
    required super.categoryId,
    required super.categoryName,
    required super.categoryType,
    super.categoryIcon,
    super.categoryColor,
    required super.amount,
    required super.averageAmount,
    required super.deviation,
    required super.transactionCount,
  });

  factory TopCategoryModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>;
    return TopCategoryModel(
      categoryId: category['id'] as String,
      categoryName: category['name'] as String,
      categoryType: category['type'] as String,
      categoryIcon: category['icon'] as String?,
      categoryColor: category['color'] as String?,
      amount: json['amount'] as int,
      averageAmount: json['averageAmount'] as int,
      deviation: json['deviation'] as int,
      transactionCount: json['transactionCount'] as int,
    );
  }
}

class MonthComparisonModel extends MonthComparison {
  const MonthComparisonModel({
    required super.previousYearMonth,
    required super.incomeChange,
    required super.expenseChange,
    required super.incomeChangeRate,
    required super.expenseChangeRate,
  });

  factory MonthComparisonModel.fromJson(Map<String, dynamic> json) {
    return MonthComparisonModel(
      previousYearMonth: json['previousYearMonth'] as String,
      incomeChange: json['incomeChange'] as int,
      expenseChange: json['expenseChange'] as int,
      incomeChangeRate: (json['incomeChangeRate'] as num).toDouble(),
      expenseChangeRate: (json['expenseChangeRate'] as num).toDouble(),
    );
  }
}

class CardPendingSummaryModel extends CardPendingSummary {
  const CardPendingSummaryModel({
    required super.totalPendingAmount,
    required super.cardCount,
  });

  factory CardPendingSummaryModel.fromJson(Map<String, dynamic> json) {
    return CardPendingSummaryModel(
      totalPendingAmount: json['totalPendingAmount'] as int,
      cardCount: json['cardCount'] as int,
    );
  }
}

class DayOfWeekPatternModel extends DayOfWeekPattern {
  const DayOfWeekPatternModel({
    required super.dayOfWeek,
    required super.averageSpending,
    required super.totalSpending,
    required super.transactionCount,
  });

  factory DayOfWeekPatternModel.fromJson(Map<String, dynamic> json) {
    return DayOfWeekPatternModel(
      dayOfWeek: json['dayOfWeek'] as String,
      averageSpending: json['averageSpending'] as int,
      totalSpending: json['totalSpending'] as int,
      transactionCount: json['transactionCount'] as int,
    );
  }
}

class MonthlyReportModel extends MonthlyReport {
  const MonthlyReportModel({
    required super.yearMonth,
    required super.totalIncome,
    required super.totalExpense,
    required super.balance,
    required super.groupSummaries,
    required super.topCategories,
    super.previousMonthComparison,
    super.cardPendingSummary,
    required super.dayOfWeekPattern,
  });

  factory MonthlyReportModel.fromJson(Map<String, dynamic> json) {
    return MonthlyReportModel(
      yearMonth: json['yearMonth'] as String,
      totalIncome: json['totalIncome'] as int,
      totalExpense: json['totalExpense'] as int,
      balance: json['balance'] as int,
      groupSummaries: (json['groupSummaries'] as List<dynamic>)
          .map((e) => GroupSummaryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      topCategories: (json['topCategories'] as List<dynamic>)
          .map((e) => TopCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      previousMonthComparison: json['previousMonthComparison'] != null
          ? MonthComparisonModel.fromJson(
              json['previousMonthComparison'] as Map<String, dynamic>)
          : null,
      cardPendingSummary: json['cardPendingSummary'] != null
          ? CardPendingSummaryModel.fromJson(
              json['cardPendingSummary'] as Map<String, dynamic>)
          : null,
      dayOfWeekPattern: (json['dayOfWeekPattern'] as List<dynamic>)
          .map(
              (e) => DayOfWeekPatternModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
