import 'dart:convert';
import 'dart:io';

/// Palette references we count as hardcoded: `Colors.red`, `Colors.grey.shade200`, …
///
/// `Colors.transparent` is excluded — it carries no light/dark meaning, so it
/// is safe in either theme.
final RegExp _paletteColor =
    RegExp(r'(?<![A-Za-z0-9_])Colors\.(?!transparent\b)[A-Za-z]\w*');

/// Counts hardcoded palette color references per file under [libDir].
///
/// Files with zero references are omitted, so a new file is "0 by default"
/// and any reference in it shows up as an addition.
Map<String, int> scanHardcodedColors(String libDir) {
  final counts = <String, int>{};
  for (final entity in Directory(libDir).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    final withoutComments = _stripCommentsAndDocs(source);
    final count = _paletteColor.allMatches(withoutComments).length;
    if (count > 0) counts[entity.path.replaceAll(r'\', '/')] = count;
  }
  return Map.fromEntries(
      counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}

/// Comments must not count — a doc comment explaining why `Colors.green` was
/// removed would otherwise read as a violation.
String _stripCommentsAndDocs(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .map((line) {
      final idx = line.indexOf('//');
      return idx >= 0 ? line.substring(0, idx) : line;
    })
    .join('\n');

const String baselinePath = 'test/core/theme/hardcoded_color_baseline.json';

/// Regenerates the ratchet baseline: `dart run tool/hardcoded_color_scan.dart`
///
/// Only run this when a change intentionally alters the color counts, and read
/// the diff — the whole point of the ratchet is that the direction is visible.
void main() {
  final counts = scanHardcodedColors('lib');
  final total = counts.values.fold<int>(0, (a, b) => a + b);
  File(baselinePath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(counts)}\n',
  );
  stdout.writeln('wrote $baselinePath — $total refs in ${counts.length} files');
}
