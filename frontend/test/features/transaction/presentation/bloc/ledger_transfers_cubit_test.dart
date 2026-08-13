import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
import 'package:budget_book/features/transaction/presentation/bloc/ledger_transfers_cubit.dart';
import 'package:budget_book/features/transaction/presentation/utils/ledger_totals_exclusion.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transfer/domain/repositories/transfer_repository.dart';

/// 장부 전용 이체 소스.
///
/// 회귀 배경: 이체는 `LoadTransfers(year, month)` 로 **월 단위**만 조회했고 거래·합계는
/// `dateFrom/dateTo` 를 따랐다. 그래서 기간 필터가 월을 넘으면 이체 행이 통째로 빠졌다
/// (실측: 범위 내 이체 금액의 77% 누락). 이제 필터 VO 를 서버로 그대로 보낸다.
class _FakeTransferRepository implements TransferRepository {
  final List<Map<String, dynamic>> calls = [];
  Either<Failure, List<Transfer>> result = const Right(<Transfer>[]);

  @override
  Future<Either<Failure, List<Transfer>>> getTransfers({
    required int year,
    required int month,
    bool? reconciled,
    TransactionFilter? filter,
  }) async {
    calls.add({
      'year': year,
      'month': month,
      'reconciled': reconciled,
      'filter': filter,
    });
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used in this test');
}

void main() {
  const author = TransactionAuthor(id: 'u1', nickname: '나');

  Transfer tf({String id = 'tf1', int amount = 5000}) => Transfer(
        id: id,
        coupleId: 'c1',
        author: author,
        sourcePaymentMethod:
            const PaymentMethodRef(id: 'pm-bank', name: '국민은행', type: 'BANK'),
        destinationPaymentMethod:
            const PaymentMethodRef(id: 'pm-cash', name: '현금', type: 'CASH'),
        amount: amount,
        description: '생활비 이체',
        transferDate: '2026-08-10',
        createdAt: DateTime(2026, 8, 10),
      );

  test('필터 VO 를 통째로 서버에 전달한다 (필드 나열 금지)', () async {
    final repo = _FakeTransferRepository();
    final cubit = LedgerTransfersCubit(transferRepository: repo);
    const filter = TransactionFilter(
      amountMin: 10000,
      dateFrom: '2026-06-15',
      dateTo: '2026-08-05',
      transactionTypes: {'EXPENSE', 'TRANSFER'},
    );

    await cubit.load(year: 2026, month: 8, filter: filter);

    expect(repo.calls, hasLength(1));
    // 필터가 그대로 실려야 한다 — 축을 골라 넘기면 새 축이 조용히 누락된다.
    expect(repo.calls.single['filter'], same(filter));
    expect(repo.calls.single['year'], 2026);
    expect(repo.calls.single['month'], 8);
  });

  test('로드 성공 시 이체 목록을 상태에 담는다', () async {
    final repo = _FakeTransferRepository()..result = Right([tf(), tf(id: 'tf2')]);
    final cubit = LedgerTransfersCubit(transferRepository: repo);

    await cubit.load(
      year: 2026,
      month: 8,
      filter: TransactionFilter.empty,
    );

    expect(cubit.state.transfers, hasLength(2));
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.error, isNull);
  });

  test('실패 시 에러를 담고 목록은 유지한다', () async {
    final repo = _FakeTransferRepository()..result = Right([tf()]);
    final cubit = LedgerTransfersCubit(transferRepository: repo);
    await cubit.load(year: 2026, month: 8, filter: TransactionFilter.empty);

    repo.result = const Left(ServerFailure('이체 목록을 불러오지 못했습니다'));
    await cubit.load(year: 2026, month: 8, filter: TransactionFilter.empty);

    expect(cubit.state.error, '이체 목록을 불러오지 못했습니다');
    // 목록을 비우지 않는다 — 필터 조작 중 화면이 깜빡이는 것을 막는다.
    expect(cubit.state.transfers, hasLength(1));
  });

  test('reload 는 마지막 필터·월을 그대로 다시 쓴다 (월 이동·WebSocket 동기화)', () async {
    final repo = _FakeTransferRepository();
    final cubit = LedgerTransfersCubit(transferRepository: repo);
    const filter = TransactionFilter(keyword: '커피');

    await cubit.load(year: 2026, month: 7, filter: filter);
    await cubit.reload();

    expect(repo.calls, hasLength(2));
    expect(repo.calls.last['year'], 2026);
    expect(repo.calls.last['month'], 7);
    expect(repo.calls.last['filter'], same(filter));
  });

  test('한 번도 로드하지 않았으면 reload 는 아무 것도 하지 않는다', () async {
    final repo = _FakeTransferRepository();
    final cubit = LedgerTransfersCubit(transferRepository: repo);

    await cubit.reload();

    expect(repo.calls, isEmpty);
  });

  group('합계 제외 판정', () {
    test('카드 정산 이체만 합계에서 제외된다', () {
      final settlement = Transfer(
        id: 'tf-settle',
        coupleId: 'c1',
        author: author,
        sourcePaymentMethod:
            const PaymentMethodRef(id: 'pm-bank', name: '국민은행', type: 'BANK'),
        destinationPaymentMethod:
            const PaymentMethodRef(id: 'pm-card', name: '신용카드', type: 'CREDIT'),
        amount: 120000,
        description: '카드 정산',
        transferDate: '2026-08-28',
        createdAt: DateTime(2026, 8, 28),
        kind: TransferKind.cardSettlement,
      );

      expect(isTransferExcludedFromTotals(settlement), isTrue);
      expect(isTransferExcludedFromTotals(tf()), isFalse);
    });
  });
}
