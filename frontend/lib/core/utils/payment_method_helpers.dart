import 'package:flutter/material.dart';

import 'package:budget_book/core/theme/bb_colors.dart';
import '../../core/theme/bb_scale.dart';

/// Group labels for payment method types, used in selector sheet section headers.
const paymentMethodGroupLabels = <String, String>{
  'CASH': '현금',
  'BANK': '은행',
  'DEBIT': '체크카드',
  'CREDIT': '신용카드',
};

/// Returns a Korean label for the given payment method type.
String paymentMethodTypeLabel(String type) {
  return switch (type) {
    'CASH' => '현금',
    'DEBIT' => '체크',
    'CREDIT' => '신용',
    'BANK' => '은행',
    _ => type,
  };
}

/// Returns an appropriate [IconData] for the given payment method type.
IconData paymentMethodTypeIcon(String type) {
  return switch (type) {
    'CASH' => Icons.money,
    'DEBIT' => Icons.credit_card,
    'CREDIT' => Icons.credit_score,
    'BANK' => Icons.account_balance,
    _ => Icons.payment,
  };
}

/// Returns a representative [Color] for the given payment method type.
///
/// Delegates to [BbColors] so the color has a dark-mode pair. It used to
/// return raw palette values (`Colors.green` …), which stayed light-mode-only
/// on every screen that called it — and eight screens do.
Color paymentMethodTypeColor(BuildContext context, String type) =>
    context.bb.paymentType(type);

/// Builds a small colored badge [Widget] for the given payment method type.
Widget buildPaymentMethodTypeBadge(BuildContext context, String type) {
  final color = paymentMethodTypeColor(context, type);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      paymentMethodTypeLabel(type),
      style: TextStyle(
        fontSize: context.bbType.caption,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    ),
  );
}
