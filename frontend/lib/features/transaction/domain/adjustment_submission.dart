import 'package:budget_book/core/widgets/category_group_selector_sheet.dart'
    show kAdjustmentSentinel;

/// 회차 4 (Phase 23 PR-X3 복원) — UI form state 를 BE 로 보낼 type/categoryId/amount
/// 로 변환하는 pure helper. widget tree 없이 단위 테스트 가능하도록 static 메서드.
///
/// Rules:
/// - `selectedCategoryId == kAdjustmentSentinel` 또는 `selectedType == 'ADJUSTMENT'`:
///   - `type` 강제 'ADJUSTMENT'
///   - `categoryId` null (ADJUSTMENT 는 사용자 카테고리 없음)
///   - `amount` 부호는 [isIncrease] = false 일 때 음수로 뒤집음 (form 의 양수 입력 + 방향 라디오)
/// - 그 외 입력 그대로 통과.
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
    final isAdjustment = selectedCategoryId == kAdjustmentSentinel ||
        selectedType == 'ADJUSTMENT';
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
