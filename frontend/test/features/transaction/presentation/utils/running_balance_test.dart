import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transaction/domain/entities/ledger_item.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transaction/presentation/utils/running_balance.dart';

// Test helpers --------------------------------------------------------------

TransactionAuthor _author() => const TransactionAuthor(id: 'u1', nickname: 't');

Transaction _tx({
  required String type,
  required int amount,
  required String id,
  String date = '2026-04-10',
}) {
  return Transaction(
    id: id,
    coupleId: 'c1',
    author: _author(),
    type: type,
    amount: amount,
    description: 'desc',
    transactionDate: date,
    createdAt: DateTime.parse('2026-04-10T00:00:00Z'),
    updatedAt: DateTime.parse('2026-04-10T00:00:00Z'),
  );
}

Transfer _tf({
  required int amount,
  required String id,
  String sourceId = 'pmSrc',
  String destId = 'pmDst',
  String date = '2026-04-10',
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
    createdAt: DateTime.parse('2026-04-10T00:00:00Z'),
  );
}

void main() {
  group('MODE A — computeExpenseCumulative (cumulative expense, negative)', () {
    test('newest expense shows -totalExpense, older rows show less', () {
      // Display order is NEWEST-FIRST.
      final e1 = LedgerItem.fromTransaction(
          _tx(type: 'EXPENSE', amount: 3000, id: 'e1')); // newest
      final e2 = LedgerItem.fromTransaction(
          _tx(type: 'EXPENSE', amount: 2000, id: 'e2'));
      final e3 = LedgerItem.fromTransaction(
          _tx(type: 'EXPENSE', amount: 1000, id: 'e3')); // oldest

      // Anchor = total expense = 3000+2000+1000 = 6000.
      final map = computeExpenseCumulative([e1, e2, e3], 6000);

      expect(map['tx:e1'], -6000, reason: 'newest = -totalExpense');
      expect(map['tx:e2'], -3000, reason: '6000 - 3000');
      expect(map['tx:e3'], -1000, reason: 'only its own expense remains');
    });

    test('income and adjustment do NOT change the running value', () {
      final inc = LedgerItem.fromTransaction(
          _tx(type: 'INCOME', amount: 9999, id: 'i1')); // newest
      final exp = LedgerItem.fromTransaction(
          _tx(type: 'EXPENSE', amount: 4000, id: 'e1'));
      final adj = LedgerItem.fromTransaction(
          _tx(type: 'ADJUSTMENT', amount: 500, id: 'a1')); // oldest

      final map = computeExpenseCumulative([inc, exp, adj], 4000);

      // Only the single expense contributes to the anchor.
      expect(map['tx:i1'], -4000, reason: 'income carries cumulative, unchanged');
      expect(map['tx:e1'], -4000);
      expect(map['tx:a1'], 0, reason: 'after the expense is consumed, 0 remains');
    });

    test('transfers get NO running total in MODE A', () {
      final exp = LedgerItem.fromTransaction(
          _tx(type: 'EXPENSE', amount: 1000, id: 'e1'));
      final tf = LedgerItem.fromTransfer(_tf(amount: 5000, id: 'tf1'));

      final map = computeExpenseCumulative([exp, tf], 1000);

      expect(map.containsKey('tf:tf1'), isFalse);
      expect(map['tx:e1'], -1000);
    });
  });

  group('MODE B — computeAssetBalance (asset balance, backward-accumulated)', () {
    const pmId = 'pmMine';

    test('income/expense/adjustment net effect, newest shows end anchor', () {
      // Newest-first display order. End-of-month anchor balance = 10000.
      final inc = LedgerItem.fromTransaction(
          _tx(type: 'INCOME', amount: 2000, id: 'i1')); // newest
      final exp = LedgerItem.fromTransaction(
          _tx(type: 'EXPENSE', amount: 3000, id: 'e1'));
      final adj = LedgerItem.fromTransaction(
          _tx(type: 'ADJUSTMENT', amount: 500, id: 'a1')); // oldest

      final map = computeAssetBalance([inc, exp, adj], 10000, pmId);

      expect(map['tx:i1'], 10000, reason: 'balance right after newest row');
      // running -= (+2000) → 8000 shown on next row
      expect(map['tx:e1'], 8000);
      // running -= (-3000) → 11000 shown on next row
      expect(map['tx:a1'], 11000);
      // sanity: balance BEFORE the oldest row would be 11000 - 500 = 10500.
    });

    test('transfer in (destination == pm) adds, transfer out subtracts', () {
      final tin = LedgerItem.fromTransfer(
          _tf(amount: 1000, id: 'in1', destId: pmId, sourceId: 'other'));
      final tout = LedgerItem.fromTransfer(
          _tf(amount: 400, id: 'out1', sourceId: pmId, destId: 'other'));
      final unrelated = LedgerItem.fromTransfer(
          _tf(amount: 999, id: 'x1', sourceId: 'o1', destId: 'o2'));

      // Order newest-first: [tin, tout, unrelated]; anchor = 5000.
      final map = computeAssetBalance([tin, tout, unrelated], 5000, pmId);

      expect(map['tf:in1'], 5000);
      // running -= (+1000 in) → 4000
      expect(map['tf:out1'], 4000);
      // running -= (-400 out) → 4400
      expect(map['tf:x1'], 4400);
      // unrelated netEffect 0 → running stays 4400 for anything older.
    });

    test('both transactions and transfers receive a running balance', () {
      final tf = LedgerItem.fromTransfer(
          _tf(amount: 1000, id: 'in1', destId: pmId, sourceId: 'other'));
      final exp = LedgerItem.fromTransaction(
          _tx(type: 'EXPENSE', amount: 2000, id: 'e1'));

      final map = computeAssetBalance([tf, exp], 7000, pmId);

      expect(map['tf:in1'], 7000);
      expect(map['tx:e1'], 6000, reason: '7000 - (+1000 transfer in)');
    });
  });

  group('netEffectOnAsset', () {
    const pmId = 'pm1';
    test('adjustment uses signed amount', () {
      final neg = LedgerItem.fromTransaction(
          _tx(type: 'ADJUSTMENT', amount: -300, id: 'a1'));
      expect(netEffectOnAsset(neg, pmId), -300);
    });
  });
}
