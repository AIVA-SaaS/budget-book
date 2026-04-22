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
  final String? categoryId;
  final Set<String> categoryIds;
  final Set<String> categoryGroupIds;
  final String? paymentMethodId;
  final Set<String> paymentMethodIds;
  final String? pocketId;
  final Set<String> pocketIds;
  final int? amountMin;
  final int? amountMax;
  final String? scrollToDate;
  final String? dateFrom;
  final String? dateTo;
  final String? type;
  final Set<String> transactionTypes;
  final String? visibility;

  const LoadTransactions({
    required this.year,
    required this.month,
    this.keyword,
    this.categoryId,
    this.categoryIds = const {},
    this.categoryGroupIds = const {},
    this.paymentMethodId,
    this.paymentMethodIds = const {},
    this.pocketId,
    this.pocketIds = const {},
    this.amountMin,
    this.amountMax,
    this.scrollToDate,
    this.dateFrom,
    this.dateTo,
    this.type,
    this.transactionTypes = const {},
    this.visibility,
  });

  @override
  List<Object?> get props => [
        year,
        month,
        keyword,
        categoryId,
        categoryIds,
        categoryGroupIds,
        paymentMethodId,
        paymentMethodIds,
        pocketId,
        pocketIds,
        amountMin,
        amountMax,
        scrollToDate,
        dateFrom,
        dateTo,
        type,
        transactionTypes,
        visibility,
      ];
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
