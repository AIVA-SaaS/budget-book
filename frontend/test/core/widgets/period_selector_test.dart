import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/period_selector.dart';

void main() {
  group('PeriodSelection', () {
    test('periodTypeString returns correct API strings', () {
      expect(
        const PeriodSelection(type: PeriodType.none).periodTypeString,
        'NONE',
      );
      expect(
        const PeriodSelection(type: PeriodType.daily).periodTypeString,
        'DAILY',
      );
      expect(
        const PeriodSelection(type: PeriodType.weekly).periodTypeString,
        'WEEKLY',
      );
      expect(
        const PeriodSelection(type: PeriodType.monthly).periodTypeString,
        'MONTHLY',
      );
    });

    test('fromApiValues creates correct PeriodSelection', () {
      final selection = PeriodSelection.fromApiValues(
        periodType: 'WEEKLY',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
      );
      expect(selection.type, PeriodType.weekly);
      expect(selection.startDate, DateTime(2026, 3, 1));
      expect(selection.endDate, DateTime(2026, 3, 31));
      expect(selection.year, 2026);
      expect(selection.month, 3);
    });

    test('fromApiValues defaults to monthly for unknown type', () {
      final selection = PeriodSelection.fromApiValues(
        periodType: 'UNKNOWN',
      );
      expect(selection.type, PeriodType.monthly);
    });
  });

  group('calculateWeekRanges', () {
    test('returns 5 weeks for March 2026 (31 days)', () {
      final ranges = calculateWeekRanges(2026, 3);
      expect(ranges.length, 5);
      expect(ranges[0], (DateTime(2026, 3, 1), DateTime(2026, 3, 7)));
      expect(ranges[1], (DateTime(2026, 3, 8), DateTime(2026, 3, 14)));
      expect(ranges[2], (DateTime(2026, 3, 15), DateTime(2026, 3, 21)));
      expect(ranges[3], (DateTime(2026, 3, 22), DateTime(2026, 3, 28)));
      expect(ranges[4], (DateTime(2026, 3, 29), DateTime(2026, 3, 31)));
    });

    test('returns 5 weeks for months with 30 days', () {
      final ranges = calculateWeekRanges(2026, 4); // April has 30 days
      expect(ranges.length, 5);
      expect(ranges[4], (DateTime(2026, 4, 29), DateTime(2026, 4, 30)));
    });

    test('returns 4 weeks for February 2026 (28 days)', () {
      final ranges = calculateWeekRanges(2026, 2);
      expect(ranges.length, 4);
      expect(ranges[0], (DateTime(2026, 2, 1), DateTime(2026, 2, 7)));
      expect(ranges[3], (DateTime(2026, 2, 22), DateTime(2026, 2, 28)));
    });

    test('returns 5 weeks for February leap year (29 days)', () {
      final ranges = calculateWeekRanges(2024, 2);
      expect(ranges.length, 5);
      expect(ranges[4], (DateTime(2024, 2, 29), DateTime(2024, 2, 29)));
    });
  });

  group('PeriodSelector widget', () {
    testWidgets('renders segmented buttons with all 4 options',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeriodSelector(
            initialSelection: const PeriodSelection(type: PeriodType.none),
            onChanged: (_) {},
          ),
        ),
      ));

      expect(find.text('없음'), findsOneWidget);
      expect(find.text('일별'), findsOneWidget);
      expect(find.text('주간'), findsOneWidget);
      expect(find.text('월별'), findsOneWidget);
    });

    testWidgets('shows "기간 미지정" for NONE type', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeriodSelector(
            initialSelection: const PeriodSelection(type: PeriodType.none),
            onChanged: (_) {},
          ),
        ),
      ));

      expect(find.text('기간 미지정'), findsOneWidget);
    });

    testWidgets('shows date pickers for DAILY type', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeriodSelector(
            initialSelection: const PeriodSelection(type: PeriodType.daily),
            onChanged: (_) {},
          ),
        ),
      ));

      expect(find.text('시작일'), findsOneWidget);
      expect(find.text('종료일'), findsOneWidget);
    });

    testWidgets('shows week breakdown for WEEKLY type', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeriodSelector(
            initialSelection: const PeriodSelection(
              type: PeriodType.weekly,
              year: 2026,
              month: 3,
            ),
            onChanged: (_) {},
          ),
        ),
      ));

      expect(find.text('주차별 기간'), findsOneWidget);
      expect(find.text('1주차:'), findsOneWidget);
      expect(find.text('5주차:'), findsOneWidget);
    });

    testWidgets('shows month pickers for MONTHLY type', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeriodSelector(
            initialSelection:
                const PeriodSelection(type: PeriodType.monthly),
            onChanged: (_) {},
          ),
        ),
      ));

      expect(find.text('시작월'), findsOneWidget);
      expect(find.text('종료월'), findsOneWidget);
    });

    testWidgets('calls onChanged when type is switched', (tester) async {
      PeriodSelection? lastSelection;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeriodSelector(
            initialSelection: const PeriodSelection(type: PeriodType.none),
            onChanged: (selection) {
              lastSelection = selection;
            },
          ),
        ),
      ));

      // Tap the "일별" segment
      await tester.tap(find.text('일별'));
      await tester.pumpAndSettle();

      expect(lastSelection, isNotNull);
      expect(lastSelection!.type, PeriodType.daily);
    });

    testWidgets('disabled selector does not respond to taps', (tester) async {
      PeriodSelection? lastSelection;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeriodSelector(
            initialSelection: const PeriodSelection(type: PeriodType.none),
            enabled: false,
            onChanged: (selection) {
              lastSelection = selection;
            },
          ),
        ),
      ));

      // Tap the "일별" segment - should not trigger onChanged
      await tester.tap(find.text('일별'));
      await tester.pumpAndSettle();

      expect(lastSelection, isNull);
    });
  });
}
