import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/utils/date_helpers.dart';

void main() {
  group('DateHelper.calculateWeekRanges', () {
    test('April 2026 should have 5 week ranges', () {
      // April 2026: Wed Apr 1 - Thu Apr 30
      // Week 1: Apr 1 (Wed) ~ Apr 5 (Sun) — partial
      // Week 2: Apr 6 (Mon) ~ Apr 12 (Sun)
      // Week 3: Apr 13 (Mon) ~ Apr 19 (Sun)
      // Week 4: Apr 20 (Mon) ~ Apr 26 (Sun)
      // Week 5: Apr 27 (Mon) ~ Apr 30 (Thu) — partial
      final ranges = DateHelper.calculateWeekRanges(2026, 4);
      expect(ranges.length, 5);

      // First week starts on Apr 1
      expect(ranges[0].start, DateTime(2026, 4, 1));
      expect(ranges[0].end, DateTime(2026, 4, 5));
      expect(ranges[0].weekNumber, 1);
      expect(ranges[0].days, 5);

      // Second week is full
      expect(ranges[1].start, DateTime(2026, 4, 6));
      expect(ranges[1].end, DateTime(2026, 4, 12));
      expect(ranges[1].days, 7);

      // Last week ends on Apr 30
      expect(ranges[4].start, DateTime(2026, 4, 27));
      expect(ranges[4].end, DateTime(2026, 4, 30));
      expect(ranges[4].days, 4);
    });

    test('March 2026 should have correct week ranges', () {
      // March 2026: Sun Mar 1 - Tue Mar 31
      // Week 1: Mar 1 (Sun) — partial (1 day)
      // Week 2: Mar 2 (Mon) ~ Mar 8 (Sun)
      // ...
      final ranges = DateHelper.calculateWeekRanges(2026, 3);
      expect(ranges.first.start, DateTime(2026, 3, 1));

      // Last range should end on Mar 31
      expect(ranges.last.end, DateTime(2026, 3, 31));
    });

    test('month starting on Monday has first full week', () {
      // June 2026: Monday Jun 1
      final ranges = DateHelper.calculateWeekRanges(2026, 6);
      expect(ranges[0].start, DateTime(2026, 6, 1));
      expect(ranges[0].end, DateTime(2026, 6, 7));
      expect(ranges[0].days, 7);
    });

    test('February 2026 (28 days, starts Sunday)', () {
      // Feb 2026: Sun Feb 1 - Sat Feb 28
      final ranges = DateHelper.calculateWeekRanges(2026, 2);
      expect(ranges.first.start, DateTime(2026, 2, 1));
      expect(ranges.last.end, DateTime(2026, 2, 28));

      // Total days across all ranges should equal 28
      final totalDays = ranges.fold<int>(0, (sum, w) => sum + w.days);
      expect(totalDays, 28);
    });
  });

  group('DateHelper.calculateProRataBudget', () {
    test('full week (7 days) returns weeklyAmount', () {
      final week = WeekRange(
        start: DateTime(2026, 4, 6),
        end: DateTime(2026, 4, 12),
        weekNumber: 2,
      );
      expect(DateHelper.calculateProRataBudget(100000, week), 100000);
    });

    test('partial week (5 days) returns pro-rata', () {
      final week = WeekRange(
        start: DateTime(2026, 4, 1),
        end: DateTime(2026, 4, 5),
        weekNumber: 1,
      );
      // 100000 * 5 / 7 = 71428
      expect(DateHelper.calculateProRataBudget(100000, week), 71428);
    });

    test('partial week (4 days) returns pro-rata', () {
      final week = WeekRange(
        start: DateTime(2026, 4, 27),
        end: DateTime(2026, 4, 30),
        weekNumber: 5,
      );
      // 100000 * 4 / 7 = 57142
      expect(DateHelper.calculateProRataBudget(100000, week), 57142);
    });
  });

  group('DateHelper.isDateInWeekRange', () {
    final week = WeekRange(
      start: DateTime(2026, 4, 6),
      end: DateTime(2026, 4, 12),
      weekNumber: 2,
    );

    test('date within range returns true', () {
      expect(DateHelper.isDateInWeekRange(DateTime(2026, 4, 8), week), true);
    });

    test('date on start boundary returns true', () {
      expect(DateHelper.isDateInWeekRange(DateTime(2026, 4, 6), week), true);
    });

    test('date on end boundary returns true', () {
      expect(DateHelper.isDateInWeekRange(DateTime(2026, 4, 12), week), true);
    });

    test('date before range returns false', () {
      expect(DateHelper.isDateInWeekRange(DateTime(2026, 4, 5), week), false);
    });

    test('date after range returns false', () {
      expect(DateHelper.isDateInWeekRange(DateTime(2026, 4, 13), week), false);
    });
  });
}
