import 'package:equatable/equatable.dart';
import 'package:budget_book/features/recurring/domain/entities/recurring_transaction.dart';

sealed class RecurringState extends Equatable {
  const RecurringState();

  @override
  List<Object?> get props => [];
}

class RecurringInitial extends RecurringState {
  const RecurringInitial();
}

class RecurringLoading extends RecurringState {
  const RecurringLoading();
}

class RecurringLoaded extends RecurringState {
  final List<RecurringTransaction> transactions;
  final String? operationError;

  const RecurringLoaded(this.transactions, {this.operationError});

  List<RecurringTransaction> get activeTransactions =>
      transactions.where((t) => t.isActive).toList();

  List<RecurringTransaction> get inactiveTransactions =>
      transactions.where((t) => !t.isActive).toList();

  @override
  List<Object?> get props => [transactions, operationError];
}

class RecurringError extends RecurringState {
  final String message;

  const RecurringError(this.message);

  @override
  List<Object?> get props => [message];
}
