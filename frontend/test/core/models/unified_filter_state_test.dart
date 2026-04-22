import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';

void main() {
  group('UnifiedFilterState', () {
    test('default state has no active filters', () {
      const state = UnifiedFilterState();
      expect(state.hasActiveFilters, isFalse);
      expect(state.hasDateRange, isFalse);
    });

    test('hasActiveFilters returns true when dateFrom is set', () {
      final state = UnifiedFilterState(
        dateFrom: DateTime(2026, 4, 1),
      );
      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters returns true when categoryIds is non-empty', () {
      const state = UnifiedFilterState(categoryIds: {'cat-1'});
      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters returns true when paymentMethodIds is non-empty', () {
      const state = UnifiedFilterState(paymentMethodIds: {'pm-1'});
      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters returns true when amountMin is set', () {
      const state = UnifiedFilterState(amountMin: 1000);
      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters returns true when keyword is non-empty', () {
      const state = UnifiedFilterState(keyword: 'test');
      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters returns false when keyword is empty', () {
      const state = UnifiedFilterState(keyword: '');
      expect(state.hasActiveFilters, isFalse);
    });

    test('hasActiveFilters returns true when transactionTypes is non-empty',
        () {
      const state = UnifiedFilterState(transactionTypes: {'EXPENSE'});
      expect(state.hasActiveFilters, isTrue);
      // Legacy singular getter still reports the first selection.
      expect(state.transactionType, 'EXPENSE');
    });

    test('transactionTypes multi-select preserves all values', () {
      const state = UnifiedFilterState(
        transactionTypes: {'EXPENSE', 'INCOME', 'TRANSFER'},
      );
      expect(state.hasActiveFilters, isTrue);
      expect(state.transactionTypes, {'EXPENSE', 'INCOME', 'TRANSFER'});
    });

    test('hasActiveFilters returns true when visibility is not ALL', () {
      const state = UnifiedFilterState(visibility: 'SHARED');
      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters returns false when visibility is ALL', () {
      const state = UnifiedFilterState(visibility: 'ALL');
      expect(state.hasActiveFilters, isFalse);
    });

    test('hasActiveFilters returns true when status is set', () {
      const state = UnifiedFilterState(status: 'PLANNED');
      expect(state.hasActiveFilters, isTrue);
    });

    test('hasDateRange returns true only when both dates are set', () {
      final state1 = UnifiedFilterState(dateFrom: DateTime(2026, 4, 1));
      expect(state1.hasDateRange, isFalse);

      final state2 = UnifiedFilterState(
        dateFrom: DateTime(2026, 4, 1),
        dateTo: DateTime(2026, 4, 30),
      );
      expect(state2.hasDateRange, isTrue);
    });

    test('copyWith preserves unchanged values', () {
      final state = UnifiedFilterState(
        dateFrom: DateTime(2026, 4, 1),
        categoryIds: const {'cat-1'},
        amountMin: 1000,
      );
      final updated = state.copyWith(amountMax: 5000);
      expect(updated.dateFrom, state.dateFrom);
      expect(updated.categoryIds, state.categoryIds);
      expect(updated.amountMin, 1000);
      expect(updated.amountMax, 5000);
    });

    test('copyWith clearDateRange clears date fields', () {
      final state = UnifiedFilterState(
        dateFrom: DateTime(2026, 4, 1),
        dateTo: DateTime(2026, 4, 30),
        dateRangeLabel: '이번 달',
      );
      final cleared = state.copyWith(clearDateRange: true);
      expect(cleared.dateFrom, isNull);
      expect(cleared.dateTo, isNull);
      expect(cleared.dateRangeLabel, isNull);
    });

    test('copyWith clearCategory clears category fields', () {
      const state = UnifiedFilterState(
        categoryIds: {'cat-1'},
        categoryName: '식비',
      );
      final cleared = state.copyWith(clearCategory: true);
      expect(cleared.categoryIds, isEmpty);
      expect(cleared.categoryName, isNull);
    });

    test('copyWith clearPaymentMethod clears payment method fields', () {
      const state = UnifiedFilterState(
        paymentMethodIds: {'pm-1'},
        paymentMethodName: '신한카드',
      );
      final cleared = state.copyWith(clearPaymentMethod: true);
      expect(cleared.paymentMethodIds, isEmpty);
      expect(cleared.paymentMethodName, isNull);
    });

    test('copyWith clearAmount clears amount fields', () {
      const state = UnifiedFilterState(amountMin: 1000, amountMax: 5000);
      final cleared = state.copyWith(clearAmount: true);
      expect(cleared.amountMin, isNull);
      expect(cleared.amountMax, isNull);
    });

    test('copyWith clearTransactionType empties transactionTypes', () {
      const state = UnifiedFilterState(transactionTypes: {'EXPENSE'});
      final cleared = state.copyWith(clearTransactionType: true);
      expect(cleared.transactionTypes, isEmpty);
      expect(cleared.transactionType, isNull);
    });

    test('clearAll returns empty state', () {
      final state = UnifiedFilterState(
        dateFrom: DateTime(2026, 4, 1),
        dateTo: DateTime(2026, 4, 30),
        categoryIds: const {'cat-1'},
        amountMin: 1000,
        keyword: 'test',
      );
      final cleared = state.clearAll();
      expect(cleared.hasActiveFilters, isFalse);
      expect(cleared.dateFrom, isNull);
      expect(cleared.categoryIds, isEmpty);
    });

    test('equatable comparison works', () {
      const state1 = UnifiedFilterState(categoryIds: {'cat-1'});
      const state2 = UnifiedFilterState(categoryIds: {'cat-1'});
      const state3 = UnifiedFilterState(categoryIds: {'cat-2'});
      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });
}
