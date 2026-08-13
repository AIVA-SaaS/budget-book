import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard S1 — the tile's width contract is sealed at compile time.
///
/// Past `ui_pattern` failures all took the shape of "한 곳에 얹기": a caller
/// slipped an arbitrary widget into a slot and re-broke the layout somewhere
/// else. `EntityTileRow` therefore accepts value types only. This test fails
/// the build if that seal is loosened.
void main() {
  final source = File('lib/core/widgets/entity_tile_row.dart').readAsStringSync();

  test('title is a String, never a Widget', () {
    expect(source, contains('final String title;'));
    expect(
      RegExp(r'\bWidget\??\s+title\b').hasMatch(source),
      isFalse,
      reason: 'EntityTileRow.title must stay a String (guard S1)',
    );
  });

  test('every public slot takes a value type', () {
    const valueTypedSlots = <String>[
      'final String? subtitle;',
      'final List<EntityBadge> badges;',
      'final EntityMetric? trailingMetric;',
      'final List<EntityMetric> metrics;',
      'final IconData? leadingIcon;',
      'final EntityTileActions? actions;',
      'final EntityViewAction? viewAction;',
    ];
    for (final slot in valueTypedSlots) {
      expect(source, contains(slot), reason: 'missing sealed slot: $slot');
    }
  });

  test('no Widget-typed or builder-typed fields leak in', () {
    final offenders = RegExp(r'^\s*final\s+(Widget|WidgetBuilder)\b.*;$',
            multiLine: true)
        .allMatches(source)
        .map((m) => m.group(0)!.trim())
        .toList();
    expect(offenders, isEmpty,
        reason: 'these fields break the width contract: $offenders');
  });

  test('the tile does not fall back to ListTile', () {
    expect(RegExp(r'(?<![A-Za-z_])ListTile\(').hasMatch(source), isFalse,
        reason: 'EntityTileRow owns its own padding — ListTile reintroduces '
            'the 32dp contentPadding + 16dp title gap it exists to remove');
  });

  test('badge and metric labels are plain strings', () {
    expect(source, contains('final String label;'));
    expect(source, contains('final String value;'));
  });
}
