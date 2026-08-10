import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';
import 'package:budget_book/features/reconciliation/domain/repositories/reconciliation_repository.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_summary_cubit.dart';

class MockReconciliationRepository extends Mock
    implements ReconciliationRepository {}

void main() {
  late MockReconciliationRepository repo;

  setUp(() => repo = MockReconciliationRepository());

  const march = ReconciliationSummary(
    yearMonth: '2026-03',
    snapshotCount: 1,
    recordedCount: 3,
    unrecordedCount: 7,
    unrecordedIncome: 0,
    unrecordedExpense: 250000,
    unrecordedTransfer: 0,
    needsReviewCount: 2,
  );

  blocTest<ReconciliationSummaryCubit, ReconciliationSummaryState>(
    'emits the summary for the requested month',
    build: () {
      when(() => repo.getSummary(year: 2026, month: 3))
          .thenAnswer((_) async => const Right(march));
      return ReconciliationSummaryCubit(repository: repo);
    },
    act: (c) => c.load(year: 2026, month: 3),
    expect: () => [
      const ReconciliationSummaryState(loading: true),
      const ReconciliationSummaryState(summary: march),
    ],
  );

  blocTest<ReconciliationSummaryCubit, ReconciliationSummaryState>(
    'clears the summary when the request fails (card disappears, tab intact)',
    build: () {
      when(() => repo.getSummary(year: 2026, month: 3))
          .thenAnswer((_) async => const Left(ServerFailure('boom')));
      return ReconciliationSummaryCubit(repository: repo);
    },
    act: (c) => c.load(year: 2026, month: 3),
    expect: () => [
      const ReconciliationSummaryState(loading: true),
      const ReconciliationSummaryState(),
    ],
  );

  test('a late response for an old month does not overwrite the new one',
      () async {
    // 3월 응답을 느리게, 4월 응답을 빠르게 → 3월 응답이 나중에 도착한다.
    const april = ReconciliationSummary(
      yearMonth: '2026-04',
      snapshotCount: 0,
      recordedCount: 0,
      unrecordedCount: 1,
      unrecordedIncome: 0,
      unrecordedExpense: 1000,
      unrecordedTransfer: 0,
      needsReviewCount: 0,
    );
    when(() => repo.getSummary(year: 2026, month: 3)).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return const Right(march);
    });
    when(() => repo.getSummary(year: 2026, month: 4))
        .thenAnswer((_) async => const Right(april));

    final cubit = ReconciliationSummaryCubit(repository: repo);
    final slow = cubit.load(year: 2026, month: 3);
    await cubit.load(year: 2026, month: 4);
    await slow;

    expect(cubit.state.summary, april,
        reason: '늦게 도착한 지난 달 응답이 현재 달 숫자를 덮어쓰면 안 된다.');
    await cubit.close();
  });
}
