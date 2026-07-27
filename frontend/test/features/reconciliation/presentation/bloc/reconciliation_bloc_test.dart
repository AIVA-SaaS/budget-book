import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';
import 'package:budget_book/features/reconciliation/domain/repositories/reconciliation_repository.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_bloc.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_event.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_state.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transfer/domain/repositories/transfer_repository.dart';

class _MockRepo extends Mock implements ReconciliationRepository {}

class _MockTxnRepo extends Mock implements TransactionRepository {}

class _MockTransferRepo extends Mock implements TransferRepository {}

void main() {
  late _MockRepo repo;
  late _MockTxnRepo txnRepo;
  late _MockTransferRepo transferRepo;

  const author = TransactionAuthor(id: 'u1', nickname: '홍길동');

  final snapshot = Reconciliation(
    id: 'r1',
    yearMonth: '2026-07',
    seq: 1,
    label: '1차',
    itemCount: 3,
    totalIncome: 0,
    totalExpense: 30000,
    totalTransfer: 0,
    reconciledAt: DateTime.utc(2026, 7, 20, 14, 3),
    reconciledBy: author,
  );

  const summary = ReconciliationSummary(
    yearMonth: '2026-07',
    snapshotCount: 1,
    recordedCount: 3,
    unrecordedCount: 12,
    unrecordedIncome: 0,
    unrecordedExpense: 340000,
    unrecordedTransfer: 50000,
    needsReviewCount: 2,
  );

  final detail = ReconciliationDetail(
    header: snapshot,
    items: const [
      ReconciliationItem(
        itemId: 'i1',
        itemKind: 'TRANSACTION',
        refId: 't1',
        snapshotAmount: 10000,
        snapshotDate: '2026-07-15',
        snapshotKind: 'EXPENSE',
        currentAmount: 10000,
        currentDate: '2026-07-15',
      ),
    ],
  );

  setUpAll(() {
    registerFallbackValue(TransactionFilter.empty);
  });

  setUp(() {
    repo = _MockRepo();
    txnRepo = _MockTxnRepo();
    transferRepo = _MockTransferRepo();
    // 미기록 목록은 서버 필터로 받는다 — 기본 stub 은 빈 페이지.
    when(() => txnRepo.getTransactions(
          year: any(named: 'year'),
          month: any(named: 'month'),
          filter: any(named: 'filter'),
          page: any(named: 'page'),
          size: any(named: 'size'),
        )).thenAnswer((_) async => const Right(PageResponse<Transaction>(
          content: [],
          page: 0,
          size: 200,
          totalElements: 0,
          totalPages: 0,
          first: true,
          last: true,
        )));
    when(() => transferRepo.getTransfers(
          year: any(named: 'year'),
          month: any(named: 'month'),
          reconciled: any(named: 'reconciled'),
        )).thenAnswer((_) async => const Right(<Transfer>[]));
    when(() => repo.getReconciliations(year: any(named: 'year'), month: any(named: 'month')))
        .thenAnswer((_) async => Right([snapshot]));
    when(() => repo.getSummary(year: any(named: 'year'), month: any(named: 'month')))
        .thenAnswer((_) async => const Right(summary));
  });

  group('LoadReconciliations', () {
    blocTest<ReconciliationBloc, ReconciliationState>(
      '스냅샷 목록과 요약을 한 상태로 함께 내려준다 (원자적 로딩)',
      build: () => ReconciliationBloc(
          repository: repo,
          transactionRepository: txnRepo,
          transferRepository: transferRepo,
        ),
      act: (bloc) => bloc.add(const LoadReconciliations(year: 2026, month: 7)),
      expect: () => [
        const ReconciliationLoading(),
        isA<ReconciliationLoaded>()
            .having((s) => s.snapshots.length, 'snapshots', 1)
            .having((s) => s.summary.unrecordedCount, 'unrecorded', 12)
            .having((s) => s.year, 'year', 2026)
            .having((s) => s.month, 'month', 7),
      ],
      verify: (_) {
        // 목록과 요약은 같은 달로 함께 조회돼야 한다.
        verify(() => repo.getReconciliations(year: 2026, month: 7)).called(1);
        verify(() => repo.getSummary(year: 2026, month: 7)).called(1);
      },
    );

    blocTest<ReconciliationBloc, ReconciliationState>(
      '목록 조회 실패 시 에러 상태',
      build: () {
        when(() => repo.getReconciliations(
                year: any(named: 'year'), month: any(named: 'month')))
            .thenAnswer((_) async => const Left(ServerFailure('실패했습니다')));
        return ReconciliationBloc(
          repository: repo,
          transactionRepository: txnRepo,
          transferRepository: transferRepo,
        );
      },
      act: (bloc) => bloc.add(const LoadReconciliations(year: 2026, month: 7)),
      expect: () => [
        const ReconciliationLoading(),
        isA<ReconciliationError>().having((s) => s.message, 'message', '실패했습니다'),
      ],
    );

    blocTest<ReconciliationBloc, ReconciliationState>(
      '달을 바꾸면 이전 달의 항목 캐시를 버린다',
      build: () {
        when(() => repo.getReconciliation('r1'))
            .thenAnswer((_) async => Right(detail));
        return ReconciliationBloc(
          repository: repo,
          transactionRepository: txnRepo,
          transferRepository: transferRepo,
        );
      },
      act: (bloc) async {
        bloc.add(const LoadReconciliations(year: 2026, month: 7));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const LoadReconciliationDetail('r1'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const LoadReconciliations(year: 2026, month: 8));
      },
      skip: 3,
      expect: () => [
        isA<ReconciliationLoaded>()
            .having((s) => s.month, 'month', 8)
            .having((s) => s.itemsBySnapshot, 'items cache cleared', isEmpty),
      ],
    );
  });

  group('미기록 목록은 서버 필터로 받는다', () {
    blocTest<ReconciliationBloc, ReconciliationState>(
      'reconciled=false 필터로 거래/이체를 각각 조회한다',
      build: () => ReconciliationBloc(
        repository: repo,
        transactionRepository: txnRepo,
        transferRepository: transferRepo,
      ),
      act: (bloc) => bloc.add(const LoadReconciliations(year: 2026, month: 7)),
      verify: (_) {
        // 클라이언트에서 걸러내면 200건 넘는 달의 미로드 페이지가 누락된다 →
        // 서버 필터를 쓰는지 고정한다.
        final captured = verify(() => txnRepo.getTransactions(
              year: 2026,
              month: 7,
              filter: captureAny(named: 'filter'),
              size: any(named: 'size'),
            )).captured;
        expect((captured.single as TransactionFilter).reconciled, isFalse);
        verify(() => transferRepo.getTransfers(
              year: 2026,
              month: 7,
              reconciled: false,
            )).called(1);
      },
    );

    blocTest<ReconciliationBloc, ReconciliationState>(
      '거래가 더 남아 있으면 hasMoreUnrecorded=true',
      build: () {
        when(() => txnRepo.getTransactions(
              year: any(named: 'year'),
              month: any(named: 'month'),
              filter: any(named: 'filter'),
              page: any(named: 'page'),
              size: any(named: 'size'),
            )).thenAnswer((_) async => const Right(PageResponse<Transaction>(
              content: [],
              page: 0,
              size: 200,
              totalElements: 500,
              totalPages: 3,
              first: true,
              last: false,
            )));
        return ReconciliationBloc(
          repository: repo,
          transactionRepository: txnRepo,
          transferRepository: transferRepo,
        );
      },
      act: (bloc) => bloc.add(const LoadReconciliations(year: 2026, month: 7)),
      expect: () => [
        const ReconciliationLoading(),
        isA<ReconciliationLoaded>()
            .having((s) => s.hasMoreUnrecorded, 'hasMore', true),
      ],
    );

    blocTest<ReconciliationBloc, ReconciliationState>(
      '이체 조회 실패도 에러로 표면화한다 (거래만 성공해도 통과 금지)',
      build: () {
        when(() => transferRepo.getTransfers(
              year: any(named: 'year'),
              month: any(named: 'month'),
              reconciled: any(named: 'reconciled'),
            )).thenAnswer((_) async => const Left(ServerFailure('이체 실패')));
        return ReconciliationBloc(
          repository: repo,
          transactionRepository: txnRepo,
          transferRepository: transferRepo,
        );
      },
      act: (bloc) => bloc.add(const LoadReconciliations(year: 2026, month: 7)),
      expect: () => [
        const ReconciliationLoading(),
        isA<ReconciliationError>().having((s) => s.message, 'message', '이체 실패'),
      ],
    );
  });

  group('CreateReconciliation', () {
    blocTest<ReconciliationBloc, ReconciliationState>(
      '성공하면 성공 메시지 + 목록/요약 재조회',
      build: () {
        when(() => repo.createReconciliation(
              yearMonth: any(named: 'yearMonth'),
              label: any(named: 'label'),
              transactionIds: any(named: 'transactionIds'),
              transferIds: any(named: 'transferIds'),
            )).thenAnswer((_) async => Right(detail));
        return ReconciliationBloc(
          repository: repo,
          transactionRepository: txnRepo,
          transferRepository: transferRepo,
        );
      },
      act: (bloc) async {
        bloc.add(const LoadReconciliations(year: 2026, month: 7));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const CreateReconciliation(
          yearMonth: '2026-07',
          label: '1차',
          transactionIds: ['t1'],
        ));
      },
      skip: 2,
      expect: () => [
        // isMutating = true
        isA<ReconciliationLoaded>().having((s) => s.isMutating, 'mutating', true),
        // 성공 메시지
        isA<ReconciliationLoaded>()
            .having((s) => s.isMutating, 'mutating', false)
            .having((s) => s.operationSuccess, 'success', contains('정산이 완료')),
        // 재조회 결과
        isA<ReconciliationLoaded>().having((s) => s.snapshots.length, 'snapshots', 1),
      ],
      verify: (_) {
        // 목록 2회(초기 + 재조회), 요약도 2회 — 미기록 건수까지 함께 갱신돼야 한다.
        verify(() => repo.getReconciliations(year: 2026, month: 7)).called(2);
        verify(() => repo.getSummary(year: 2026, month: 7)).called(2);
      },
    );

    blocTest<ReconciliationBloc, ReconciliationState>(
      '409(이미 정산됨) 는 에러 메시지로 노출하고 목록은 재조회하지 않는다',
      build: () {
        when(() => repo.createReconciliation(
              yearMonth: any(named: 'yearMonth'),
              label: any(named: 'label'),
              transactionIds: any(named: 'transactionIds'),
              transferIds: any(named: 'transferIds'),
            )).thenAnswer((_) async =>
            const Left(ServerFailure('이미 정산에 기록된 거래가 포함되어 있습니다')));
        return ReconciliationBloc(
          repository: repo,
          transactionRepository: txnRepo,
          transferRepository: transferRepo,
        );
      },
      act: (bloc) async {
        bloc.add(const LoadReconciliations(year: 2026, month: 7));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const CreateReconciliation(
          yearMonth: '2026-07',
          transactionIds: ['t1'],
        ));
      },
      skip: 2,
      expect: () => [
        isA<ReconciliationLoaded>().having((s) => s.isMutating, 'mutating', true),
        isA<ReconciliationLoaded>()
            .having((s) => s.isMutating, 'mutating', false)
            .having((s) => s.operationError, 'error', contains('이미 정산')),
      ],
      verify: (_) {
        verify(() => repo.getReconciliations(year: 2026, month: 7)).called(1);
      },
    );

    blocTest<ReconciliationBloc, ReconciliationState>(
      'mutation 진행 중 중복 요청은 무시된다',
      build: () {
        when(() => repo.createReconciliation(
              yearMonth: any(named: 'yearMonth'),
              label: any(named: 'label'),
              transactionIds: any(named: 'transactionIds'),
              transferIds: any(named: 'transferIds'),
            )).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return Right(detail);
        });
        return ReconciliationBloc(
          repository: repo,
          transactionRepository: txnRepo,
          transferRepository: transferRepo,
        );
      },
      act: (bloc) async {
        bloc.add(const LoadReconciliations(year: 2026, month: 7));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const CreateReconciliation(
            yearMonth: '2026-07', transactionIds: ['t1']));
        bloc.add(const CreateReconciliation(
            yearMonth: '2026-07', transactionIds: ['t1']));
        await Future<void>.delayed(const Duration(milliseconds: 120));
      },
      verify: (_) {
        verify(() => repo.createReconciliation(
              yearMonth: any(named: 'yearMonth'),
              label: any(named: 'label'),
              transactionIds: any(named: 'transactionIds'),
              transferIds: any(named: 'transferIds'),
            )).called(1);
      },
    );
  });

  group('DeleteReconciliation / RemoveReconciliationItems', () {
    blocTest<ReconciliationBloc, ReconciliationState>(
      '정산 취소 성공 시 목록/요약 재조회',
      build: () {
        when(() => repo.deleteReconciliation('r1'))
            .thenAnswer((_) async => const Right(null));
        return ReconciliationBloc(
          repository: repo,
          transactionRepository: txnRepo,
          transferRepository: transferRepo,
        );
      },
      act: (bloc) async {
        bloc.add(const LoadReconciliations(year: 2026, month: 7));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const DeleteReconciliation('r1'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      verify: (_) {
        verify(() => repo.deleteReconciliation('r1')).called(1);
        verify(() => repo.getSummary(year: 2026, month: 7)).called(2);
      },
    );

    blocTest<ReconciliationBloc, ReconciliationState>(
      '항목 제외는 removeItemIds 로 전달된다',
      build: () {
        when(() => repo.updateReconciliation(
              id: any(named: 'id'),
              label: any(named: 'label'),
              addTransactionIds: any(named: 'addTransactionIds'),
              addTransferIds: any(named: 'addTransferIds'),
              removeItemIds: any(named: 'removeItemIds'),
            )).thenAnswer((_) async => Right(detail));
        return ReconciliationBloc(
          repository: repo,
          transactionRepository: txnRepo,
          transferRepository: transferRepo,
        );
      },
      act: (bloc) async {
        bloc.add(const LoadReconciliations(year: 2026, month: 7));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const RemoveReconciliationItems(id: 'r1', itemIds: ['i1']));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      verify: (_) {
        verify(() => repo.updateReconciliation(
              id: 'r1',
              removeItemIds: ['i1'],
            )).called(1);
      },
    );
  });

  group('LoadReconciliationDetail', () {
    blocTest<ReconciliationBloc, ReconciliationState>(
      '펼치면 항목을 캐시하고, 다시 펼쳐도 재요청하지 않는다',
      build: () {
        when(() => repo.getReconciliation('r1'))
            .thenAnswer((_) async => Right(detail));
        return ReconciliationBloc(
          repository: repo,
          transactionRepository: txnRepo,
          transferRepository: transferRepo,
        );
      },
      act: (bloc) async {
        bloc.add(const LoadReconciliations(year: 2026, month: 7));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const LoadReconciliationDetail('r1'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const LoadReconciliationDetail('r1'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      verify: (_) {
        verify(() => repo.getReconciliation('r1')).called(1);
      },
    );
  });
}
