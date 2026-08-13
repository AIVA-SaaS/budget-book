import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards S3 and S6 for the screens migrated onto [EntityTileRow].
///
/// S3 — the migrated screens must not reach around the tile/density contract:
///   * no `ListTile(`  — it re-introduces the 32dp contentPadding + 16dp title
///     gap that squeezed the name to 124dp on a 360dp phone.
///   * no direct `MediaQuery...width` — `BbDensity` is the single place the
///     app reads screen width, otherwise per-screen breakpoints drift apart.
///
/// S6 — a user-chosen color read with `UIHelpers.parseColor` must pass through
/// `BbColors.readable()` before it is painted, or dark mode swallows it.
void main() {
  /// Screens migrated onto the tile contract. Extend this list with each
  /// migration commit — never shrink it.
  const targets = <String>[
    'lib/features/settings/presentation/pages/asset_management_page.dart',
    'lib/features/category/presentation/widgets/category_list_tile.dart',
    'lib/core/widgets/account_balance_card.dart',
  ];

  /// `BbDensity` is the sanctioned owner of the width read.
  const densityOwner = 'lib/core/theme/bb_density.dart';

  String read(String path) => File(path).readAsStringSync();

  test('target files exist', () {
    for (final path in targets) {
      expect(File(path).existsSync(), isTrue, reason: 'missing target: $path');
    }
  });

  test('S3 — no ListTile in migrated screens', () {
    // Word boundary matters: `CategoryListTile(` is ours, `ListTile(` is not.
    final listTile = RegExp(r'(?<![A-Za-z_])ListTile\(');
    for (final path in targets) {
      expect(listTile.hasMatch(read(path)), isFalse,
          reason: '$path fell back to ListTile — use EntityTileRow');
    }
  });

  test('S3 — screens never read the screen width directly', () {
    final widthRead = RegExp(r'MediaQuery[^;]*\.width');
    for (final path in targets) {
      expect(widthRead.hasMatch(read(path)), isFalse,
          reason: '$path reads MediaQuery width — use context.density');
    }
  });

  test('S3 — BbDensity is the only place that reads the width', () {
    final widthRead = RegExp(r'MediaQuery[^;]*\.width');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path == densityOwner) continue;
      if (widthRead.hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }
    // Screens outside the asset tab have not been migrated yet; this is a
    // ratchet, so record the current set and fail on any addition.
    const knownLegacy = <String>[];
    expect(offenders..sort(), knownLegacy,
        reason: 'new MediaQuery width reads must go through BbDensity');
  });

  test('S6 — parseColor results are corrected with readable()', () {
    for (final path in targets) {
      final lines = read(path).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('parseColor(')) continue;
        expect(
          lines[i].contains('readable('),
          isTrue,
          reason: '$path:${i + 1} paints a user color without readable():\n'
              '${lines[i].trim()}',
        );
      }
    }
  });

  test('migrated screens actually use the shared tile', () {
    for (final path in targets) {
      expect(read(path), contains('EntityTileRow'),
          reason: '$path is listed as migrated but never uses EntityTileRow');
    }
  });
}
