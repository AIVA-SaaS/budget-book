import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/reconciliation/reconciliation_scope.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// "정산 대상" FE 판정 — 서버 `ReconciliationScope` 와 같은 규칙을 고정한다.
/// 잔액 수정을 빼지 않으면 그 날/그 달은 영원히 정산 완료가 되지 않는다.
void main() {
  const author = TransactionAuthor(id: 'u1', nickname: '홍길동');

  Transaction txn({
    required String id,
    String type = 'EXPENSE',
    bool reconciled = false,
  }) =>
      Transaction(
        id: id,
        coupleId: 'c1',
        author: author,
        type: type,
        amount: 10000,
        description: '거래',
        transactionDate: '2026-07-15',
        visibility: 'SHARED',
        reconciliationId: reconciled ? 'r1' : null,
        reconciliationSeq: reconciled ? 1 : null,
        createdAt: DateTime.utc(2026, 7, 15),
        updatedAt: DateTime.utc(2026, 7, 15),
      );

  Transfer transfer({required String id, bool reconciled = false}) => Transfer(
        id: id,
        coupleId: 'c1',
        author: author,
        sourcePaymentMethod:
            const PaymentMethodRef(id: 'p1', name: '은행', type: 'BANK'),
        destinationPaymentMethod:
            const PaymentMethodRef(id: 'p2', name: '현금', type: 'CASH'),
        amount: 50000,
        transferDate: '2026-07-15',
        kind: TransferKind.generic,
        reconciliationId: reconciled ? 'r1' : null,
        reconciliationSeq: reconciled ? 1 : null,
        createdAt: DateTime.utc(2026, 7, 15),
      );

  test('잔액 수정은 정산 대상이 아니다', () {
    expect(
        ReconciliationScope.isReconcilableTransaction(txn(id: 't1')), isTrue);
    expect(
      ReconciliationScope.isReconcilableTransaction(
          txn(id: 't2', type: 'ADJUSTMENT')),
      isFalse,
    );
  });

  test('잔액 수정이 섞인 날도 나머지가 정산되면 완료로 판정한다', () {
    final result = ReconciliationScope.allReconciled(
      transactions: [
        txn(id: 't1', reconciled: true),
        txn(id: 't2', type: 'ADJUSTMENT'), // 미정산이지만 대상 아님
      ],
      transfers: [transfer(id: 'tr1', reconciled: true)],
    );
    expect(result, isTrue);
  });

  test('미정산 이체가 하나라도 있으면 완료가 아니다', () {
    final result = ReconciliationScope.allReconciled(
      transactions: [txn(id: 't1', reconciled: true)],
      transfers: [transfer(id: 'tr1')],
    );
    expect(result, isFalse);
  });

  test('정산 대상이 하나도 없는 날은 완료로 치지 않는다', () {
    final result = ReconciliationScope.allReconciled(
      transactions: [txn(id: 't1', type: 'ADJUSTMENT')],
      transfers: const [],
    );
    expect(result, isFalse);
  });
}
