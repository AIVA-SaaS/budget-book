import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/category_group_selector_sheet.dart';
import 'package:budget_book/features/transaction/domain/adjustment_submission.dart';

void main() {
  group('AdjustmentSubmission.resolve', () {
    test('non-adjustment passthrough — EXPENSE 유지', () {
      final r = AdjustmentSubmission.resolve(
        selectedType: 'EXPENSE',
        selectedCategoryId: 'cat-1',
        rawAmount: 5000,
        isIncrease: true,
      );
      expect(r.type, 'EXPENSE');
      expect(r.categoryId, 'cat-1');
      expect(r.amount, 5000);
    });

    test('non-adjustment passthrough — INCOME 유지', () {
      final r = AdjustmentSubmission.resolve(
        selectedType: 'INCOME',
        selectedCategoryId: 'cat-2',
        rawAmount: 10000,
        isIncrease: false,
      );
      expect(r.type, 'INCOME');
      expect(r.amount, 10000); // isIncrease 무시 (non-adjustment)
    });

    test('sentinel categoryId → ADJUSTMENT 강제 + 증가 부호', () {
      final r = AdjustmentSubmission.resolve(
        selectedType: 'EXPENSE',
        selectedCategoryId: kAdjustmentSentinel,
        rawAmount: 7000,
        isIncrease: true,
      );
      expect(r.type, 'ADJUSTMENT');
      expect(r.categoryId, isNull);
      expect(r.amount, 7000);
    });

    test('sentinel + 감소 → 음수 부호', () {
      final r = AdjustmentSubmission.resolve(
        selectedType: 'EXPENSE',
        selectedCategoryId: kAdjustmentSentinel,
        rawAmount: 7000,
        isIncrease: false,
      );
      expect(r.type, 'ADJUSTMENT');
      expect(r.categoryId, isNull);
      expect(r.amount, -7000);
    });

    test('selectedType=ADJUSTMENT (수정 진입) + 증가 → 양수', () {
      final r = AdjustmentSubmission.resolve(
        selectedType: 'ADJUSTMENT',
        selectedCategoryId: null,
        rawAmount: 3000,
        isIncrease: true,
      );
      expect(r.type, 'ADJUSTMENT');
      expect(r.categoryId, isNull);
      expect(r.amount, 3000);
    });

    test('selectedType=ADJUSTMENT + 감소 → 음수', () {
      final r = AdjustmentSubmission.resolve(
        selectedType: 'ADJUSTMENT',
        selectedCategoryId: kAdjustmentSentinel,
        rawAmount: 3000,
        isIncrease: false,
      );
      expect(r.amount, -3000);
    });
  });
}
