import 'package:equatable/equatable.dart';

sealed class TransferEvent extends Equatable {
  const TransferEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransfers extends TransferEvent {
  final int year;
  final int month;

  const LoadTransfers({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class CreateTransfer extends TransferEvent {
  final String sourcePaymentMethodId;
  final String destinationPaymentMethodId;
  final int amount;
  final String? description;
  final String transferDate;
  final String? memo;

  const CreateTransfer({
    required this.sourcePaymentMethodId,
    required this.destinationPaymentMethodId,
    required this.amount,
    this.description,
    required this.transferDate,
    this.memo,
  });

  @override
  List<Object?> get props => [
        sourcePaymentMethodId,
        destinationPaymentMethodId,
        amount,
        description,
        transferDate,
        memo,
      ];
}

class UpdateTransfer extends TransferEvent {
  final String id;
  final String? sourcePaymentMethodId;
  final String? destinationPaymentMethodId;
  final int? amount;
  final String? description;
  final bool clearDescription;
  final String? transferDate;
  final String? memo;
  final bool clearMemo;

  const UpdateTransfer({
    required this.id,
    this.sourcePaymentMethodId,
    this.destinationPaymentMethodId,
    this.amount,
    this.description,
    this.clearDescription = false,
    this.transferDate,
    this.memo,
    this.clearMemo = false,
  });

  @override
  List<Object?> get props => [
        id,
        sourcePaymentMethodId,
        destinationPaymentMethodId,
        amount,
        description,
        clearDescription,
        transferDate,
        memo,
        clearMemo,
      ];
}

class DeleteTransfer extends TransferEvent {
  final String id;

  const DeleteTransfer(this.id);

  @override
  List<Object?> get props => [id];
}
