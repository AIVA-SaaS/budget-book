import 'package:budget_book/core/widgets/category_group_selector_sheet.dart'
    show kAdjustmentSentinel;

/// Phase 23 PR-X3: Pure helper that translates the UI form state into the
/// concrete fields that go onto [CreateTransaction] / [UpdateTransaction]
/// events when the user picked the virtual "잔액 조정" category.
///
/// Kept as a static method so it can be unit-tested without a widget tree.
///
/// Rules:
/// - If [selectedCategoryId] is [kAdjustmentSentinel] OR [selectedType] is
///   `'ADJUSTMENT'`, the submission is an adjustment:
///   - `type` is forced to `'ADJUSTMENT'`
///   - `categoryId` becomes `null` (ADJUSTMENT has no user category)
///   - `amount` sign is flipped when [isIncrease] is false (user entered a
///     positive value on the form; the radio determines direction)
/// - Otherwise the inputs pass through unchanged.
class AdjustmentSubmission {
  final String type;
  final String? categoryId;
  final int amount;

  const AdjustmentSubmission({
    required this.type,
    required this.categoryId,
    required this.amount,
  });

  static AdjustmentSubmission resolve({
    required String selectedType,
    required String? selectedCategoryId,
    required int rawAmount,
    required bool isIncrease,
  }) {
    final isAdjustment =
        selectedCategoryId == kAdjustmentSentinel || selectedType == 'ADJUSTMENT';
    if (!isAdjustment) {
      return AdjustmentSubmission(
        type: selectedType,
        categoryId: selectedCategoryId,
        amount: rawAmount,
      );
    }
    return AdjustmentSubmission(
      type: 'ADJUSTMENT',
      categoryId: null,
      amount: isIncrease ? rawAmount : -rawAmount,
    );
  }
}
