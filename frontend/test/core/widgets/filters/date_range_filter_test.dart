import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/filters/date_range_filter.dart';

void main() {
  group('DateRangeIndicator', () {
    testWidgets('renders label and close button', (tester) async {
      bool cleared = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DateRangeIndicator(
            label: '이번 주',
            onClear: () => cleared = true,
          ),
        ),
      ));

      expect(find.text('이번 주'), findsOneWidget);
      expect(find.byIcon(Icons.date_range), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      expect(cleared, isTrue);
    });
  });

  group('showDateRangeFilterSheet', () {
    testWidgets('shows preset options', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDateRangeFilterSheet(
                context: context,
                onApply: (_, __, ___) {},
                onClear: () {},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('기간 필터'), findsOneWidget);
      expect(find.text('이번 주'), findsOneWidget);
      expect(find.text('지난 주'), findsOneWidget);
      expect(find.text('이번 달'), findsOneWidget);
      expect(find.text('지난 달'), findsOneWidget);
      expect(find.text('직접 설정'), findsOneWidget);
    });

    testWidgets('shows clear option when currentFrom is set', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDateRangeFilterSheet(
                context: context,
                currentFrom: DateTime(2026, 4, 1),
                currentTo: DateTime(2026, 4, 30),
                onApply: (_, __, ___) {},
                onClear: () {},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('기간 필터 해제'), findsOneWidget);
    });

    testWidgets('does not show clear option when no current range',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDateRangeFilterSheet(
                context: context,
                onApply: (_, __, ___) {},
                onClear: () {},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('기간 필터 해제'), findsNothing);
    });

    testWidgets('tapping "이번 달" calls onApply', (tester) async {
      String? appliedLabel;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDateRangeFilterSheet(
                context: context,
                onApply: (label, from, to) {
                  appliedLabel = label;
                },
                onClear: () {},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('이번 달'));
      await tester.pumpAndSettle();

      expect(appliedLabel, '이번 달');
    });

    testWidgets('tapping clear calls onClear', (tester) async {
      bool cleared = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDateRangeFilterSheet(
                context: context,
                currentFrom: DateTime(2026, 4, 1),
                onApply: (_, __, ___) {},
                onClear: () => cleared = true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('기간 필터 해제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기간 필터 해제'));
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
    });
  });
}
