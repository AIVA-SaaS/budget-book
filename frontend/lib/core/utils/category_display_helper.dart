import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';

/// 회차 12 P3 (2026-05-03) — 카테고리 표시 통일 helper.
///
/// 자동 선택 (suggestion / AI) 응답은 categoryGroupName 정보 없음 →
/// CategoryGroupBloc lookup 으로 "$groupName > $categoryName" 형식 build.
///
/// 사용처 (모든 categoryName 만 받는 응답 표시):
/// - transaction_form_page._applySuggestionPattern (suggestion 자동 선택)
/// - transaction_form_page._applyAiCategory (AI 자동 선택)
/// - 그 외 categoryName 만 받는 응답 표시 시 통일
///
/// fallback: groupName lookup 실패 시 categoryName 만 반환.
String formatCategoryDisplay(
  String? categoryId, {
  required String categoryName,
}) {
  if (categoryId == null || categoryId.isEmpty) return categoryName;

  // CategoryGroupBloc 은 singleton (di/injection 등록).
  final groupBloc = getIt<CategoryGroupBloc>();
  final state = groupBloc.state;
  if (state is! CategoryGroupLoaded) return categoryName;

  for (final group in state.groups) {
    for (final category in group.categories) {
      if (category.id == categoryId) {
        return group.name.isNotEmpty
            ? '${group.name} > $categoryName'
            : categoryName;
      }
    }
  }
  return categoryName;
}
