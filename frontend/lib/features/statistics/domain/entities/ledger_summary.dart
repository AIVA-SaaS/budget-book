import 'package:equatable/equatable.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// Aggregated ledger totals for a window of transactions and transfers.
///
/// S2 structural fix (§5 of Phase 22 plan): centralize FE-side aggregation so
/// kind/type branching logic lives in exactly one place. Call sites must NOT
/// loop over transactions/transfers inline to compute totals — they should
/// call [LedgerSummary.from] instead.
///
/// Aggregation rules (§2.4):
/// - totalIncome  = Transaction(type=INCOME)
///                + Transfer(kind=INCOME_TRANSFER)[amount]
/// - totalExpense = Transaction(type=EXPENSE)
///                + Transfer(kind=EXPENSE_TRANSFER)[amount]
/// - totalTransfer = Transfer(kind=GENERIC)[amount]
/// - Transfer(kind=CARD_SETTLEMENT): excluded from every bucket (the original
///   EXPENSE is already counted)
/// - Transaction(type=ADJUSTMENT): excluded from totalIncome/totalExpense,
///   but contributes signed amount to [balance] (§2.5).
/// - balance = totalIncome - totalExpense + adjustments
class LedgerSummary extends Equatable {
  final int totalIncome;
  final int totalExpense;
  final int totalTransfer;
  final int balance;

  const LedgerSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalTransfer,
    required this.balance,
  });

  static const LedgerSummary zero = LedgerSummary(
    totalIncome: 0,
    totalExpense: 0,
    totalTransfer: 0,
    balance: 0,
  );

  /// Build a summary from explicit transaction and transfer lists.
  ///
  /// When [pmFilter] is provided, transfer in/out is computed relative to
  /// that payment method id (source → out, destination → in). GENERIC
  /// transfers aggregate into [totalTransfer] using only the out leg (or
  /// the leg hitting the filtered method) to avoid double counting.
  ///
  /// When [pmFilter] is null, GENERIC transfers aggregate their raw amount
  /// once (not doubled), matching the global month view.
  factory LedgerSummary.from({
    required List<Transaction> txs,
    required List<Transfer> tfs,
    String? pmFilter,
  }) {
    int income = 0;
    int expense = 0;
    int adjustmentSum = 0;
    int transferTotal = 0;

    for (final t in txs) {
      if (t.isIncome) {
        income += t.amount;
      } else if (t.isExpense) {
        expense += t.amount;
      } else if (t.isAdjustment) {
        // amount is signed (positive=balance increase, negative=decrease);
        // excluded from income/expense but contributes to balance.
        adjustmentSum += t.amount;
      }
    }

    for (final tf in tfs) {
      switch (tf.kind) {
        case TransferKind.cardSettlement:
          // Skip — original EXPENSE transaction already accounted for.
          continue;
        case TransferKind.expenseTransfer:
          if (pmFilter == null) {
            expense += tf.amount;
          } else if (tf.sourcePaymentMethod.id == pmFilter) {
            expense += tf.amount;
          }
          break;
        case TransferKind.incomeTransfer:
          if (pmFilter == null) {
            income += tf.amount;
          } else if (tf.destinationPaymentMethod.id == pmFilter) {
            income += tf.amount;
          }
          break;
        case TransferKind.generic:
          if (pmFilter == null) {
            transferTotal += tf.amount;
          } else {
            // When viewing a single payment method, every internal move
            // that touches that method flows through exactly once on its
            // out or in side. Count the leg relative to the filter.
            if (tf.sourcePaymentMethod.id == pmFilter ||
                tf.destinationPaymentMethod.id == pmFilter) {
              transferTotal += tf.amount;
            }
          }
          break;
      }
    }

    return LedgerSummary(
      totalIncome: income,
      totalExpense: expense,
      totalTransfer: transferTotal,
      balance: income - expense + adjustmentSum,
    );
  }

  @override
  List<Object?> get props =>
      [totalIncome, totalExpense, totalTransfer, balance];
}
