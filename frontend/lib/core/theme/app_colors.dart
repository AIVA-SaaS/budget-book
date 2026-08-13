import 'package:flutter/material.dart';

import 'package:budget_book/core/theme/bb_colors.dart';

/// Legacy flat palette. Superseded by [BbColors], which defines light/dark
/// pairs and is injected as a `ThemeExtension` — read it via `context.bb`.
///
/// Kept only so that any straggling reference keeps compiling; remove once
/// the hardcoded-color ratchet reaches zero.
@Deprecated('Use BbColors via context.bb — this palette has no dark pair.')
class AppColors {
  AppColors._();

  static const Color primary = BbColors.brandSeed;
  static Color get income => BbColors.light.income.color;
  static Color get expense => BbColors.light.expense.color;
  static Color get budget => BbColors.light.budget.color;
  static Color get savings => BbColors.light.savings.color;
}
