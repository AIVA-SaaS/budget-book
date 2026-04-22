import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/statistics/domain/entities/ledger_summary.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

// Test helpers --------------------------------------------------------------

TransactionAuthor _author() => const TransactionAuthor(
      id: 'u1',
      nickname: 'tester',
    );

Transaction _tx({
  required String type,
  required int amount,
  String id = 't',
  String date = '2026-04-01',
}) {
  return Transaction(
    id: id,
    coupleId: 'c1',
    author: _author(),
    type: type,
    amount: amount,
    description: 'desc',
    transactionDate: date,
    createdAt: DateTime.parse('2026-04-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-04-01T00:00:00Z'),
  );
}

Transfer _tf({
  required TransferKind kind,
  required int amount,
  String sourceId = 'pmA',
  String destId = 'pmB',
  String id = 'tf',
  String date = '2026-04-02',
}) {
  return Transfer(
    id: id,
    coupleId: 'c1',
    author: _author(),
    sourcePaymentMethod:
        PaymentMethodRef(id: sourceId, name: 'src', type: 'BANK'),
    destinationPaymentMethod:
        PaymentMethodRef(id: destId, name: 'dst', type: 'BANK'),
    amount: amount,
    transferDate: date,
    createdAt: DateTime.parse('2026-04-02T00:00:00Z'),
    kind: kind,
  );
}

void main() {
  group('LedgerSummary.from — Phase 22 §2.4 aggregation', () {
    test('transactions only: income/expense segregated', () {
      final summary = LedgerSummary.from(
        txs: [
          _tx(type: 'INCOME', amount: 100000, id: 'i1'),
          _tx(type: 'INCOME', amount: 50000, id: 'i2'),
          _tx(type: 'EXPENSE', amount: 30000, id: 'e1'),
        ],
        tfs: const [],
      );
      expect(summary.totalIncome, 150000);
      expect(summary.totalExpense, 30000);
      expect(summary.totalTransfer, 0);
      expect(summary.balance, 120000);
    });

    test('CARD_SETTLEMENT is excluded from every bucket (no double-count)',
        () {
      final summary = LedgerSummary.from(
        txs: [_tx(type: 'EXPENSE', amount: 50000)],
        tfs: [_tf(kind: TransferKind.cardSettlement, amount: 50000)],
      );
      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 50000, reason: 'original EXPENSE counts once');
      expect(summary.totalTransfer, 0);
      expect(summary.balance, -50000);
    });

    test('EXPENSE_TRANSFER adds to expense but not income (no pmFilter)', () {
      final summary = LedgerSummary.from(
        txs: [_tx(type: 'EXPENSE', amount: 10000)],
        tfs: [_tf(kind: TransferKind.expenseTransfer, amount: 25000)],
      );
      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 35000);
      expect(summary.totalTransfer, 0);
      expect(summary.balance, -35000);
    });

    test('INCOME_TRANSFER adds to income but not expense (no pmFilter)', () {
      final summary = LedgerSummary.from(
        txs: const [],
        tfs: [_tf(kind: TransferKind.incomeTransfer, amount: 40000)],
      );
      expect(summary.totalIncome, 40000);
      expect(summary.totalExpense, 0);
      expect(summary.totalTransfer, 0);
      expect(summary.balance, 40000);
    });

    test('GENERIC aggregates into totalTransfer (no pmFilter)', () {
      final summary = LedgerSummary.from(
        txs: const [],
        tfs: [
          _tf(kind: TransferKind.generic, amount: 30000),
          _tf(kind: TransferKind.generic, amount: 20000),
        ],
      );
      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 0);
      expect(summary.totalTransfer, 50000);
      expect(summary.balance, 0);
    });

    test('ADJUSTMENT is excluded from income/expense but affects balance', () {
      final summary = LedgerSummary.from(
        txs: [
          _tx(type: 'INCOME', amount: 100000, id: 'i1'),
          _tx(type: 'EXPENSE', amount: 40000, id: 'e1'),
          _tx(type: 'ADJUSTMENT', amount: 5000, id: 'a1'), // +5,000
          _tx(type: 'ADJUSTMENT', amount: -2000, id: 'a2'), // -2,000
        ],
        tfs: const [],
      );
      expect(summary.totalIncome, 100000,
          reason: 'ADJUSTMENT must not inflate income');
      expect(summary.totalExpense, 40000,
          reason: 'ADJUSTMENT must not inflate expense');
      // balance = 100k - 40k + (5k - 2k) = 63k
      expect(summary.balance, 63000);
    });

    test('pmFilter: EXPENSE_TRANSFER only counts when its source matches', () {
      final summary = LedgerSummary.from(
        txs: const [],
        tfs: [
          _tf(
            kind: TransferKind.expenseTransfer,
            amount: 10000,
            sourceId: 'pmA',
            destId: 'pmB',
          ),
          _tf(
            kind: TransferKind.expenseTransfer,
            amount: 77777,
            sourceId: 'pmX',
            destId: 'pmB',
          ),
        ],
        pmFilter: 'pmA',
      );
      expect(summary.totalExpense, 10000);
    });

    test('pmFilter: INCOME_TRANSFER only counts when its destination matches',
        () {
      final summary = LedgerSummary.from(
        txs: const [],
        tfs: [
          _tf(
            kind: TransferKind.incomeTransfer,
            amount: 20000,
            sourceId: 'pmX',
            destId: 'pmFiltered',
          ),
          _tf(
            kind: TransferKind.incomeTransfer,
            amount: 99999,
            sourceId: 'pmA',
            destId: 'pmB',
          ),
        ],
        pmFilter: 'pmFiltered',
      );
      expect(summary.totalIncome, 20000);
    });

    test('pmFilter: GENERIC counts once when either leg hits the filter', () {
      final summary = LedgerSummary.from(
        txs: const [],
        tfs: [
          _tf(
            kind: TransferKind.generic,
            amount: 5000,
            sourceId: 'pmA',
            destId: 'pmB',
          ),
          _tf(
            kind: TransferKind.generic,
            amount: 3000,
            sourceId: 'pmZ',
            destId: 'pmA',
          ),
          _tf(
            kind: TransferKind.generic,
            amount: 9999,
            sourceId: 'pmX',
            destId: 'pmY',
          ),
        ],
        pmFilter: 'pmA',
      );
      // both A-touching transfers should count (one via source, one via dest)
      expect(summary.totalTransfer, 8000);
    });

    test('mixed kinds + transactions + ADJUSTMENT — integration', () {
      final summary = LedgerSummary.from(
        txs: [
          _tx(type: 'INCOME', amount: 100000, id: 'i1'),
          _tx(type: 'EXPENSE', amount: 30000, id: 'e1'),
          _tx(type: 'EXPENSE', amount: 20000, id: 'e2'),
          _tx(type: 'ADJUSTMENT', amount: -1000, id: 'a1'),
        ],
        tfs: [
          _tf(kind: TransferKind.cardSettlement, amount: 50000, id: 'tf-cs'),
          _tf(kind: TransferKind.expenseTransfer, amount: 15000, id: 'tf-et'),
          _tf(kind: TransferKind.incomeTransfer, amount: 25000, id: 'tf-it'),
          _tf(kind: TransferKind.generic, amount: 40000, id: 'tf-g'),
        ],
      );
      // income = 100k (tx) + 25k (IT) = 125k
      expect(summary.totalIncome, 125000);
      // expense = 30k + 20k + 15k (ET) = 65k; CARD_SETTLEMENT excluded
      expect(summary.totalExpense, 65000);
      // transfer = 40k (GENERIC only)
      expect(summary.totalTransfer, 40000);
      // balance = 125k - 65k + (-1k) = 59k
      expect(summary.balance, 59000);
    });
  });

  group('TransferKind.fromWire', () {
    test('parses all defined wire values', () {
      expect(TransferKind.fromWire('CARD_SETTLEMENT'),
          TransferKind.cardSettlement);
      expect(TransferKind.fromWire('EXPENSE_TRANSFER'),
          TransferKind.expenseTransfer);
      expect(TransferKind.fromWire('INCOME_TRANSFER'),
          TransferKind.incomeTransfer);
      expect(TransferKind.fromWire('GENERIC'), TransferKind.generic);
    });

    test('unknown or null falls back to GENERIC', () {
      expect(TransferKind.fromWire(null), TransferKind.generic);
      expect(TransferKind.fromWire('FUTURE_KIND'), TransferKind.generic);
      expect(TransferKind.fromWire(''), TransferKind.generic);
    });
  });
}
