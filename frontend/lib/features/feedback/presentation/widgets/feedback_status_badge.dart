import 'package:flutter/material.dart';

class FeedbackStatusBadge extends StatelessWidget {
  final String status;

  const FeedbackStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static (String, Color) _statusInfo(String status) {
    return switch (status) {
      'SUBMITTED' => ('접수', Colors.grey),
      'REVIEWING' => ('검토 중', Colors.blue),
      'IN_PROGRESS' => ('개발 중', Colors.orange),
      'RESOLVED' => ('완료', Colors.green),
      'REJECTED' => ('반려', Colors.red),
      _ => (status, Colors.grey),
    };
  }

  /// Returns the Korean label for a given status value.
  static String statusLabel(String status) {
    final (label, _) = _statusInfo(status);
    return label;
  }
}

class FeedbackCategoryChip extends StatelessWidget {
  final String category;

  const FeedbackCategoryChip({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final (label, icon) = _categoryInfo(category);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static (String, String) _categoryInfo(String category) {
    return switch (category) {
      'BUG' => ('버그', '\uD83D\uDC1B'),
      'IMPROVEMENT' => ('개선', '\uD83D\uDCA1'),
      'FEATURE' => ('기능 추가', '\u2728'),
      'OTHER' => ('기타', '\uD83D\uDCAC'),
      _ => (category, '\uD83D\uDCAC'),
    };
  }

  /// Returns the Korean label for a given category value.
  static String categoryLabel(String category) {
    final (label, _) = _categoryInfo(category);
    return label;
  }

  /// Returns the emoji icon for a given category value.
  static String categoryIcon(String category) {
    final (_, icon) = _categoryInfo(category);
    return icon;
  }
}
