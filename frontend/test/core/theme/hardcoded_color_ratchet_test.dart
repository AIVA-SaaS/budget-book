import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/hardcoded_color_scan.dart';

/// Guard S2 — the hardcoded-color ratchet.
///
/// The app carries a legacy of raw `Colors.*` palette values that have no dark
/// pair (that is *why* dark mode looked wrong). Converting all of them at once
/// is not this round's scope, so instead this test freezes the current count
/// per file: the number can go **down**, never up, and a brand-new file starts
/// at zero.
///
/// The counts are recomputed here by the same scanner that wrote the baseline
/// (`dart run tool/hardcoded_color_scan.dart`) — a hand-edited number in the
/// JSON fails just as loudly as a new color, because the comparison is exact
/// in both directions.
void main() {
  /// Files this round migrated onto [BbColors]. They must stay at zero.
  const migratedToTokens = <String>[
    'lib/core/theme/app_theme.dart',
    'lib/core/theme/bb_colors.dart',
    'lib/core/utils/payment_method_helpers.dart',
    'lib/core/widgets/account_balance_card.dart',
    'lib/core/widgets/asset_edit_mode_scope.dart',
    'lib/core/widgets/entity_tile_row.dart',
    'lib/core/widgets/one_line_label.dart',
    'lib/features/category/presentation/widgets/category_list_tile.dart',
    'lib/features/settings/presentation/pages/asset_management_page.dart',
  ];

  late Map<String, int> baseline;
  late Map<String, int> actual;

  setUpAll(() {
    baseline = (json.decode(File(baselinePath).readAsStringSync()) as Map)
        .map((k, v) => MapEntry(k as String, v as int));
    actual = scanHardcodedColors('lib');
  });

  test('no file gained hardcoded palette colors', () {
    final increased = <String>[];
    actual.forEach((path, count) {
      final allowed = baseline[path] ?? 0;
      if (count > allowed) increased.add('$path: $allowed → $count');
    });
    expect(
      increased,
      isEmpty,
      reason: '하드코딩 팔레트 색은 늘어날 수 없다. context.bb 토큰을 쓰거나, 정말 의도한 '
          '변경이면 `dart run tool/hardcoded_color_scan.dart` 로 baseline 을 다시 '
          '만들고 diff 를 확인하라.\n${increased.join('\n')}',
    );
  });

  test('new files start at zero', () {
    final unlisted = actual.keys.where((p) => !baseline.containsKey(p)).toList();
    expect(unlisted, isEmpty,
        reason: '신규 파일은 하드코딩 색 0 이어야 한다:\n${unlisted.join('\n')}');
  });

  test('baseline has no stale or inflated entries', () {
    final stale = <String>[];
    baseline.forEach((path, allowed) {
      final count = actual[path] ?? 0;
      if (count < allowed) stale.add('$path: baseline $allowed, 실제 $count');
    });
    expect(
      stale,
      isEmpty,
      reason: 'baseline 이 실제보다 높다 — 그만큼 가드가 헐거워진 상태다. '
          '색을 줄였다면 `dart run tool/hardcoded_color_scan.dart` 로 baseline 을 '
          '낮춰 그 성과를 고정하라.\n${stale.join('\n')}',
    );
  });

  test('files migrated to BbColors stay at zero', () {
    for (final path in migratedToTokens) {
      expect(File(path).existsSync(), isTrue, reason: 'missing file: $path');
      expect(actual[path] ?? 0, 0,
          reason: '$path 는 토큰으로 이관된 파일이다 — 하드코딩 색을 다시 넣지 않는다');
      expect(baseline.containsKey(path), isFalse,
          reason: '$path 가 baseline 에 있으면 안 된다 (0 이어야 한다)');
    }
  });

  test('the ratchet is actually measuring something', () {
    // 회귀 방지: 스캐너가 아무것도 못 찾는 상태로 조용히 망가지면 가드가 무력해진다.
    final total = actual.values.fold<int>(0, (a, b) => a + b);
    expect(total, greaterThan(0));
    expect(baseline, isNotEmpty);
  });
}
