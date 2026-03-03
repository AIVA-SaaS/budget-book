import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository transactionRepository;

  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;

  TransactionBloc({required this.transactionRepository})
      : super(const TransactionInitial()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<CreateTransaction>(_onCreateTransaction);
    on<UpdateTransaction>(_onUpdateTransaction);
    on<DeleteTransaction>(_onDeleteTransaction);
  }

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    _currentYear = event.year;
    _currentMonth = event.month;
    emit(const TransactionLoading());

    final result = await transactionRepository.getTransactions(
      year: event.year,
      month: event.month,
      size: 100,
    );
    result.fold(
      (failure) => emit(TransactionError(failure.message)),
      (page) => emit(TransactionLoaded(
        transactions: page.content,
        year: event.year,
        month: event.month,
        totalElements: page.totalElements,
        hasMore: !page.last,
      )),
    );
  }

  Future<void> _onCreateTransaction(
    CreateTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    final result = await transactionRepository.createTransaction(
      type: event.type,
      amount: event.amount,
      description: event.description,
      categoryId: event.categoryId,
      transactionDate: event.transactionDate,
      memo: event.memo,
    );
    result.fold(
      (failure) => emit(TransactionError(failure.message)),
      (_) => add(LoadTransactions(year: _currentYear, month: _currentMonth)),
    );
  }

  Future<void> _onUpdateTransaction(
    UpdateTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    final result = await transactionRepository.updateTransaction(
      id: event.id,
      amount: event.amount,
      description: event.description,
      categoryId: event.categoryId,
      transactionDate: event.transactionDate,
      memo: event.memo,
      clearMemo: event.clearMemo,
    );
    result.fold(
      (failure) => emit(TransactionError(failure.message)),
      (_) => add(LoadTransactions(year: _currentYear, month: _currentMonth)),
    );
  }

  Future<void> _onDeleteTransaction(
    DeleteTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    final currentState = state;
    final result = await transactionRepository.deleteTransaction(event.id);
    result.fold(
      (failure) {
        if (currentState is TransactionLoaded) {
          emit(TransactionLoaded(
            transactions: currentState.transactions,
            year: currentState.year,
            month: currentState.month,
            totalElements: currentState.totalElements,
            hasMore: currentState.hasMore,
            operationError: failure.message,
          ));
        } else {
          emit(TransactionError(failure.message));
        }
      },
      (_) {
        if (currentState is TransactionLoaded) {
          final updatedList = currentState.transactions
              .where((t) => t.id != event.id)
              .toList();
          emit(TransactionLoaded(
            transactions: updatedList,
            year: currentState.year,
            month: currentState.month,
            totalElements: currentState.totalElements - 1,
            hasMore: currentState.hasMore,
          ));
        }
      },
    );
  }
}
