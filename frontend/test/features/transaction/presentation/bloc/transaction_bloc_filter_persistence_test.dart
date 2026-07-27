import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
import 'package:budget_book/core/error/failure.dart';

/// 회차 1 (2026-05-26) — Bug 1 회귀 방지:
/// 필터 적용 상태에서 거래 수정 → 저장 시, BLoC 가 dispatch 하는 자동 reload
/// LoadTransactions 가 nav 필터 (paymentMethodIds/categoryId 등) 를 보존해야 한다.
///
/// 이 가드가 무너지면 라우터 builder 가 chip-applied 필터를 wipe 하는 경로
/// (`context.go('/transactions?year=Y&month=M')`) 와 결합해 사용자 보이는
/// 회귀 (필터 chip 사라짐) 가 재발한다. 라우터 builder 분리 (S2) 와 함께
/// 두 가드가 모두 유지되어야 안전. knowledge/filter-propagation-nav-vs-content.md.
class _MockTransactionRepository extends Mock implements TransactionRepository {
  @override
  Future<Either<Failure, PageResponse<Transaction>>> getTransactions({
    int? year,
    int? month,
    TransactionFilter filter = TransactionFilter.empty,
    int page = 0,
    int size = 20,
  }) async =>
      Right<Failure, PageResponse<Transaction>>(
        PageResponse<Transaction>(
          content: const [],
          page: 0,
          size: size,
          totalElements: 0,
          totalPages: 0,
          first: true,
          last: true,
        ),
      );

  @override
  Future<Either<Failure, Transaction>> updateTransaction({
    required String id,
    String? type,
    int? amount,
    String? description,
    String? categoryId,
    String? transactionDate,
    String? memo,
    bool clearMemo = false,
    String? paymentMethodId,
    String? pocketId,
    bool? needsReview,
  }) async =>
      Right<Failure, Transaction>(_dummyTxn);

  static final _dummyTxn = Transaction(
    id: 'dummy',
    coupleId: '',
    author: const TransactionAuthor(id: '', nickname: ''),
    type: 'EXPENSE',
    amount: 0,
    description: '',
    transactionDate: '2024-01-01',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

void main() {
  late _MockTransactionRepository repo;
  late TransactionBloc bloc;

  setUp(() {
    repo = _MockTransactionRepository();
    bloc = TransactionBloc(transactionRepository: repo);
  });

  tearDown(() {
    bloc.close();
  });

  group('UpdateTransaction → nav 필터 보존', () {
    test('paymentMethodIds 단일 필터 적용 후 update → currentPaymentMethodIds 보존',
        () async {
      bloc.add(LoadTransactions.fromFilter(
        2026,
        5,
        const TransactionFilter(paymentMethodIds: {'pm-7'}),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.currentPaymentMethodIds, equals({'pm-7'}),
          reason: 'chip 적용 직후 BLoC 가 nav 필터를 기억해야 함');

      bloc.add(const UpdateTransaction(id: 'txn-x', amount: 999));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.currentPaymentMethodIds, equals({'pm-7'}),
          reason: 'update 후 자동 reload 는 currentPaymentMethodIds 를 carry');
    });

    test('categoryId 필터 적용 후 update → currentCategoryId 보존', () async {
      bloc.add(LoadTransactions.fromFilter(
        2026,
        5,
        const TransactionFilter(categoryId: 'cat-9'),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.currentCategoryId, equals('cat-9'));

      bloc.add(const UpdateTransaction(id: 'txn-x', amount: 1234));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.currentCategoryId, equals('cat-9'),
          reason: 'update 후 자동 reload 는 currentCategoryId 를 carry');
    });

    test('categoryGroupIds 적용 후 update → currentCategoryGroupIds 보존', () async {
      bloc.add(LoadTransactions.fromFilter(
        2026,
        5,
        const TransactionFilter(categoryGroupIds: {'grp-2', 'grp-3'}),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.currentCategoryGroupIds, equals({'grp-2', 'grp-3'}));

      bloc.add(const UpdateTransaction(id: 'txn-x', amount: 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.currentCategoryGroupIds, equals({'grp-2', 'grp-3'}),
          reason: 'update 후 자동 reload 는 currentCategoryGroupIds 를 carry');
    });

    test('keyword + visibility (content 필터) 동시 보존', () async {
      bloc.add(LoadTransactions.fromFilter(
        2026,
        5,
        const TransactionFilter(
          paymentMethodIds: {'pm-1'},
          keyword: '점심',
          visibility: 'INCLUDE_ONLY',
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      bloc.add(const UpdateTransaction(id: 'txn-x', amount: 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.currentPaymentMethodIds, equals({'pm-1'}));
      expect(bloc.currentFilter.keyword, equals('점심'));
      expect(bloc.currentFilter.visibility, equals('INCLUDE_ONLY'));
    });
  });
}
