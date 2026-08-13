import 'package:equatable/equatable.dart';

class StatisticsSummary extends Equatable {
  final String yearMonth;
  final int totalIncome;
  final int totalExpense;

  /// 순수 내부 이체(`TransferKind.GENERIC`) 합계. 수입/지출과 disjoint.
  ///
  /// 2026-08-12 신규 — 이전에는 이 값이 응답에 있어도 FE 엔티티에 없어서 장부의
  /// "이체" 칸을 클라이언트가 따로 계산했다. 그 계산은 포커스 월의 이체만 봐서
  /// 기간 필터가 월을 넘으면 과소 표시됐다.
  final int totalTransfer;

  final int balance;
  final int transactionCount;

  /// 이 합계에 집계된 이체 건수(`CARD_SETTLEMENT` 제외). 합계와 행 대조용.
  final int transferCount;

  const StatisticsSummary({
    required this.yearMonth,
    required this.totalIncome,
    required this.totalExpense,
    this.totalTransfer = 0,
    required this.balance,
    required this.transactionCount,
    this.transferCount = 0,
  });

  @override
  List<Object?> get props => [
        yearMonth,
        totalIncome,
        totalExpense,
        totalTransfer,
        balance,
        transactionCount,
        transferCount,
      ];
}
