import 'dart:io';

/// Finds `ListTile` (and its Switch/Checkbox/Radio variants) painted inside a
/// [Container]/[DecoratedBox] that has its own background color, with no
/// [Material] in between.
///
/// Why this matters: a `ListTile` paints its background and ink splashes on
/// the **nearest Material ancestor**, so a tinted box between the two hides
/// them. Newer Flutter versions assert on this at build time — which means the
/// same source passes locally on an older SDK and fails in CI. Scanning the
/// source catches it regardless of which SDK is installed.
///
/// Fix: wrap the tile in `Material(type: MaterialType.transparency, …)`.
final RegExp _box =
    RegExp(r'(?<![A-Za-z0-9_])(Container|DecoratedBox|AnimatedContainer)\(');
final RegExp _tile = RegExp(
    r'(?<![A-Za-z0-9_])(SwitchListTile|CheckboxListTile|RadioListTile|ListTile)\(');
final RegExp _paintsColor = RegExp(r'color:\s*(?!Colors\.transparent)\S');

/// `file:line` for every offending tile under [libDir].
List<String> findInkHiddenTiles(String libDir) {
  final findings = <String>{};
  for (final entity in Directory(libDir).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();

    final coloredBoxes = <(int, int)>[];
    for (final m in _box.allMatches(source)) {
      final open = m.end - 1;
      final close = _matchingParen(source, open);
      // Only the box's own arguments count — a color deeper inside a child is
      // not this box's background.
      final head = source.substring(m.start, close.clamp(m.start, source.length));
      final ownArgs = head.length > 600 ? head.substring(0, 600) : head;
      if (_paintsColor.hasMatch(ownArgs)) coloredBoxes.add((m.start, close));
    }

    for (final t in _tile.allMatches(source)) {
      for (final (start, end) in coloredBoxes) {
        if (start >= t.start || t.start >= end) continue;
        // A Material between the box and the tile restores the ink surface.
        if (source.substring(start, t.start).contains('Material(')) break;
        final line = '\n'.allMatches(source.substring(0, t.start)).length + 1;
        findings.add('${entity.path.replaceAll(r'\', '/')}:$line');
        break;
      }
    }
  }
  final sorted = findings.toList()..sort();
  return sorted;
}

int _matchingParen(String source, int openIndex) {
  var depth = 0;
  var i = openIndex;
  while (i < source.length) {
    final c = source[i];
    if (c == '"' || c == "'") {
      final quote = c;
      i++;
      while (i < source.length && source[i] != quote) {
        if (source[i] == r'\') i++;
        i++;
      }
    } else if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return source.length;
}

void main() {
  final findings = findInkHiddenTiles('lib');
  if (findings.isEmpty) {
    stdout.writeln('no ink-hidden ListTiles');
  } else {
    stdout.writeln(findings.join('\n'));
  }
}
