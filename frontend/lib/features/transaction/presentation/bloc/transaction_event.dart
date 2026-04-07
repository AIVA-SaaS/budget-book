import 'package:equatable/equatable.dart';

sealed class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactions extends TransactionEvent {
  final int year;
  final int month;
  final String? keyword;
  final String? paymentMethodId;
  final String? pocketId;
  final int? amountMin;
  final int? amountMax;
  final String? scrollToDate;
  final String? categoryId;
  final String? dateFrom;
  final String? dateTo;

  const LoadTransactions({
    required this.year,
    required this.month,
    this.keyword,
    this.paymentMethodId,
    this.pocketId,
    this.amountMin,
    this.amountMax,
    this.scrollToDate,
    this.categoryId,
    this.dateFrom,
    this.dateTo,
  });

  @override
  List<Object?> get props =>
      [year, month, keyword, paymentMethodId, pocketId, amountMin, amountMax, scrollToDate, categoryId, dateFrom, dateTo];
}

class CreateTransaction extends TransactionEvent {
  final String type;
  final int amount;
  final String description;
  final String? categoryId;
  final String transactionDate;
  final String? memo;
  final String? paymentMethodId;
  final String? pocketId;

  const CreateTransaction({
    required this.type,
    required this.amount,
    required this.description,
    this.categoryId,
    required this.transactionDate,
    this.memo,
    this.paymentMethodId,
    this.pocketId,
  });

  @override
  List<Object?> get props =>
      [type, amount, description, categoryId, transactionDate, memo, paymentMethodId, pocketId];
}

class UpdateTransaction extends TransactionEvent {
  final String id;
  final int? amount;
  final String? description;
  final String? categoryId;
  final String? transactionDate;
  final String? memo;
  final bool clearMemo;
  final String? paymentMethodId;
  final String? pocketId;

  const UpdateTransaction({
    required this.id,
    this.amount,
    this.description,
    this.categoryId,
    this.transactionDate,
    this.memo,
    this.clearMemo = false,
    this.paymentMethodId,
    this.pocketId,
  });

  @override
  List<Object?> get props =>
      [id, amount, description, categoryId, transactionDate, memo, clearMemo, paymentMethodId, pocketId];
}

class LoadMoreTransactions extends TransactionEvent {
  const LoadMoreTransactions();
}

class DeleteTransaction extends TransactionEvent {
  final String id;

  const DeleteTransaction(this.id);

  @override
  List<Object?> get props => [id];
}
