import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/reconciliation/presentation/widgets/reconciliation_summary_card.dart';
import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';

/// 분석 탭 "월말 점검" 카드.
///
/// 고정하는 것: 용어(미기록) · 서버 소계를 그대로 표시 · 확인 필요 배지 ·
/// 정산 완료 상태 · **탭 시 보고 있던 달이 목적지 URL 에 실린다**(navigation_state).
void main() {
  ReconciliationSummary summary({
    int unrecordedCount = 7,
    int recordedCount = 3,
    int needsReviewCount = 0,
    int income = 0,
    int expense = 0,
    int transfer = 0,
  }) =>
      ReconciliationSummary(
        yearMonth: '2026-03',
        snapshotCount: 1,
        recordedCount: recordedCount,
        unrecordedCount: unrecordedCount,
        unrecordedIncome: income,
        unrecordedExpense: expense,
        unrecordedTransfer: transfer,
        needsReviewCount: needsReviewCount,
      );

  /// Hosts the card at `/` and records where a tap navigates to.
  Future<Uri?> pumpAndTap(
    WidgetTester tester,
    ReconciliationSummary data, {
    bool tap = true,
  }) async {
    Uri? landed;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: ReconciliationSummaryCard(
              summary: data,
              year: 2026,
              month: 3,
            ),
          ),
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) {
            landed = state.uri;
            return const Scaffold(body: Text('ledger'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    if (tap) {
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
    }
    return landed;
  }

  testWidgets('shows the unrecorded count using the ledger wording',
      (tester) async {
    await pumpAndTap(tester, summary(unrecordedCount: 7), tap: false);

    expect(find.text('월말 점검'), findsOneWidget);
    expect(find.text('미기록 7건'), findsOneWidget);
    // "미정산" 은 이 앱의 용어가 아니다 (정산은 3개 동명 개념).
    expect(find.textContaining('미정산'), findsNothing);
  });

  testWidgets('renders server subtotals verbatim', (tester) async {
    await pumpAndTap(
      tester,
      summary(expense: 250000, income: 100000),
      tap: false,
    );

    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('|');
    expect(text, contains('지출'));
    expect(text, contains('수입'));
    // 이체 소계가 0 이면 줄에 나타나지 않는다.
    expect(text, isNot(contains('이체')));
  });

  testWidgets('shows a needs-review badge when there are flagged rows',
      (tester) async {
    await pumpAndTap(tester, summary(needsReviewCount: 2), tap: false);

    expect(find.text('확인 필요 2건'), findsOneWidget);
  });

  testWidgets('shows the done state when nothing is left unrecorded',
      (tester) async {
    await pumpAndTap(
      tester,
      summary(unrecordedCount: 0, recordedCount: 4),
      tap: false,
    );

    expect(find.text('이 달은 정산 완료입니다'), findsOneWidget);
    expect(find.textContaining('미기록'), findsNothing);
  });

  testWidgets('carries the displayed month and the reconciliation view on tap',
      (tester) async {
    final landed = await pumpAndTap(tester, summary());

    expect(landed, isNotNull);
    // 분석 탭이 3월을 보고 있었으면 목적지도 3월이어야 한다 — "오늘" 로 리셋되면
    // navigation_state 인시던트(3회 재발)의 재현이다.
    expect(landed!.queryParameters['year'], '2026');
    expect(landed.queryParameters['month'], '3');
    expect(landed.queryParameters['view'], 'reconciliation');
  });

  testWidgets('tapping the card body navigates the same way', (tester) async {
    Uri? landed;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: ReconciliationSummaryCard(
              summary: summary(),
              year: 2026,
              month: 3,
            ),
          ),
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) {
            landed = state.uri;
            return const Scaffold(body: Text('ledger'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('미기록 7건'));
    await tester.pumpAndSettle();

    expect(landed?.queryParameters['view'], 'reconciliation');
  });
}
