import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `/transactions?view=` 배선 가드.
///
/// 뷰 모드(리스트/달력/정산)는 원래 SharedPreferences 에만 있었다. 홈 "월말 점검"
/// 위젯이 정산 뷰로 진입하려면 URL 로 지정할 수 있어야 해서 2026-08-10 에 신설했다.
/// 판정 규칙 자체는 `ledger_route_test.dart` 가 순수 함수로 검증하고, 여기서는
/// **그 규칙이 실제 페이지에 연결돼 있는지**를 고정한다.
void main() {
  final router = File('lib/core/router/app_router.dart').readAsStringSync();
  final page = File(
    'lib/features/transaction/presentation/pages/transaction_list_page.dart',
  ).readAsStringSync();

  test('router reads the view param and passes it down', () {
    expect(router.contains("queryParameters['view']"), isTrue);
    expect(router.contains('initialView: view'), isTrue);
  });

  test('URL view wins over the stored view without racing it', () {
    // _loadViewMode() 는 비동기 prefs 복원이라, URL 로 뷰를 지정한 진입에서도
    // 호출하면 나중에 완료되면서 URL 지정을 덮어쓴다(정산 뷰 → 리스트로 튕김).
    // 그래서 else 분기에서만 호출해야 한다.
    final initState = page.substring(
      page.indexOf('void initState()'),
      page.indexOf('_TxViewMode _viewModeFrom'),
    );

    expect(initState.contains('parseLedgerView(widget.initialView)'), isTrue,
        reason: 'initState 가 URL 뷰를 읽지 않는다.');
    expect(initState.contains('} else {\n      _loadViewMode();'), isTrue,
        reason: 'URL 뷰가 지정된 경우에도 _loadViewMode() 를 호출하면 레이스가 생긴다.');
  });

  test('URL entry does not overwrite the saved view preference', () {
    // _saveViewMode 는 사용자가 화면 안에서 토글할 때만 호출된다.
    final saveCalls = RegExp(r'_saveViewMode\(').allMatches(page).length;
    expect(saveCalls, 2,
        reason: '_saveViewMode 는 선언 1회 + 토글 호출 1회여야 한다. '
            '늘었다면 URL 진입이 기본 뷰를 덮어쓰고 있을 가능성이 크다.');
  });

  test('didUpdateWidget delegates the transition rule to the pure function', () {
    expect(page.contains('nextLedgerViewOnUpdate('), isTrue,
        reason: '전환 규칙(특히 value→null 무시)이 페이지 안에 다시 흩어지면 '
            '단위 테스트가 지키지 못한다.');
  });
}
