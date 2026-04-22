import 'package:equatable/equatable.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

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
  final TransferKind kind;

  const CreateTransfer({
    required this.sourcePaymentMethodId,
    required this.destinationPaymentMethodId,
    required this.amount,
    this.description,
    required this.transferDate,
    this.memo,
    this.kind = TransferKind.generic,
  });

  @override
  List<Object?> get props => [
        sourcePaymentMethodId,
        destinationPaymentMethodId,
        amount,
        description,
        transferDate,
        memo,
        kind,
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
  final TransferKind? kind;

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
    this.kind,
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
        kind,
      ];
}

class DeleteTransfer extends TransferEvent {
  final String id;

  const DeleteTransfer(this.id);

  @override
  List<Object?> get props => [id];
}
