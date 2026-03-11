import 'package:equatable/equatable.dart';

class RecurringTransaction extends Equatable {
  final String id;
  final String type;
  final int amount;
  final String description;
  final String? memo;
  final String frequency;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final String nextRunDate;
  final String? lastRunDate;
  final bool isActive;
  final String? categoryId;
  final String? categoryName;
  final String? paymentMethodId;
  final String? paymentMethodName;
  final DateTime createdAt;

  const RecurringTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.memo,
    required this.frequency,
    this.dayOfMonth,
    this.dayOfWeek,
    required this.nextRunDate,
    this.lastRunDate,
    required this.isActive,
    this.categoryId,
    this.categoryName,
    this.paymentMethodId,
    this.paymentMethodName,
    required this.createdAt,
  });

  bool get isExpense => type == 'EXPENSE';
  bool get isIncome => type == 'INCOME';

  String get frequencyLabel => switch (frequency) {
        'DAILY' => '매일',
        'WEEKLY' => '매주',
        'MONTHLY' => '매월',
        'YEARLY' => '매년',
        _ => frequency,
      };

  @override
  List<Object?> get props => [
        id,
        type,
        amount,
        description,
        memo,
        frequency,
        dayOfMonth,
        dayOfWeek,
        nextRunDate,
        lastRunDate,
        isActive,
        categoryId,
        categoryName,
        paymentMethodId,
        paymentMethodName,
        createdAt,
      ];
}
