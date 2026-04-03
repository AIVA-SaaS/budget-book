import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/statistics/domain/repositories/statistics_repository.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository transactionRepository;
  final StatisticsRepository? statisticsRepository;

  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;
  String? _currentKeyword;
  String? _currentCategoryId;
  String? _currentPaymentMethodId;
  String? _currentPocketId;
  int? _currentAmountMin;
  int? _currentAmountMax;

  TransactionBloc({required this.transactionRepository, this.statisticsRepository})
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
    try {
      final previousState = state;
      _currentYear = event.year;
      _currentMonth = event.month;
      _currentKeyword = event.keyword;
      _currentCategoryId = event.categoryId;
      _currentPaymentMethodId = event.paymentMethodId;
      _currentPocketId = event.pocketId;
      _currentAmountMin = event.amountMin;
      _currentAmountMax = event.amountMax;
      // Only show full loading skeleton on initial load, not during search/filter
      if (previousState is! TransactionLoaded) {
        emit(const TransactionLoading());
      }

      final hasOnlyPaymentMethodFilter = event.paymentMethodId != null &&
          event.keyword == null &&
          event.categoryId == null &&
          event.pocketId == null &&
          event.amountMin == null &&
          event.amountMax == null;

      final hasNoFilters = event.keyword == null &&
          event.categoryId == null &&
          event.paymentMethodId == null &&
          event.pocketId == null &&
          event.amountMin == null &&
          event.amountMax == null;

      final txnFuture = transactionRepository.getTransactions(
        year: event.year,
        month: event.month,
        keyword: event.keyword,
        categoryId: event.categoryId,
        paymentMethodId: event.paymentMethodId,
        pocketId: event.pocketId,
        amountMin: event.amountMin,
        amountMax: event.amountMax,
        page: 0,
        size: _pageSize,
      );

      // Fetch server totals for full-month or payment-method filtered view
      int? serverIncome;
      int? serverExpense;

      if (hasNoFilters && statisticsRepository != null) {
        final results = await Future.wait([
          txnFuture,
          statisticsRepository!.getSummary(year: event.year, month: event.month),
        ]);
        final txnResult = results[0] as Either;
        final summaryResult = results[1] as Either;
        summaryResult.fold((_) {}, (s) {
          serverIncome = (s as dynamic).totalIncome as int;
          serverExpense = (s as dynamic).totalExpense as int;
        });
        txnResult.fold(
          (failure) => emit(TransactionError((failure as dynamic).message as String)),
          (page) => emit(TransactionLoaded(
            transactions: ((page as dynamic).content as List).cast(),
            year: event.year,
            month: event.month,
            totalElements: (page as dynamic).totalElements as int,
            hasMore: !((page as dynamic).last as bool),
            currentPage: 0,
            serverTotalIncome: serverIncome,
            serverTotalExpense: serverExpense,
          )),
        );
        return;
      }

      if (hasOnlyPaymentMethodFilter && statisticsRepository != null) {
        final results = await Future.wait([
          txnFuture,
          statisticsRepository!.getPaymentMethodStats(year: event.year, month: event.month),
        ]);
        final txnResult = results[0] as Either;
        final pmStatsResult = results[1] as Either;
        pmStatsResult.fold((_) {}, (statsList) {
          for (final stat in (statsList as List)) {
            final pmStat = stat as dynamic;
            if (pmStat.paymentMethodId == event.paymentMethodId) {
              serverExpense = pmStat.totalAmount as int;
              serverIncome = 0;
              break;
            }
          }
        });
        txnResult.fold(
          (failure) => emit(TransactionError((failure as dynamic).message as String)),
          (page) => emit(TransactionLoaded(
            transactions: ((page as dynamic).content as List).cast(),
            year: event.year,
            month: event.month,
            totalElements: (page as dynamic).totalElements as int,
            hasMore: !((page as dynamic).last as bool),
            currentPage: 0,
            serverTotalIncome: serverIncome,
            serverTotalExpense: serverExpense,
          )),
        );
        return;
      }

      final result = await txnFuture;
      result.fold(
        (failure) => emit(TransactionError(failure.message)),
        (page) => emit(TransactionLoaded(
          transactions: page.content,
          year: event.year,
          month: event.month,
          totalElements: page.totalElements,
          hasMore: !page.last,
          currentPage: 0,
          scrollToDate: event.scrollToDate,
        )),
      );
    } catch (e) {
      emit(const TransactionError('예기치 않은 오류가 발생했습니다'));
    }
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

    try {
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
        scrollToDate: currentState.scrollToDate,
        serverTotalIncome: currentState.serverTotalIncome,
        serverTotalExpense: currentState.serverTotalExpense,
      ));

      final result = await transactionRepository.getTransactions(
        year: _currentYear,
        month: _currentMonth,
        keyword: _currentKeyword,
        categoryId: _currentCategoryId,
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
            serverTotalIncome: currentState.serverTotalIncome,
            serverTotalExpense: currentState.serverTotalExpense,
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
            scrollToDate: currentState.scrollToDate,
            serverTotalIncome: currentState.serverTotalIncome,
            serverTotalExpense: currentState.serverTotalExpense,
          ));
        },
      );
    } catch (e) {
      emit(TransactionLoaded(
        transactions: currentState.transactions,
        year: currentState.year,
        month: currentState.month,
        totalElements: currentState.totalElements,
        hasMore: currentState.hasMore,
        currentPage: currentState.currentPage,
        isLoadingMore: false,
        operationError: '예기치 않은 오류가 발생했습니다',
        serverTotalIncome: currentState.serverTotalIncome,
        serverTotalExpense: currentState.serverTotalExpense,
      ));
    }
  }

  Future<void> _onCreateTransaction(
    CreateTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
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
              categoryId: _currentCategoryId,
              paymentMethodId: _currentPaymentMethodId,
              pocketId: _currentPocketId,
              amountMin: _currentAmountMin,
              amountMax: _currentAmountMax,
              scrollToDate: event.transactionDate,
            )),
      );
    } catch (e) {
      final currentState = state;
      if (currentState is TransactionLoaded) {
        emit(TransactionLoaded(
          transactions: currentState.transactions,
          year: currentState.year,
          month: currentState.month,
          totalElements: currentState.totalElements,
          hasMore: currentState.hasMore,
          currentPage: currentState.currentPage,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const TransactionError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onUpdateTransaction(
    UpdateTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
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
              categoryId: _currentCategoryId,
              paymentMethodId: _currentPaymentMethodId,
              pocketId: _currentPocketId,
              amountMin: _currentAmountMin,
              amountMax: _currentAmountMax,
              scrollToDate: event.transactionDate,
            )),
      );
    } catch (e) {
      final currentState = state;
      if (currentState is TransactionLoaded) {
        emit(TransactionLoaded(
          transactions: currentState.transactions,
          year: currentState.year,
          month: currentState.month,
          totalElements: currentState.totalElements,
          hasMore: currentState.hasMore,
          currentPage: currentState.currentPage,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const TransactionError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onDeleteTransaction(
    DeleteTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
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
    } catch (e) {
      final currentState = state;
      if (currentState is TransactionLoaded) {
        emit(TransactionLoaded(
          transactions: currentState.transactions,
          year: currentState.year,
          month: currentState.month,
          totalElements: currentState.totalElements,
          hasMore: currentState.hasMore,
          currentPage: currentState.currentPage,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const TransactionError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }
}
