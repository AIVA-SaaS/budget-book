import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository transactionRepository;

  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;
  String? _currentKeyword;
  String? _currentPaymentMethodId;
  String? _currentPocketId;
  int? _currentAmountMin;
  int? _currentAmountMax;

  TransactionBloc({required this.transactionRepository})
      : super(const TransactionInitial()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<LoadMoreTransactions>(_onLoadMoreTransactions);
    on<CreateTransaction>(_onCreateTransaction);
    on<UpdateTransaction>(_onUpdateTransaction);
    on<DeleteTransaction>(_onDeleteTransaction);
  }

  static const int _pageSize = 30;

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    _currentYear = event.year;
    _currentMonth = event.month;
    _currentKeyword = event.keyword;
    _currentPaymentMethodId = event.paymentMethodId;
    _currentPocketId = event.pocketId;
    _currentAmountMin = event.amountMin;
    _currentAmountMax = event.amountMax;
    emit(const TransactionLoading());

    final result = await transactionRepository.getTransactions(
      year: event.year,
      month: event.month,
      keyword: event.keyword,
      paymentMethodId: event.paymentMethodId,
      pocketId: event.pocketId,
      amountMin: event.amountMin,
      amountMax: event.amountMax,
      page: 0,
      size: _pageSize,
    );
    result.fold(
      (failure) => emit(TransactionError(failure.message)),
      (page) => emit(TransactionLoaded(
        transactions: page.content,
        year: event.year,
        month: event.month,
        totalElements: page.totalElements,
        hasMore: !page.last,
        currentPage: 0,
      )),
    );
  }

  Future<void> _onLoadMoreTransactions(
    LoadMoreTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! TransactionLoaded ||
        !currentState.hasMore ||
        currentState.isLoadingMore) {
      return;
    }

    final nextPage = currentState.currentPage + 1;

    // Emit loading-more state
    emit(TransactionLoaded(
      transactions: currentState.transactions,
      year: currentState.year,
      month: currentState.month,
      totalElements: currentState.totalElements,
      hasMore: currentState.hasMore,
      currentPage: currentState.currentPage,
      isLoadingMore: true,
    ));

    final result = await transactionRepository.getTransactions(
      year: _currentYear,
      month: _currentMonth,
      keyword: _currentKeyword,
      paymentMethodId: _currentPaymentMethodId,
      pocketId: _currentPocketId,
      amountMin: _currentAmountMin,
      amountMax: _currentAmountMax,
      page: nextPage,
      size: _pageSize,
    );

    result.fold(
      (failure) {
        // Revert to non-loading state on error
        emit(TransactionLoaded(
          transactions: currentState.transactions,
          year: currentState.year,
          month: currentState.month,
          totalElements: currentState.totalElements,
          hasMore: currentState.hasMore,
          currentPage: currentState.currentPage,
          isLoadingMore: false,
          operationError: failure.message,
        ));
      },
      (page) {
        final allTransactions = [
          ...currentState.transactions,
          ...page.content,
        ];
        emit(TransactionLoaded(
          transactions: allTransactions,
          year: currentState.year,
          month: currentState.month,
          totalElements: page.totalElements,
          hasMore: !page.last,
          currentPage: nextPage,
        ));
      },
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
      paymentMethodId: event.paymentMethodId,
      pocketId: event.pocketId,
    );
    result.fold(
      (failure) => emit(TransactionError(failure.message)),
      (_) => add(LoadTransactions(
            year: _currentYear,
            month: _currentMonth,
            keyword: _currentKeyword,
            paymentMethodId: _currentPaymentMethodId,
            pocketId: _currentPocketId,
            amountMin: _currentAmountMin,
            amountMax: _currentAmountMax,
          )),
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
      paymentMethodId: event.paymentMethodId,
      pocketId: event.pocketId,
    );
    result.fold(
      (failure) => emit(TransactionError(failure.message)),
      (_) => add(LoadTransactions(
            year: _currentYear,
            month: _currentMonth,
            keyword: _currentKeyword,
            paymentMethodId: _currentPaymentMethodId,
            pocketId: _currentPocketId,
            amountMin: _currentAmountMin,
            amountMax: _currentAmountMax,
          )),
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
            operationSuccess: '거래가 삭제되었습니다',
          ));
        }
      },
    );
  }
}
