import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 계단 금지 가드 — 하네스 `ui_pattern` STRUCTURAL_FIX (2026-08-20).
///
/// 왜 이 파일이 있나
/// -----------------
/// 크기 체계는 이미 두 번 같은 실패를 겪었다: **토큰을 추가했지만 계단이 남아
/// 경쟁 경로가 됐다.**
///
///   1회 (폰트) — `BbDensity` 의 타일 폰트만 폭에 반응하고 테마 타이포는 상수였다
///                → "자산 탭만 적절하고 거래·분석·더보기는 크다"
///   2회 (여백) — `BbDensity` 의 3단 여백만 반응하고 `BbSpace` 는 7% 상수였다
///                → "여백·간격도 적절하게 조정되게 해줘"
///
/// 그래서 `BbDensity`(3단 계단)를 **삭제**했고, 이 가드가 **재도입을 막는다**.
/// 완료 기준은 "곡선을 추가했다"가 아니라 **"계단이 0개다"** 다.
void main() {
  const scaleOwner = 'lib/core/theme/bb_scale.dart';

  /// 곡선 정의 자체는 폭을 비교할 수밖에 없다(clamp). 그 한 파일만 예외다.
  const allowed = <String>{scaleOwner};

  List<File> dartFiles() => [
        for (final e in Directory('lib').listSync(recursive: true))
          if (e is File && e.path.endsWith('.dart')) e,
      ];

  test('S1 — BbDensity 는 삭제됐다 (3단 계단 정본 부재)', () {
    expect(File('lib/core/theme/bb_density.dart').existsSync(), isFalse,
        reason: 'BbDensity 가 되살아났다 — 계단이 곡선과 경쟁한다');
    for (final f in dartFiles()) {
      final src = f.readAsStringSync();
      expect(src.contains('BbDensityTier'), isFalse,
          reason: '${f.path} 에 3단 tier 가 다시 생겼다');
      expect(src.contains('compactMaxWidth') || src.contains('regularMaxWidth'),
          isFalse,
          reason: '${f.path} 에 브레이크포인트 상수가 다시 생겼다');
    }
  });

  test('S2 — 폭으로 분기하지 않는다 (계단 = 크기가 점프하는 지점)', () {
    // `width < 600 ? 44 : 48` 류. 곡선이면 이런 비교가 필요 없다.
    final branch = RegExp(
      r'width\s*[<>]=?\s*[\d.]|[\d.]+\s*[<>]=?\s*width\b|'
      r'\.width\s*[<>]=?\s*[\d.]',
    );
    final offenders = <String>[];
    for (final f in dartFiles()) {
      if (allowed.contains(f.path)) continue;
      for (final line in f.readAsStringSync().split('\n')) {
        final t = line.trimLeft();
        if (t.startsWith('//')) continue;
        if (branch.hasMatch(line)) {
          offenders.add('${f.path}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '폭 분기(계단)가 생겼다. 크기는 `BbType`/`BbSpace`/`BbBox` 곡선으로 '
            '표현하고, 밀도 판정이 꼭 필요하면 컨테이너 폭 함수를 '
            '`bb_scale.dart` 에 두어라:\n${offenders.join('\n')}');
  });

  test('S3 — 국소 VisualDensity override 가 없다 (테마 단일 소스)', () {
    // 검수 클래스 D: 17곳이 테마 밀도와 경쟁하고 있었다(2026-08-20 실측).
    // 밀도는 `AppTheme._densityFor` 하나가 정한다.
    final offenders = <String>[];
    for (final f in dartFiles()) {
      if (f.path == 'lib/core/theme/app_theme.dart') continue;
      for (final line in f.readAsStringSync().split('\n')) {
        final t = line.trimLeft();
        if (t.startsWith('//') || t.startsWith('///')) continue;
        if (line.contains('visualDensity:')) offenders.add('${f.path}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: '국소 visualDensity 가 테마 밀도와 경쟁한다:\n${offenders.join('\n')}');
  });

  test('S4 — 폭을 채우는 자리에 `*Button.icon` 을 쓰지 않는다', () {
    // 사용자 지적(2026-08-20): "-1일 전/+1일 후 문구의 왼쪽 여백이 더 길다."
    // 측정 결과 버튼 좌우 여백은 같았고(57.30/57.30) **라벨**이 아이콘폭+간격
    // (=24dp)만큼 밀려 있었다 — `*Button.icon` 은 아이콘+라벨을 한 덩어리로
    // 중앙 정렬하기 때문이다. 폭이 남는 자리에서만 눈에 띈다.
    // 대안은 `BbStepButton`(라벨은 정중앙, 아이콘은 바깥쪽 끝).
    final iconButton = RegExp(r'(Text|Outlined|Elevated|Filled)Button\.icon\(');
    final offenders = <String>[];
    for (final f in dartFiles()) {
      final lines = f.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!iconButton.hasMatch(lines[i])) continue;
        final window = lines
            .sublist((i - 4).clamp(0, lines.length), (i + 8).clamp(0, lines.length))
            .join(' ');
        if (window.contains('Expanded(') ||
            window.contains('double.infinity') ||
            window.contains('Size.fromHeight')) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '폭이 남는 자리의 Button.icon 은 라벨이 중앙에서 벗어난다 — '
            'BbStepButton 을 쓰거나 아이콘을 바깥쪽에 고정하라:\n${offenders.join('\n')}');
  });
}
