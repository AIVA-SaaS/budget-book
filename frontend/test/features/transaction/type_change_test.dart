import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transaction/data/datasources/transaction_remote_datasource.dart';
import 'package:budget_book/features/transaction/data/models/transaction_model.dart';
import 'package:budget_book/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:budget_book/features/transfer/data/models/transfer_model.dart';

class _MockDataSource extends Mock implements TransactionRemoteDataSource {}

/// 거래 유형 변경 (2026-07-27) — 전달 체인 고정.
///
/// 과거에 필터/파라미터가 repository→datasource hop 에서 조용히 누락된 사고가 3회 있었다
/// (dateFrom/dateTo, PeriodSummary 필터, LoadCardSettlementSummary year/month).
/// 여기서는 `type` 과 변환 payload 가 **실제 요청 map 에 들어가는지**를 검증한다.
void main() {
  late _MockDataSource ds;
  late TransactionRepositoryImpl repo;

  final txJson = <String, dynamic>{
    'id': 't1',
    'coupleId': 'c1',
    'author': {'id': 'u1', 'nickname': '홍길동'},
    'type': 'INCOME',
    'amount': 15000,
    'description': '환불',
    'transactionDate': '2026-07-15',
    'createdAt': '2026-07-15T10:00:00Z',
    'updatedAt': '2026-07-15T10:00:00Z',
  };

  final transferJson = <String, dynamic>{
    'id': 'tr1',
    'coupleId': 'c1',
    'author': {'id': 'u1', 'nickname': '홍길동'},
    'sourcePaymentMethod': {'id': 'p1', 'name': '은행', 'type': 'BANK'},
    'destinationPaymentMethod': {'id': 'p2', 'name': '현금', 'type': 'CASH'},
    'amount': 50000,
    'transferDate': '2026-07-15',
    'kind': 'GENERIC',
    'createdAt': '2026-07-15T10:00:00Z',
  };

  setUp(() {
    ds = _MockDataSource();
    repo = TransactionRepositoryImpl(remoteDataSource: ds);
  });

  group('updateTransaction type', () {
    test('type 을 주면 요청 body 에 실린다', () async {
      when(() => ds.updateTransaction(any(), any()))
          .thenAnswer((_) async => TransactionModel.fromJson(txJson));

      final result = await repo.updateTransaction(id: 't1', type: 'INCOME');

      expect(result.isRight(), isTrue);
      final data = verify(() => ds.updateTransaction('t1', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(data['type'], 'INCOME');
    });

    test('type 을 안 주면 body 에 없다 (미변경)', () async {
      when(() => ds.updateTransaction(any(), any()))
          .thenAnswer((_) async => TransactionModel.fromJson(txJson));

      await repo.updateTransaction(id: 't1', amount: 20000);

      final data = verify(() => ds.updateTransaction('t1', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(data.containsKey('type'), isFalse);
      expect(data['amount'], 20000);
    });
  });

  group('convertToTransfer', () {
    test('결제수단은 필수로, 생략한 값은 body 에서 빠진다 (서버가 원본 승계)', () async {
      when(() => ds.convertToTransfer(any(), any()))
          .thenAnswer((_) async => TransferModel.fromJson(transferJson));

      final result = await repo.convertToTransfer(
        id: 't1',
        sourcePaymentMethodId: 'p1',
        destinationPaymentMethodId: 'p2',
      );

      expect(result.isRight(), isTrue);
      final data = verify(() => ds.convertToTransfer('t1', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(data['sourcePaymentMethodId'], 'p1');
      expect(data['destinationPaymentMethodId'], 'p2');
      expect(data.containsKey('amount'), isFalse);
      expect(data.containsKey('transferDate'), isFalse);
    });

    test('금액·날짜·설명·메모를 주면 전부 전달된다', () async {
      when(() => ds.convertToTransfer(any(), any()))
          .thenAnswer((_) async => TransferModel.fromJson(transferJson));

      await repo.convertToTransfer(
        id: 't1',
        sourcePaymentMethodId: 'p1',
        destinationPaymentMethodId: 'p2',
        amount: 50000,
        transferDate: '2026-07-16',
        description: '계좌 이동',
        memo: '메모',
      );

      final data = verify(() => ds.convertToTransfer('t1', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(data['amount'], 50000);
      expect(data['transferDate'], '2026-07-16');
      expect(data['description'], '계좌 이동');
      expect(data['memo'], '메모');
    });

    test('실패는 Failure 로 매핑된다', () async {
      when(() => ds.convertToTransfer(any(), any()))
          .thenThrow(Exception('boom'));

      final result = await repo.convertToTransfer(
        id: 't1',
        sourcePaymentMethodId: 'p1',
        destinationPaymentMethodId: 'p2',
      );

      expect(result.isLeft(), isTrue);
      result.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('실패해야 한다'));
    });
  });
}
