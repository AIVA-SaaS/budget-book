import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transaction/data/models/transaction_model.dart';
import 'package:budget_book/features/transfer/data/datasources/transfer_remote_datasource.dart';
import 'package:budget_book/features/transfer/data/repositories/transfer_repository_impl.dart';

class _MockDataSource extends Mock implements TransferRemoteDataSource {}

/// 이체 → 거래 역변환 (2026-08-09) — 전달 체인 고정.
///
/// `type_change_test.dart` (거래 → 이체) 의 거울상이다. repository→datasource hop 에서
/// 파라미터가 조용히 누락된 사고가 반복됐던 자리라, **실제 요청 map** 을 검증한다.
/// 특히 "생략하면 서버가 원본 이체를 승계한다" 는 계약이므로, 생략한 필드가 body 에
/// null 로라도 실리면 안 된다 (실리면 승계가 아니라 덮어쓰기가 된다).
void main() {
  late _MockDataSource ds;
  late TransferRepositoryImpl repo;

  final txJson = <String, dynamic>{
    'id': 't1',
    'coupleId': 'c1',
    'author': {'id': 'u1', 'nickname': '홍길동'},
    'type': 'EXPENSE',
    'amount': 50000,
    'description': '계좌 이동',
    'transactionDate': '2026-07-15',
    'createdAt': '2026-07-15T10:00:00Z',
    'updatedAt': '2026-07-15T10:00:00Z',
  };

  setUp(() {
    ds = _MockDataSource();
    repo = TransferRepositoryImpl(remoteDataSource: ds);
  });

  group('convertToTransaction', () {
    test('type 만 필수로 실리고, 생략한 값은 body 에서 빠진다 (서버가 원본 승계)', () async {
      when(() => ds.convertToTransaction(any(), any()))
          .thenAnswer((_) async => TransactionModel.fromJson(txJson));

      final result = await repo.convertToTransaction(id: 'tr1', type: 'EXPENSE');

      expect(result.isRight(), isTrue);
      final data = verify(() => ds.convertToTransaction('tr1', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(data['type'], 'EXPENSE');
      expect(data.containsKey('amount'), isFalse);
      expect(data.containsKey('transactionDate'), isFalse);
      expect(data.containsKey('description'), isFalse);
      expect(data.containsKey('paymentMethodId'), isFalse);
    });

    test('카테고리·결제수단·포켓·금액·날짜·설명·메모·needsReview 를 주면 전부 전달된다',
        () async {
      when(() => ds.convertToTransaction(any(), any()))
          .thenAnswer((_) async => TransactionModel.fromJson(txJson));

      await repo.convertToTransaction(
        id: 'tr1',
        type: 'INCOME',
        categoryId: 'c9',
        paymentMethodId: 'p2',
        pocketId: 'pk1',
        amount: 50000,
        transactionDate: '2026-07-16',
        description: '계좌 이동',
        memo: '메모',
        needsReview: true,
      );

      final data = verify(() => ds.convertToTransaction('tr1', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(data['type'], 'INCOME');
      expect(data['categoryId'], 'c9');
      expect(data['paymentMethodId'], 'p2');
      expect(data['pocketId'], 'pk1');
      expect(data['amount'], 50000);
      expect(data['transactionDate'], '2026-07-16');
      expect(data['description'], '계좌 이동');
      expect(data['memo'], '메모');
      expect(data['needsReview'], true);
    });

    test('실패는 Failure 로 매핑된다', () async {
      when(() => ds.convertToTransaction(any(), any()))
          .thenThrow(Exception('boom'));

      final result = await repo.convertToTransaction(id: 'tr1', type: 'EXPENSE');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('실패해야 한다'),
      );
    });
  });
}
