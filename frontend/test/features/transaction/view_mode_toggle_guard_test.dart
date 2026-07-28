import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 거래 탭 뷰 토글은 **글리프에 의존하지 않아야 한다** (2026-07-28).
///
/// 정산 세그먼트가 아이콘 전용(`Icons.fact_check`)이던 시절, 특정 기기에서 그 글리프만
/// 렌더되지 않아 3번째 칸이 빈칸으로 보였다. 서버(폰트 cmap·글리프 외곽선·번들 코드포인트)는
/// 결백했고, 서버가 되돌릴 수 없는 클라이언트 폰트 상태가 원인이었다.
/// → 진입점 라벨을 텍스트로 두면 어떤 폰트 상태에서도 기능이 보인다.
///
/// 위젯 테스트로 잡으려면 거래 목록 페이지 전체(BLoC 5종 + DI)를 띄워야 해서, 여기서는
/// 소스 선언 자체를 고정한다 (필터 필드 개수 가드와 같은 방식).
void main() {
  test('뷰 토글 3개 세그먼트는 텍스트 라벨을 가진다 (아이콘 전용 금지)', () {
    final source = File(
      'lib/features/transaction/presentation/pages/transaction_list_page.dart',
    ).readAsStringSync();

    final start = source.indexOf('class _ViewModeToggle');
    expect(start, isNonNegative, reason: '_ViewModeToggle 클래스를 찾지 못했다');
    final body = source.substring(start);

    for (final label in ['목록', '달력', '정산']) {
      expect(
        body.contains("label: Text('$label')"),
        isTrue,
        reason: '$label 세그먼트에 텍스트 라벨이 없다 — 글리프가 안 뜨는 기기에서 빈칸이 된다',
      );
    }

    // 아이콘을 다시 넣더라도 라벨과 **함께**여야 한다. 아이콘 전용 세그먼트 금지.
    final segmentsBlock = body.substring(
      body.indexOf('segments:'),
      body.indexOf('selected:'),
    );
    final iconCount = 'icon: Icon('.allMatches(segmentsBlock).length;
    final labelCount = 'label: Text('.allMatches(segmentsBlock).length;
    expect(
      labelCount >= iconCount,
      isTrue,
      reason: '아이콘만 있는 세그먼트가 있다 (icon $iconCount개 / label $labelCount개)',
    );
  });
}
