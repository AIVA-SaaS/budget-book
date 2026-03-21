import 'package:flutter/material.dart';

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
Color paymentMethodTypeColor(String type) {
  return switch (type) {
    'CASH' => Colors.green,
    'DEBIT' => Colors.blue,
    'CREDIT' => Colors.deepPurple,
    'BANK' => Colors.teal,
    _ => Colors.grey,
  };
}

/// Builds a small colored badge [Widget] for the given payment method type.
Widget buildPaymentMethodTypeBadge(BuildContext context, String type) {
  final color = paymentMethodTypeColor(type);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      paymentMethodTypeLabel(type),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    ),
  );
}
