import 'package:equatable/equatable.dart';

sealed class PocketTransferEvent extends Equatable {
  const PocketTransferEvent();

  @override
  List<Object?> get props => [];
}

class LoadPocketTransfers extends PocketTransferEvent {
  final String? fromPocketId;
  final String? toPocketId;
  final String? startDate;
  final String? endDate;

  const LoadPocketTransfers({
    this.fromPocketId,
    this.toPocketId,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [fromPocketId, toPocketId, startDate, endDate];
}

class CreatePocketTransfer extends PocketTransferEvent {
  final String fromPocketId;
  final String toPocketId;
  final int amount;
  final String? description;
  final String transferDate;

  const CreatePocketTransfer({
    required this.fromPocketId,
    required this.toPocketId,
    required this.amount,
    this.description,
    required this.transferDate,
  });

  @override
  List<Object?> get props =>
      [fromPocketId, toPocketId, amount, description, transferDate];
}
