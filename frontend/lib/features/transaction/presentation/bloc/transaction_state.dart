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
  final int currentPage;
  final bool isLoadingMore;
  final String? operationError;
  final String? operationSuccess;
  final int? serverTotalIncome;
  final int? serverTotalExpense;

  /// 서버가 계산한 이체(GENERIC) 합계. 2026-08-12 — 이전에는 이 값이 없어서 장부의
  /// "이체" 칸을 클라이언트가 포커스 월의 이체로만 계산했다(기간 필터에서 과소 표시).
  final int? serverTotalTransfer;

  /// 서버 합계에 포함된 이체 건수. 합계 ↔ 행 대조용 관측 값.
  final int? serverTransferCount;

  final String? scrollToDate;
  final String? dateFrom;
  final String? dateTo;

  const TransactionLoaded({
    required this.transactions,
    required this.year,
    required this.month,
    required this.totalElements,
    required this.hasMore,
    this.currentPage = 0,
    this.isLoadingMore = false,
    this.operationError,
    this.operationSuccess,
    this.scrollToDate,
    this.serverTotalIncome,
    this.serverTotalExpense,
    this.serverTotalTransfer,
    this.serverTransferCount,
    this.dateFrom,
    this.dateTo,
  });

  int get totalIncome => serverTotalIncome ?? transactions
      .where((t) => t.isIncome)
      .fold(0, (sum, t) => sum + t.amount);

  int get totalExpense => serverTotalExpense ?? transactions
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

  /// Returns transactions as-is (server already filters by dateFrom/dateTo).
  List<Transaction> get filteredTransactions => transactions;

  /// Alias for groupedByDate (server already filters by dateFrom/dateTo).
  Map<String, List<Transaction>> get filteredGroupedByDate => groupedByDate;

  @override
  List<Object?> get props =>
      [transactions, year, month, totalElements, hasMore, currentPage, isLoadingMore, operationError, operationSuccess, scrollToDate, serverTotalIncome, serverTotalExpense, serverTotalTransfer, serverTransferCount, dateFrom, dateTo];
}

class TransactionError extends TransactionState {
  final String message;

  const TransactionError(this.message);

  @override
  List<Object?> get props => [message];
}
