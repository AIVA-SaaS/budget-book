import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/widgets/reconciled_badge.dart';
import 'package:budget_book/features/transaction/data/models/transaction_model.dart';
import 'package:budget_book/features/transfer/data/models/transfer_model.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ReconciledBadge', () {
    testWidgets('회차를 표시하고 체크 아이콘을 그린다', (tester) async {
      await tester.pumpWidget(wrap(const ReconciledBadge(seq: 2)));

      expect(find.text('2차'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('정산 후 수정된 항목은 경고 아이콘', (tester) async {
      await tester.pumpWidget(wrap(const ReconciledBadge(seq: 1, changed: true)));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('회차가 없어도 "정산" 텍스트를 붙인다 (아이콘 글리프 의존 제거)', (tester) async {
      // 2026-07-28 — 특정 기기에서 아이콘 글리프가 안 뜨는 사례가 있어, 배지는 아이콘만으로
      // 존재를 알리지 않는다.
      await tester.pumpWidget(wrap(const ReconciledBadge()));

      expect(find.text('정산'), findsOneWidget);
    });

    testWidgets('compact 모드는 텍스트 없이 점만 (달력 셀 레이아웃 보호)', (tester) async {
      await tester.pumpWidget(wrap(const ReconciledBadge(seq: 3, compact: true)));

      expect(find.text('3차'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });

  group('정산 필드 파싱 — 거래/이체 양쪽 동일', () {
    final txJson = <String, dynamic>{
      'id': 't1',
      'coupleId': 'c1',
      'author': {'id': 'u1', 'nickname': '홍길동'},
      'type': 'EXPENSE',
      'amount': 10000,
      'description': '스타벅스',
      'transactionDate': '2026-07-15',
      'createdAt': '2026-07-15T10:00:00Z',
      'updatedAt': '2026-07-15T10:00:00Z',
    };

    final tfJson = <String, dynamic>{
      'id': 'tr1',
      'coupleId': 'c1',
      'author': {'id': 'u1', 'nickname': '홍길동'},
      'sourcePaymentMethod': {'id': 'p1', 'name': '은행', 'type': 'BANK'},
      'destinationPaymentMethod': {'id': 'p2', 'name': '현금', 'type': 'CASH'},
      'amount': 50000,
      'transferDate': '2026-07-20',
      'kind': 'GENERIC',
      'createdAt': '2026-07-20T10:00:00Z',
    };

    test('거래: 정산된 응답은 isReconciled=true + 회차/시각 파싱', () {
      final tx = TransactionModel.fromJson({
        ...txJson,
        'reconciliationId': 'r1',
        'reconciliationSeq': 2,
        'reconciledAt': '2026-07-20T14:03:00Z',
      });

      expect(tx.isReconciled, isTrue);
      expect(tx.reconciliationSeq, 2);
      expect(tx.reconciledAt, DateTime.utc(2026, 7, 20, 14, 3));
    });

    test('거래: 미기록 응답(필드 없음)은 isReconciled=false', () {
      final tx = TransactionModel.fromJson(txJson);

      expect(tx.isReconciled, isFalse);
      expect(tx.reconciliationId, isNull);
      expect(tx.reconciliationSeq, isNull);
      expect(tx.reconciledAt, isNull);
    });

    test('이체: 거래와 동일한 3필드를 파싱한다 (한쪽만 채우면 배지 drift)', () {
      final tf = TransferModel.fromJson({
        ...tfJson,
        'reconciliationId': 'r1',
        'reconciliationSeq': 2,
        'reconciledAt': '2026-07-20T14:03:00Z',
      });

      expect(tf.isReconciled, isTrue);
      expect(tf.reconciliationSeq, 2);
      expect(tf.reconciledAt, DateTime.utc(2026, 7, 20, 14, 3));
    });

    test('이체: 미기록 응답은 isReconciled=false', () {
      final tf = TransferModel.fromJson(tfJson);

      expect(tf.isReconciled, isFalse);
      expect(tf.reconciliationId, isNull);
    });
  });
}
