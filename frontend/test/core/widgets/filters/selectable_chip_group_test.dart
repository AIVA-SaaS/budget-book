import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/filters/selectable_chip_group.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  const items = [
    ChipItem(value: 'A', label: 'A'),
    ChipItem(value: 'B', label: 'B'),
    ChipItem(value: 'C', label: 'C'),
  ];

  group('SelectableChipGroup.multi', () {
    testWidgets('"전체" chip derived on when all items selected',
        (tester) async {
      await tester.pumpWidget(_host(
        SelectableChipGroup<String>.multi(
          items: items,
          selected: const {'A', 'B', 'C'},
          onChanged: (_) {},
          direction: ChipGroupDirection.wrap,
        ),
      ));
      final allChip = tester.widget<FilterChip>(find.ancestor(
        of: find.text('전체'),
        matching: find.byType(FilterChip),
      ));
      expect(allChip.selected, isTrue);
    });

    testWidgets('tap "전체" while all on → clears', (tester) async {
      Set<String>? last;
      await tester.pumpWidget(_host(
        SelectableChipGroup<String>.multi(
          items: items,
          selected: const {'A', 'B', 'C'},
          onChanged: (next) => last = next,
          direction: ChipGroupDirection.wrap,
        ),
      ));
      await tester.tap(find.text('전체'));
      expect(last, isEmpty);
    });

    testWidgets('tap "전체" while empty → selects all', (tester) async {
      Set<String>? last;
      await tester.pumpWidget(_host(
        SelectableChipGroup<String>.multi(
          items: items,
          selected: const {},
          onChanged: (next) => last = next,
          direction: ChipGroupDirection.wrap,
        ),
      ));
      await tester.tap(find.text('전체'));
      expect(last, {'A', 'B', 'C'});
    });

    testWidgets('individual toggle adds/removes', (tester) async {
      Set<String>? last;
      await tester.pumpWidget(_host(
        SelectableChipGroup<String>.multi(
          items: items,
          selected: const {'A'},
          onChanged: (next) => last = next,
          direction: ChipGroupDirection.wrap,
        ),
      ));
      await tester.tap(find.text('B'));
      expect(last, {'A', 'B'});
    });

    testWidgets('"전체" derived off when partial', (tester) async {
      await tester.pumpWidget(_host(
        SelectableChipGroup<String>.multi(
          items: items,
          selected: const {'A', 'B'},
          onChanged: (_) {},
          direction: ChipGroupDirection.wrap,
        ),
      ));
      final allChip = tester.widget<FilterChip>(find.ancestor(
        of: find.text('전체'),
        matching: find.byType(FilterChip),
      ));
      expect(allChip.selected, isFalse);
    });
  });

  group('SelectableChipGroup.single', () {
    testWidgets('"전체" on when selected is null', (tester) async {
      await tester.pumpWidget(_host(
        SelectableChipGroup<String>.single(
          items: items,
          selected: null,
          onChanged: (_) {},
          direction: ChipGroupDirection.wrap,
        ),
      ));
      final allChip = tester.widget<FilterChip>(find.ancestor(
        of: find.text('전체'),
        matching: find.byType(FilterChip),
      ));
      expect(allChip.selected, isTrue);
    });

    testWidgets('tap individual → sets value', (tester) async {
      String? last;
      await tester.pumpWidget(_host(
        SelectableChipGroup<String>.single(
          items: items,
          selected: null,
          onChanged: (v) => last = v,
          direction: ChipGroupDirection.wrap,
        ),
      ));
      await tester.tap(find.text('B'));
      expect(last, 'B');
    });

    testWidgets('tap "전체" → sets null', (tester) async {
      String? last = 'unset';
      await tester.pumpWidget(_host(
        SelectableChipGroup<String>.single(
          items: items,
          selected: 'A',
          onChanged: (v) => last = v,
          direction: ChipGroupDirection.wrap,
        ),
      ));
      await tester.tap(find.text('전체'));
      expect(last, isNull);
    });
  });
}
