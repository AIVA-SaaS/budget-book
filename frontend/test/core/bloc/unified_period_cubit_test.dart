import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/bloc/unified_period_cubit.dart';

void main() {
  group('UnifiedPeriodState', () {
    test('defaults: month mode with current year/month', () {
      final cubit = UnifiedPeriodCubit(initialYear: 2026, initialMonth: 3);
      expect(cubit.state.year, 2026);
      expect(cubit.state.month, 3);
      expect(cubit.state.isRangeMode, isFalse);
      expect(cubit.state.dateFromIso, isNull);
      cubit.close();
    });

    test('dateFromIso/dateToIso format YYYY-MM-DD', () {
      const s = UnifiedPeriodState(
        year: 2026,
        month: 3,
        dateFrom: null,
      );
      expect(s.dateFromIso, isNull);
      final s2 = s.copyWith(
        dateFrom: DateTime(2026, 3, 5),
        dateTo: DateTime(2026, 3, 20),
      );
      expect(s2.dateFromIso, '2026-03-05');
      expect(s2.dateToIso, '2026-03-20');
      expect(s2.isRangeMode, isTrue);
    });
  });

  group('UnifiedPeriodCubit', () {
    test('changeMonth clears range (moves back to month mode)', () {
      final cubit = UnifiedPeriodCubit(initialYear: 2026, initialMonth: 1);
      cubit.setDateRange(DateTime(2026, 1, 5), DateTime(2026, 1, 20));
      expect(cubit.state.isRangeMode, isTrue);

      cubit.changeMonth(2026, 2);
      expect(cubit.state.year, 2026);
      expect(cubit.state.month, 2);
      expect(cubit.state.isRangeMode, isFalse, reason: 'range should clear on month change');
      cubit.close();
    });

    test('setDateRange syncs year/month from "from" date', () {
      final cubit = UnifiedPeriodCubit(initialYear: 2026, initialMonth: 1);
      cubit.setDateRange(DateTime(2026, 3, 5), DateTime(2026, 4, 20));
      expect(cubit.state.year, 2026);
      expect(cubit.state.month, 3);
      expect(cubit.state.isRangeMode, isTrue);
      cubit.close();
    });

    test('same month = no emit (prevent unnecessary reload)', () {
      final cubit = UnifiedPeriodCubit(initialYear: 2026, initialMonth: 3);
      final emitted = <UnifiedPeriodState>[];
      final sub = cubit.stream.listen(emitted.add);
      cubit.changeMonth(2026, 3);
      cubit.changeMonth(2026, 3);
      expectLater(sub.asFuture<void>(), completes);
      expect(emitted, isEmpty, reason: 'no emit for identical month');
      cubit.close();
    });

    test('clearRange returns to month mode without touching year/month', () {
      final cubit = UnifiedPeriodCubit(initialYear: 2026, initialMonth: 3);
      cubit.setDateRange(DateTime(2026, 5, 10), DateTime(2026, 5, 25));
      expect(cubit.state.year, 2026);
      expect(cubit.state.month, 5);

      cubit.clearRange();
      expect(cubit.state.isRangeMode, isFalse);
      expect(cubit.state.year, 2026);
      expect(cubit.state.month, 5, reason: 'year/month preserved after clearRange');
      cubit.close();
    });

    test('setWeek stores + clears on null', () {
      final cubit = UnifiedPeriodCubit(initialYear: 2026, initialMonth: 3);
      cubit.setWeek(2);
      expect(cubit.state.week, 2);
      cubit.setWeek(null);
      expect(cubit.state.week, isNull);
      cubit.close();
    });
  });
}
