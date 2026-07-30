import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// 프로젝트 폰트 지문 가드 (2026-07-30).
///
/// 왜 있는가: `assets/fonts/NotoSansKR-Subset.woff2` 는 **해시 없는 고정 URL** 로 서빙되고,
/// 2026-04~07 사이에는 폰트 확장자 전체가 `Cache-Control: immutable` 로 나갔다. 그때 폰트를
/// 캐시한 기기는 만료 전 재검증을 하지 않는다 → 지금 이 파일을 같은 이름으로 교체하면
/// (`ops/fonts/build-noto-subset.sh` 로 subset 을 넓히는 등) 그 기기에서는 **새로 포함된
/// 글자만 두부(□)** 로 보인다. 아이콘 폰트에서 5회 재발한 사건의 한글 버전이다.
/// 경위·측정·일반 규칙: `docs/incidents/2026-07-30_icon-font-stale-cache.md`
///
/// 아이콘 폰트처럼 배포 시 자동 rename 하지 않는 이유: 이 파일은 `AssetManifest.bin`(바이너리)
/// 에도 등재돼 있어 빌드 후 rename 이 안전하지 않다. 커밋된 자산은 `pubspec.yaml` 이 단일
/// 소스이므로 **저작 시점에 파일명을 바꾸는 것**이 맞고, 이 테스트가 그걸 강제한다.
void main() {
  test('프로젝트 폰트를 교체할 때는 파일명도 함께 바꾼다', () {
    const path = 'assets/fonts/NotoSansKR-Subset.woff2';
    // 이 값을 갱신하는 유일한 정당한 절차는 아래 실패 메시지의 3단계다.
    const pinnedSha256 =
        '16b5e7b430500a42cbc27c6f3838a2efb92259ce5d281e63bd53f9ea6adba5ca';

    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path 가 없다 — pubspec 선언과 어긋난다');

    final actual = sha256.convert(file.readAsBytesSync()).toString();
    expect(
      actual,
      pinnedSha256,
      reason: '''
$path 의 내용이 바뀌었다. 같은 URL 로 내보내면 예전 폰트를 immutable 로 캐시한 기기에서
새로 포함된 글자가 두부(□)로 보인다. 다음 순서로 처리하라:
  1. 파일명에 버전을 붙인다 — 예: NotoSansKR-Subset.v2.woff2 (또는 sha256 앞 12자)
  2. pubspec.yaml 의 `fonts:` asset 경로를 새 파일명으로 갱신 (단일 소스)
  3. 이 테스트의 path/pinnedSha256 을 새 파일 기준으로 갱신
자세한 배경: docs/incidents/2026-07-30_icon-font-stale-cache.md §5
''',
    );

    // 파일명 규칙: 내용이 바뀌면 이름도 바뀐다는 원칙이 지켜지는지(버전 토큰 존재) 확인.
    // 최초 파일(Subset)은 예외로 허용하되, 다음 교체부터는 버전 토큰이 있어야 한다.
    final name = path.split('/').last;
    final versioned = RegExp(r'\.(v\d+|[0-9a-f]{12})\.woff2$').hasMatch(name);
    expect(
      versioned || name == 'NotoSansKR-Subset.woff2',
      isTrue,
      reason: '$name — 교체 시에는 파일명에 버전 토큰(.v2. 또는 content hash)을 넣어라',
    );
  });

  test('아이콘 폰트는 pubspec 이 아니라 배포 파이프라인이 해시한다', () {
    // MaterialIcons 는 Flutter 가 빌드마다 tree-shake 해서 내용이 달라지므로 저작 시점에
    // 이름을 정할 수 없다 → 배포 시 hash-icon-font.sh 가 rename 한다. 이 두 경로가 뒤섞이면
    // (예: pubspec 에 MaterialIcons 를 직접 선언) 해시 단계가 무력화될 수 있어 고정한다.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('MaterialIcons'),
      isFalse,
      reason: 'pubspec 에서 MaterialIcons 를 직접 선언하면 배포 해시 단계의 전제가 깨진다',
    );
  });
}
