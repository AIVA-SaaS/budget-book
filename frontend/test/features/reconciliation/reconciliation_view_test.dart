import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:budget_book/core/widgets/ledger_date_header.dart';
import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_bloc.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_event.dart';
import 'package:budget_book/features/reconciliation/presentation/bloc/reconciliation_state.dart';
import 'package:budget_book/features/reconciliation/presentation/widgets/reconciliation_view.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';

class _MockReconciliationBloc
    extends MockBloc<ReconciliationEvent, ReconciliationState>
    implements ReconciliationBloc {}

/// 정산 뷰 UX 회귀 방지 — 2026-07-27 라이브 검증에서 나온 3건.
///  - 미기록 항목에 날짜가 안 보인다 (타일에 날짜가 없고 그룹 헤더도 없었다)
///  - [전체 선택] 을 발견하지 못한다 (하단 바에만 있었다)
///  - 스냅샷 항목을 한 번에 정산 취소할 수 없다 (낱건 아이콘뿐이었다)
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
    registerFallbackValue(const LoadReconciliations(year: 2026, month: 7));
  });

  const author = TransactionAuthor(id: 'u1', nickname: '홍길동');

  Transaction txn(String id, String date, {int amount = 10000}) => Transaction(
        id: id,
        coupleId: 'c1',
        author: author,
        type: 'EXPENSE',
        amount: amount,
        description: '거래 $id',
        transactionDate: date,
        visibility: 'SHARED',
        createdAt: DateTime.utc(2026, 7, 15),
        updatedAt: DateTime.utc(2026, 7, 15),
      );

  final snapshot = Reconciliation(
    id: 'r1',
    yearMonth: '2026-07',
    seq: 1,
    label: '1차',
    itemCount: 2,
    totalIncome: 0,
    totalExpense: 30000,
    totalTransfer: 0,
    reconciledAt: DateTime.utc(2026, 7, 20, 14, 3),
    reconciledBy: author,
  );

  const items = [
    ReconciliationItem(
      itemId: 'i1',
      itemKind: 'TRANSACTION',
      refId: 't10',
      snapshotAmount: 10000,
      snapshotDate: '2026-07-15',
      snapshotKind: 'EXPENSE',
      snapshotDescription: '기록된 거래 1',
    ),
    ReconciliationItem(
      itemId: 'i2',
      itemKind: 'TRANSACTION',
      refId: 't11',
      snapshotAmount: 20000,
      snapshotDate: '2026-07-16',
      snapshotKind: 'EXPENSE',
      snapshotDescription: '기록된 거래 2',
    ),
  ];

  ReconciliationLoaded loaded({
    List<Transaction> unrecorded = const [],
    Map<String, List<ReconciliationItem>> itemsBySnapshot = const {},
    int unrecordedCount = 0,
  }) =>
      ReconciliationLoaded(
        year: 2026,
        month: 7,
        snapshots: [snapshot],
        summary: ReconciliationSummary(
          yearMonth: '2026-07',
          snapshotCount: 1,
          recordedCount: 2,
          unrecordedCount: unrecordedCount,
          unrecordedIncome: 0,
          unrecordedExpense: 30000,
          unrecordedTransfer: 0,
          needsReviewCount: 0,
        ),
        unrecordedTransactions: unrecorded,
        itemsBySnapshot: itemsBySnapshot,
      );

  Future<_MockReconciliationBloc> pumpView(
      WidgetTester tester, ReconciliationState state) async {
    final bloc = _MockReconciliationBloc();
    whenListen(bloc, const Stream<ReconciliationState>.empty(),
        initialState: state);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlocProvider<ReconciliationBloc>.value(
          value: bloc,
          child: const ReconciliationView(year: 2026, month: 7),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return bloc;
  }

  group('미기록 목록', () {
    testWidgets('날짜 그룹 헤더로 언제 거래인지 보인다', (tester) async {
      await pumpView(
        tester,
        loaded(
          unrecorded: [txn('t1', '2026-07-15'), txn('t2', '2026-07-16')],
          unrecordedCount: 2,
        ),
      );

      // 표기는 리스트 모드와 같은 LedgerDateHeader 포맷.
      expect(find.text(LedgerDateHeader.format('2026-07-16')), findsOneWidget);
      expect(find.text(LedgerDateHeader.format('2026-07-15')), findsOneWidget);
      // 최신 날짜가 위 (리스트 모드와 같은 역순).
      final y16 = tester
          .getTopLeft(find.text(LedgerDateHeader.format('2026-07-16')))
          .dy;
      final y15 = tester
          .getTopLeft(find.text(LedgerDateHeader.format('2026-07-15')))
          .dy;
      expect(y16, lessThan(y15));
    });

    testWidgets('[전체 선택] 이 목록 위에 드러나 있고 전체를 고른다', (tester) async {
      await pumpView(
        tester,
        loaded(
          unrecorded: [txn('t1', '2026-07-15'), txn('t2', '2026-07-16')],
          unrecordedCount: 2,
        ),
      );

      // 하단 바가 아니라 목록 바로 위에도 있어야 한다 (발견 실패 방지) → 라벨 2곳.
      expect(find.text('전체 선택'), findsNWidgets(2));

      await tester.tap(find.text('전체 선택').first);
      await tester.pumpAndSettle();

      expect(find.text('2건 선택'), findsOneWidget);
      expect(find.text('선택 2건 정산하기'), findsOneWidget);
    });

    testWidgets('날짜 그룹 체크박스는 그 날짜만 고른다', (tester) async {
      await pumpView(
        tester,
        loaded(
          unrecorded: [
            txn('t1', '2026-07-15'),
            txn('t2', '2026-07-16'),
            txn('t3', '2026-07-16'),
          ],
          unrecordedCount: 3,
        ),
      );

      await tester.tap(find.text(LedgerDateHeader.format('2026-07-16')));
      await tester.pumpAndSettle();

      expect(find.text('2건 선택'), findsOneWidget);
    });
  });

  group('스냅샷 정산 취소', () {
    testWidgets('펼침 chevron 이 있고 액션이 본문에 드러난다', (tester) async {
      await pumpView(tester, loaded(itemsBySnapshot: {'r1': items}));

      // ⋮ 팝업 메뉴로 숨기지 않는다 (이전 구현에서 chevron 까지 사라졌다).
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('라벨 수정'), findsOneWidget);
      expect(find.text('전체 정산 취소'), findsOneWidget);
      expect(find.text('선택 0건 정산 취소'), findsOneWidget);
    });

    testWidgets('항목 2건 선택 → 한 번의 이벤트로 정산 취소', (tester) async {
      final bloc = await pumpView(
        tester,
        loaded(itemsBySnapshot: {'r1': items}),
      );

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('기록된 거래 1'));
      await tester.tap(find.text('기록된 거래 2'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('선택 2건 정산 취소'));
      await tester.pumpAndSettle();

      // 확인 다이얼로그 → 실행
      await tester.tap(find.widgetWithText(FilledButton, '정산 취소'));
      await tester.pumpAndSettle();

      // 낱건 반복이 아니라 **한 번의 요청** — 중간 실패 시 절반만 취소되는 상태 방지.
      final captured = verify(() => bloc.add(captureAny())).captured
          .whereType<RemoveReconciliationItems>()
          .toList();
      expect(captured, hasLength(1));
      expect(captured.single.id, 'r1');
      expect(captured.single.itemIds, containsAll(['i1', 'i2']));
    });
  });
}
