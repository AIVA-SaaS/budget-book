import 'package:equatable/equatable.dart';

sealed class RecurringEvent extends Equatable {
  const RecurringEvent();

  @override
  List<Object?> get props => [];
}

class LoadRecurringTransactions extends RecurringEvent {
  const LoadRecurringTransactions();
}

class CreateRecurringTransaction extends RecurringEvent {
  final String type;
  final int amount;
  final String description;
  final String? memo;
  final String frequency;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final String? categoryId;
  final String? paymentMethodId;

  const CreateRecurringTransaction({
    required this.type,
    required this.amount,
    required this.description,
    this.memo,
    required this.frequency,
    this.dayOfMonth,
    this.dayOfWeek,
    this.categoryId,
    this.paymentMethodId,
  });

  @override
  List<Object?> get props => [
        type,
        amount,
        description,
        memo,
        frequency,
        dayOfMonth,
        dayOfWeek,
        categoryId,
        paymentMethodId,
      ];
}

class UpdateRecurringTransaction extends RecurringEvent {
  final String id;
  final int? amount;
  final String? description;
  final String? memo;
  final String? categoryId;
  final String? paymentMethodId;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final bool? isActive;

  const UpdateRecurringTransaction({
    required this.id,
    this.amount,
    this.description,
    this.memo,
    this.categoryId,
    this.paymentMethodId,
    this.dayOfMonth,
    this.dayOfWeek,
    this.isActive,
  });

  @override
  List<Object?> get props => [
        id,
        amount,
        description,
        memo,
        categoryId,
        paymentMethodId,
        dayOfMonth,
        dayOfWeek,
        isActive,
      ];
}

class DeleteRecurringTransaction extends RecurringEvent {
  final String id;

  const DeleteRecurringTransaction(this.id);

  @override
  List<Object?> get props => [id];
}
