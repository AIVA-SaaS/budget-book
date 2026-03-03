import 'package:equatable/equatable.dart';

sealed class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactions extends TransactionEvent {
  final int year;
  final int month;

  const LoadTransactions({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class CreateTransaction extends TransactionEvent {
  final String type;
  final int amount;
  final String description;
  final String? categoryId;
  final String transactionDate;
  final String? memo;

  const CreateTransaction({
    required this.type,
    required this.amount,
    required this.description,
    this.categoryId,
    required this.transactionDate,
    this.memo,
  });

  @override
  List<Object?> get props =>
      [type, amount, description, categoryId, transactionDate, memo];
}

class UpdateTransaction extends TransactionEvent {
  final String id;
  final int? amount;
  final String? description;
  final String? categoryId;
  final String? transactionDate;
  final String? memo;
  final bool clearMemo;

  const UpdateTransaction({
    required this.id,
    this.amount,
    this.description,
    this.categoryId,
    this.transactionDate,
    this.memo,
    this.clearMemo = false,
  });

  @override
  List<Object?> get props =>
      [id, amount, description, categoryId, transactionDate, memo, clearMemo];
}

class DeleteTransaction extends TransactionEvent {
  final String id;

  const DeleteTransaction(this.id);

  @override
  List<Object?> get props => [id];
}
