import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
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
  String? get currentCategoryId => _currentCategoryId;
  Set<String> _currentCategoryIds = const {};
  Set<String> get currentCategoryIds => _currentCategoryIds;
  Set<String> _currentCategoryGroupIds = const {};
  Set<String> get currentCategoryGroupIds => _currentCategoryGroupIds;
  String? _currentPaymentMethodId;
  String? get currentPaymentMethodId => _currentPaymentMethodId;
  Set<String> _currentPaymentMethodIds = const {};
  Set<String> get currentPaymentMethodIds => _currentPaymentMethodIds;
  String? _currentPocketId;
  Set<String> _currentPocketIds = const {};
  Set<String> get currentPocketIds => _currentPocketIds;
  int? _currentAmountMin;
  int? _currentAmountMax;
  String? _currentDateFrom;
  String? _currentDateTo;
  String? _currentType;
  Set<String> _currentTransactionTypes = const {};
  String? _currentVisibility;

  /// 전체 필터 상태의 단일 스냅샷.
  /// MonthSyncHandler 등 외부 consumer 가 필드 drop 없이 전체 필터를 전파하도록
  /// 반드시 이 getter 를 사용한다. 새 필터 추가 시 TransactionFilter 와
  /// LoadTransactions 시그니처, 이 getter 세 군데를 함께 수정해야 컴파일 통과.
  TransactionFilter get currentFilter => TransactionFilter(
        keyword: _currentKeyword,
        categoryId: _currentCategoryId,
        categoryIds: _currentCategoryIds,
        categoryGroupIds: _currentCategoryGroupIds,
        paymentMethodId: _currentPaymentMethodId,
        paymentMethodIds: _currentPaymentMethodIds,
        pocketId: _currentPocketId,
        pocketIds: _currentPocketIds,
        amountMin: _currentAmountMin,
        amountMax: _currentAmountMax,
        dateFrom: _currentDateFrom,
        dateTo: _currentDateTo,
        type: _currentType,
        transactionTypes: _currentTransactionTypes,
        visibility: _currentVisibility,
      );

  int get currentYear => _currentYear;
  int get currentMonth => _currentMonth;

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
      _currentCategoryIds = event.categoryIds;
      _currentCategoryGroupIds = event.categoryGroupIds;
      _currentPaymentMethodId = event.paymentMethodId;
      _currentPaymentMethodIds = event.paymentMethodIds;
      _currentPocketId = event.pocketId;
      _currentPocketIds = event.pocketIds;
      _currentAmountMin = event.amountMin;
      _currentAmountMax = event.amountMax;
      _currentDateFrom = event.dateFrom;
      _currentDateTo = event.dateTo;
      _currentType = event.type;
      _currentTransactionTypes = event.transactionTypes;
      _currentVisibility = event.visibility;
      // Only show full loading skeleton on initial load, not during search/filter
      if (previousState is! TransactionLoaded) {
        emit(const TransactionLoading());
      }

      // 회차 8 — BE getSummary 가 모든 필터 지원하도록 확장됨.
      // 이전 hasNoFilters / hasOnlyPaymentMethodFilter 분기 제거.
      // 항상 BE summary 호출 + 모든 필터 전달 → 정확한 (filtered) 월 합계.
      // FE 의 client-side fold (page 단위 부정확) 는 제거됨.
      final txnFuture = transactionRepository.getTransactions(
        year: event.year,
        month: event.month,
        keyword: event.keyword,
        categoryId: event.categoryId,
        categoryIds: event.categoryIds,
        categoryGroupIds: event.categoryGroupIds,
        paymentMethodId: event.paymentMethodId,
        paymentMethodIds: event.paymentMethodIds,
        pocketId: event.pocketId,
        pocketIds: event.pocketIds,
        amountMin: event.amountMin,
        amountMax: event.amountMax,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        type: event.type,
        transactionTypes: event.transactionTypes,
        visibility: event.visibility,
        page: 0,
        size: _pageSize,
      );

      int? serverIncome;
      int? serverExpense;

      if (statisticsRepository != null) {
        final results = await Future.wait([
          txnFuture,
          statisticsRepository!.getSummary(
            year: event.year,
            month: event.month,
            visibility: event.visibility ?? 'ALL',
            dateFrom: event.dateFrom,
            dateTo: event.dateTo,
            categoryId: event.categoryId,
            paymentMethodId: event.paymentMethodId,
            pocketId: event.pocketId,
            categoryIds: event.categoryIds,
            categoryGroupIds: event.categoryGroupIds,
            paymentMethodIds: event.paymentMethodIds,
            pocketIds: event.pocketIds,
            amountMin: event.amountMin,
            amountMax: event.amountMax,
            keyword: event.keyword,
            transactionTypes: event.transactionTypes,
          ),
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
            scrollToDate: event.scrollToDate,
            dateFrom: event.dateFrom,
            dateTo: event.dateTo,
          )),
        );
        return;
      }

      // statisticsRepository 미주입 (테스트 케이스 등) 에만 fallback — server total 없음.
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
          dateFrom: event.dateFrom,
          dateTo: event.dateTo,
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
        serverTotalIncome: currentState.serverTotalIncome,
        serverTotalExpense: currentState.serverTotalExpense,
        dateFrom: currentState.dateFrom,
        dateTo: currentState.dateTo,
      ));

      final result = await transactionRepository.getTransactions(
        year: _currentYear,
        month: _currentMonth,
        keyword: _currentKeyword,
        categoryId: _currentCategoryId,
        categoryIds: _currentCategoryIds,
        categoryGroupIds: _currentCategoryGroupIds,
        paymentMethodId: _currentPaymentMethodId,
        paymentMethodIds: _currentPaymentMethodIds,
        pocketId: _currentPocketId,
        pocketIds: _currentPocketIds,
        amountMin: _currentAmountMin,
        amountMax: _currentAmountMax,
        dateFrom: _currentDateFrom,
        dateTo: _currentDateTo,
        type: _currentType,
        transactionTypes: _currentTransactionTypes,
        visibility: _currentVisibility,
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
            dateFrom: currentState.dateFrom,
            dateTo: currentState.dateTo,
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
            serverTotalIncome: currentState.serverTotalIncome,
            serverTotalExpense: currentState.serverTotalExpense,
            dateFrom: currentState.dateFrom,
            dateTo: currentState.dateTo,
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
        dateFrom: currentState.dateFrom,
        dateTo: currentState.dateTo,
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
              categoryIds: _currentCategoryIds,
              categoryGroupIds: _currentCategoryGroupIds,
              paymentMethodId: _currentPaymentMethodId,
              paymentMethodIds: _currentPaymentMethodIds,
              pocketId: _currentPocketId,
              pocketIds: _currentPocketIds,
              amountMin: _currentAmountMin,
              amountMax: _currentAmountMax,
              scrollToDate: event.transactionDate,
              dateFrom: _currentDateFrom,
              dateTo: _currentDateTo,
              type: _currentType,
              transactionTypes: _currentTransactionTypes,
              visibility: _currentVisibility,
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
              categoryIds: _currentCategoryIds,
              categoryGroupIds: _currentCategoryGroupIds,
              paymentMethodId: _currentPaymentMethodId,
              paymentMethodIds: _currentPaymentMethodIds,
              pocketId: _currentPocketId,
              pocketIds: _currentPocketIds,
              amountMin: _currentAmountMin,
              amountMax: _currentAmountMax,
              scrollToDate: event.transactionDate,
              dateFrom: _currentDateFrom,
              dateTo: _currentDateTo,
              type: _currentType,
              transactionTypes: _currentTransactionTypes,
              visibility: _currentVisibility,
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
