import 'package:budget_book/features/recurring/domain/entities/recurring_transaction.dart';

class RecurringTransactionModel extends RecurringTransaction {
  const RecurringTransactionModel({
    required super.id,
    required super.type,
    required super.amount,
    required super.description,
    super.memo,
    required super.frequency,
    super.dayOfMonth,
    super.dayOfWeek,
    required super.nextRunDate,
    super.lastRunDate,
    required super.isActive,
    super.categoryId,
    super.categoryName,
    super.paymentMethodId,
    super.paymentMethodName,
    super.visibility,
    super.ownerId,
    required super.createdAt,
  });

  factory RecurringTransactionModel.fromJson(Map<String, dynamic> json) {
    return RecurringTransactionModel(
      id: json['id'] as String,
      type: json['type'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String,
      memo: json['memo'] as String?,
      frequency: json['frequency'] as String,
      dayOfMonth: json['dayOfMonth'] as int?,
      dayOfWeek: json['dayOfWeek'] as int?,
      nextRunDate: json['nextRunDate'] as String,
      lastRunDate: json['lastRunDate'] as String?,
      isActive: json['isActive'] as bool,
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
      paymentMethodId: json['paymentMethodId'] as String?,
      paymentMethodName: json['paymentMethodName'] as String?,
      visibility: json['visibility'] as String? ?? 'SHARED',
      ownerId: json['ownerId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
