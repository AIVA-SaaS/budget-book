import 'package:equatable/equatable.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';

sealed class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {
  const TransactionInitial();
}

class TransactionLoading extends TransactionState {
  const TransactionLoading();
}

class TransactionLoaded extends TransactionState {
  final List<Transaction> transactions;
  final int year;
  final int month;
  final int totalElements;
  final bool hasMore;
  final String? operationError;

  const TransactionLoaded({
    required this.transactions,
    required this.year,
    required this.month,
    required this.totalElements,
    required this.hasMore,
    this.operationError,
  });

  int get totalIncome => transactions
      .where((t) => t.isIncome)
      .fold(0, (sum, t) => sum + t.amount);

  int get totalExpense => transactions
      .where((t) => t.isExpense)
      .fold(0, (sum, t) => sum + t.amount);

  int get balance => totalIncome - totalExpense;

  Map<String, List<Transaction>> get groupedByDate {
    final grouped = <String, List<Transaction>>{};
    for (final t in transactions) {
      grouped.putIfAbsent(t.transactionDate, () => []).add(t);
    }
    return grouped;
  }

  @override
  List<Object?> get props =>
      [transactions, year, month, totalElements, hasMore, operationError];
}

class TransactionError extends TransactionState {
  final String message;

  const TransactionError(this.message);

  @override
  List<Object?> get props => [message];
}
