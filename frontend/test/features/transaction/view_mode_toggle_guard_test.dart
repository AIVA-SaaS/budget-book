import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 거래 탭 뷰 토글 가드 (2026-07-30 개정).
///
/// 경위: 정산 세그먼트(`Icons.fact_check`, 0xE256)만 빈칸으로 보이는 증상이 3회 재발했다.
/// 서버 폰트는 결백했다(cmap 에 0xE256 존재, 외곽선 존재, headless Chrome 렌더 정상).
/// 실제 원인은 **URL 신원 ≠ 내용 신원**이었다 — 트리셰이킹 아이콘 폰트는 내용이 빌드마다
/// 바뀌는데 URL 이 `assets/fonts/MaterialIcons-Regular.otf` 로 고정이라, 그 URL 이
/// `immutable` 로 나가던 시절에 캐시한 기기는 구 subset 을 물고 재검증조차 하지 않았다.
///
/// 그래서 2026-07-28 에는 "아이콘 전용 금지(텍스트 라벨 필수)"로 우회했지만, 근본 원인을
/// 배포 파이프라인에서 제거한 뒤(폰트 파일명 content hash) 라벨을 걷어냈다.
/// 이 파일은 그 전제 두 가지를 고정한다:
///   1. 아이콘 전용이므로 세그먼트마다 tooltip(접근성/식별 수단)이 있다.
///   2. 폰트 해시 게이트가 배포 파이프라인에 배선돼 있다 — 이게 빠지면 1의 전제가 무너진다.
///
/// 위젯 테스트로 잡으려면 거래 목록 페이지 전체(BLoC 5종 + DI)를 띄워야 해서, 여기서는
/// 소스 선언 자체를 고정한다 (필터 필드 개수 가드와 같은 방식).
void main() {
  test('뷰 토글 3개 세그먼트는 아이콘 + tooltip 을 가진다', () {
    final source = File(
      'lib/features/transaction/presentation/pages/transaction_list_page.dart',
    ).readAsStringSync();

    final start = source.indexOf('class _ViewModeToggle');
    expect(start, isNonNegative, reason: '_ViewModeToggle 클래스를 찾지 못했다');
    final body = source.substring(start);

    final segmentsBlock = body.substring(
      body.indexOf('segments:'),
      body.indexOf('selected:'),
    );

    final segmentCount = 'ButtonSegment('.allMatches(segmentsBlock).length;
    expect(segmentCount, 3, reason: '뷰 토글 세그먼트가 3개(목록/달력/정산)가 아니다');

    final iconCount = 'icon: Icon('.allMatches(segmentsBlock).length;
    final tooltipCount = 'tooltip:'.allMatches(segmentsBlock).length;
    expect(
      iconCount,
      segmentCount,
      reason: '아이콘 없는 세그먼트가 있다 (icon $iconCount개 / segment $segmentCount개)',
    );
    expect(
      tooltipCount,
      segmentCount,
      reason: 'tooltip 없는 세그먼트가 있다 — 아이콘 전용 토글은 이름을 알 방법이 사라진다',
    );
  });

  test('아이콘 폰트 content hash 게이트가 배포 파이프라인에 배선돼 있다', () {
    final script = File('../infra/scripts/hash-icon-font.sh');
    expect(
      script.existsSync(),
      isTrue,
      reason: 'infra/scripts/hash-icon-font.sh 가 없다 — 아이콘 전용 토글의 전제가 무너진다',
    );

    final workflow =
        File('../.github/workflows/deploy-nas.yml').readAsStringSync();
    expect(
      workflow.contains('hash-icon-font.sh'),
      isTrue,
      reason: 'deploy 워크플로가 hash-icon-font.sh 를 실행하지 않는다 → 폰트 URL 이 고정되고 '
          '구 subset 을 문 기기에서 새 아이콘이 다시 빈칸이 된다',
    );

    final verify =
        File('../infra/scripts/verify-cache-headers.sh').readAsStringSync();
    expect(
      verify.contains('FontManifest.json') && verify.contains(r'[0-9a-f]{12}'),
      isTrue,
      reason: 'verify-cache-headers.sh 가 아이콘 폰트 URL 의 content hash 를 검증하지 않는다',
    );
  });
}
