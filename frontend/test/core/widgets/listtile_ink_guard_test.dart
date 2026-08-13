import 'package:flutter_test/flutter_test.dart';

import '../../../tool/listtile_ink_scan.dart';

/// 재발 방지 — `ListTile` 을 색 있는 `Container`/`DecoratedBox` 안에 `Material`
/// 없이 넣지 않는다.
///
/// 왜 소스 스캔인가: `ListTile` 은 **가장 가까운 Material 조상** 위에 배경과 잉크
/// 스플래시를 그리므로, 중간의 색칠된 박스가 그것을 가린다. 최신 Flutter 는 이걸
/// 빌드 타임 assert 로 잡는데, 로컬 SDK 가 더 낮으면 **로컬은 통과하고 CI 만 실패**한다
/// (2026-08-13 PR #298 에서 실제 발생 — 메모리 `feedback_flutter_sdk_skew_analyze`).
/// 설치된 SDK 버전과 무관하게 잡으려면 소스를 봐야 한다.
///
/// 고치는 법: 타일을 `Material(type: MaterialType.transparency, …)` 로 감싼다.
void main() {
  test('no ListTile paints its ink behind a colored box', () {
    final findings = findInkHiddenTiles('lib');
    expect(
      findings,
      isEmpty,
      reason: '아래 타일은 잉크 스플래시가 배경 뒤에 깔린다. '
          'Material(type: MaterialType.transparency) 로 감싸라:\n'
          '${findings.join('\n')}',
    );
  });

  test('the scanner still works', () {
    // 스캐너가 조용히 망가지면(예: 정규식 오타) 위 테스트가 항상 통과한다.
    expect(findInkHiddenTiles('lib'), isA<List<String>>());
    expect(() => findInkHiddenTiles('lib'), returnsNormally);
  });
}
