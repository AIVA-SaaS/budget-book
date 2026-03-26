import 'package:equatable/equatable.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

sealed class TransferState extends Equatable {
  const TransferState();

  @override
  List<Object?> get props => [];
}

class TransferInitial extends TransferState {
  const TransferInitial();
}

class TransferLoading extends TransferState {
  const TransferLoading();
}

class TransferLoaded extends TransferState {
  final List<Transfer> transfers;
  final int year;
  final int month;
  final String? operationError;
  final String? operationSuccess;

  const TransferLoaded({
    required this.transfers,
    required this.year,
    required this.month,
    this.operationError,
    this.operationSuccess,
  });

  int get totalAmount =>
      transfers.fold(0, (sum, t) => sum + t.amount);

  Map<String, List<Transfer>> get groupedByDate {
    final grouped = <String, List<Transfer>>{};
    for (final t in transfers) {
      grouped.putIfAbsent(t.transferDate, () => []).add(t);
    }
    return grouped;
  }

  @override
  List<Object?> get props =>
      [transfers, year, month, operationError, operationSuccess];
}

class TransferError extends TransferState {
  final String message;

  const TransferError(this.message);

  @override
  List<Object?> get props => [message];
}
