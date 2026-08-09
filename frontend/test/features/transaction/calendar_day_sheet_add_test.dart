import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'dart:io';

import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transaction/presentation/widgets/transaction_calendar_view.dart';

/// 달력 일자 시트의 "거래 추가" 진입 가드.
///
/// 경위: 달력 뷰에서 날짜를 누르면 일자 시트(`_showDayBottomSheet`)가 열리는데 시트 안에
/// 추가 진입이 전혀 없었다. 시트는 모달이라 페이지 FAB 을 배리어로 덮으므로 그 상태에서는
/// 거래를 추가할 방법이 없고, 시트를 닫고 FAB 을 눌러도 선택한 날짜가 승계되지 않았다
/// (목록 모드에는 `_DateHeader.onAddTap` 으로 이미 있던 진입이 달력에만 빠져 있었다).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  const author = TransactionAuthor(id: 'u1', nickname: '홍길동');

  Transaction txn(String date) => Transaction(
        id: 't1',
        coupleId: 'c1',
        author: author,
        type: 'EXPENSE',
        amount: 10000,
        description: '점심',
        transactionDate: date,
        visibility: 'SHARED',
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      );

  Future<void> pump(
    WidgetTester tester, {
    required List<Transaction> transactions,
    void Function(DateTime)? onAddTap,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionCalendarView(
          year: 2026,
          month: 8,
          transactions: transactions,
          transfers: const [],
          onAddTap: onAddTap,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('거래 없는 날: 시트에 [이 날짜에 거래 추가] 버튼이 있고 그 날짜로 콜백된다',
      (tester) async {
    DateTime? added;
    await pump(tester, transactions: const [], onAddTap: (d) => added = d);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(find.text('거래 없음'), findsOneWidget);
    expect(find.text('이 날짜에 거래 추가'), findsOneWidget);

    await tester.tap(find.text('이 날짜에 거래 추가'));
    await tester.pumpAndSettle();

    expect(added, isNotNull);
    expect(added!.year, 2026);
    expect(added!.month, 8);
    expect(added!.day, 15);
    // 시트는 닫힌 뒤 콜백된다 — 남겨두면 폼에서 돌아왔을 때 옛 데이터가 보인다.
    expect(find.text('거래 없음'), findsNothing);
  });

  testWidgets('거래 있는 날: 시트 헤더의 + 버튼으로도 같은 날짜로 추가된다', (tester) async {
    DateTime? added;
    await pump(
      tester,
      transactions: [txn('2026-08-15')],
      onAddTap: (d) => added = d,
    );

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(find.text('점심'), findsOneWidget);
    final addButton = find.byTooltip('이 날짜에 거래 추가');
    expect(addButton, findsOneWidget);

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(added, isNotNull);
    expect(added!.day, 15);
  });

  testWidgets('onAddTap 미주입 시 추가 어포던스를 노출하지 않는다', (tester) async {
    await pump(tester, transactions: [txn('2026-08-15')]);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(find.text('점심'), findsOneWidget);
    expect(find.byTooltip('이 날짜에 거래 추가'), findsNothing);
    expect(find.text('이 날짜에 거래 추가'), findsNothing);
  });

  /// 진입 URL 은 `_buildCreateTransactionUrl` 단일 소스만 만든다(필터된 결제수단 전파).
  /// 위젯이 직접 push 하거나 상위가 URL 을 수동 조립하면 필터 propagation 이 끊긴다.
  /// 목록 페이지 전체를 띄우려면 BLoC 5종 + DI 가 필요해 선언 자체를 고정한다
  /// (`view_mode_toggle_guard_test.dart` 와 같은 방식).
  test('달력 onAddTap 배선은 _buildCreateTransactionUrl 을 경유한다', () {
    final page = File(
      'lib/features/transaction/presentation/pages/transaction_list_page.dart',
    ).readAsStringSync();

    final start = page.indexOf('TransactionCalendarView(');
    expect(start, isNonNegative, reason: 'TransactionCalendarView 호출부를 찾지 못했다');
    final callSite = page.substring(start, page.indexOf('),', page.indexOf('onAddTap:', start)));

    expect(callSite.contains('onAddTap:'), isTrue,
        reason: '달력에 거래 추가 진입이 배선되지 않았다');
    expect(callSite.contains('_buildCreateTransactionUrl('), isTrue,
        reason: '헬퍼를 경유하지 않으면 필터된 결제수단이 전파되지 않는다');

    final widget = File(
      'lib/features/transaction/presentation/widgets/transaction_calendar_view.dart',
    ).readAsStringSync();
    expect(widget.contains("'/transactions/create"), isFalse,
        reason: '달력 위젯이 직접 URL 을 조립하면 헬퍼 단일 소스가 깨진다');
  });
}
