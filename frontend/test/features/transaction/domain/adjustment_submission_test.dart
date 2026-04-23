import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/widgets/category_group_selector_sheet.dart'
    show kAdjustmentSentinel;
import 'package:budget_book/features/transaction/domain/adjustment_submission.dart';

/// Phase 23 PR-X3 — unit tests for the pure translation logic that converts
/// form-state (selected type + selected category id + amount + direction)
/// into the concrete (type, categoryId, amount) that is sent to the BE.
void main() {
  group('AdjustmentSubmission.resolve', () {
    test(
      'non-adjustment EXPENSE passes through unchanged',
      () {
        final result = AdjustmentSubmission.resolve(
          selectedType: 'EXPENSE',
          selectedCategoryId: 'cat-1',
          rawAmount: 15000,
          isIncrease: true, // ignored
        );
        expect(result.type, 'EXPENSE');
        expect(result.categoryId, 'cat-1');
        expect(result.amount, 15000);
      },
    );

    test(
      'non-adjustment INCOME passes through unchanged',
      () {
        final result = AdjustmentSubmission.resolve(
          selectedType: 'INCOME',
          selectedCategoryId: 'cat-income',
          rawAmount: 2500000,
          isIncrease: false, // ignored
        );
        expect(result.type, 'INCOME');
        expect(result.categoryId, 'cat-income');
        expect(result.amount, 2500000);
      },
    );

    test(
      'sentinel category triggers ADJUSTMENT: type forced, categoryId nulled, '
      'amount kept positive when isIncrease=true',
      () {
        final result = AdjustmentSubmission.resolve(
          selectedType: 'EXPENSE',
          selectedCategoryId: kAdjustmentSentinel,
          rawAmount: 10000,
          isIncrease: true,
        );
        expect(result.type, 'ADJUSTMENT');
        expect(result.categoryId, isNull);
        expect(result.amount, 10000);
      },
    );

    test(
      'sentinel category with isIncrease=false flips the sign to negative',
      () {
        final result = AdjustmentSubmission.resolve(
          selectedType: 'EXPENSE',
          selectedCategoryId: kAdjustmentSentinel,
          rawAmount: 7500,
          isIncrease: false,
        );
        expect(result.type, 'ADJUSTMENT');
        expect(result.categoryId, isNull);
        expect(result.amount, -7500);
      },
    );

    test(
      'selectedType==ADJUSTMENT alone also triggers translation '
      '(defensive: in case sentinel was cleared but type still set)',
      () {
        final result = AdjustmentSubmission.resolve(
          selectedType: 'ADJUSTMENT',
          selectedCategoryId: null,
          rawAmount: 20000,
          isIncrease: false,
        );
        expect(result.type, 'ADJUSTMENT');
        expect(result.categoryId, isNull);
        expect(result.amount, -20000);
      },
    );

    test(
      'ADJUSTMENT submission never carries a real categoryId '
      '(even if sentinel was replaced mid-flight)',
      () {
        // If selectedType is still ADJUSTMENT but somehow a real categoryId
        // snuck in, we still null it — BE forbids ADJUSTMENT + category.
        final result = AdjustmentSubmission.resolve(
          selectedType: 'ADJUSTMENT',
          selectedCategoryId: 'stale-cat-id',
          rawAmount: 5000,
          isIncrease: true,
        );
        expect(result.type, 'ADJUSTMENT');
        expect(result.categoryId, isNull);
        expect(result.amount, 5000);
      },
    );
  });
}
