import 'package:equatable/equatable.dart';
import 'package:budget_book/features/pocket/domain/entities/pocket_transfer.dart';

sealed class PocketTransferState extends Equatable {
  const PocketTransferState();

  @override
  List<Object?> get props => [];
}

class PocketTransferInitial extends PocketTransferState {
  const PocketTransferInitial();
}

class PocketTransferLoading extends PocketTransferState {
  const PocketTransferLoading();
}

class PocketTransferLoaded extends PocketTransferState {
  final List<PocketTransfer> transfers;
  final String? operationError;

  const PocketTransferLoaded(this.transfers, {this.operationError});

  @override
  List<Object?> get props => [transfers, operationError];
}

class PocketTransferError extends PocketTransferState {
  final String message;

  const PocketTransferError(this.message);

  @override
  List<Object?> get props => [message];
}
