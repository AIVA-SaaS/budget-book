import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/statistics/domain/entities/statistics_filter.dart';

void main() {
  group('StatisticsFilter', () {
    test('initial defaults — EXPENSE / ALL / no date range', () {
      expect(StatisticsFilter.initial.categoryType, 'EXPENSE');
      expect(StatisticsFilter.initial.visibilityFilter, 'ALL');
      expect(StatisticsFilter.initial.hasDateRange, isFalse);
      expect(StatisticsFilter.initial.hasAny, isFalse);
    });

    test('hasAny 각 필드', () {
      expect(const StatisticsFilter(categoryType: 'INCOME').hasAny, isTrue);
      expect(const StatisticsFilter(visibilityFilter: 'SHARED').hasAny, isTrue);
      expect(const StatisticsFilter(dateFrom: '2026-04-01', dateTo: '2026-04-30').hasAny, isTrue);
    });

    test('hasDateRange — from/to 둘 다 있어야 true', () {
      expect(const StatisticsFilter(dateFrom: '2026-04-01').hasDateRange, isFalse);
      expect(const StatisticsFilter(dateTo: '2026-04-30').hasDateRange, isFalse);
      expect(
        const StatisticsFilter(dateFrom: '2026-04-01', dateTo: '2026-04-30').hasDateRange,
        isTrue,
      );
    });

    test('copyWith clearDateRange', () {
      const f = StatisticsFilter(
        categoryType: 'INCOME',
        visibilityFilter: 'SHARED',
        dateFrom: '2026-04-01',
        dateTo: '2026-04-30',
        dateRangeLabel: '4월',
      );
      final cleared = f.copyWith(clearDateRange: true);
      expect(cleared.dateFrom, isNull);
      expect(cleared.dateTo, isNull);
      expect(cleared.dateRangeLabel, isNull);
      // 다른 필드는 유지
      expect(cleared.categoryType, 'INCOME');
      expect(cleared.visibilityFilter, 'SHARED');
    });

    // 회귀 방지: TransactionFilter 와 같은 round-trip 테스트
    test('round-trip preserves ALL filter fields — 월 변경 시 필터 drop 방지', () {
      const full = StatisticsFilter(
        categoryType: 'INCOME',
        visibilityFilter: 'PRIVATE',
        dateFrom: '2026-04-01',
        dateTo: '2026-04-30',
        dateRangeLabel: '4월',
      );
      expect(full.copyWith(), equals(full));
      expect(full.categoryType, 'INCOME');
      expect(full.visibilityFilter, 'PRIVATE');
      expect(full.dateFrom, '2026-04-01');
      expect(full.dateTo, '2026-04-30');
      expect(full.dateRangeLabel, '4월');
    });

    test('Equatable 동등성', () {
      const a = StatisticsFilter(categoryType: 'INCOME', dateFrom: '2026-04-01');
      const b = StatisticsFilter(categoryType: 'INCOME', dateFrom: '2026-04-01');
      const c = StatisticsFilter(categoryType: 'EXPENSE', dateFrom: '2026-04-01');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
