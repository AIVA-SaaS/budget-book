import 'package:flutter/material.dart';

/// Shows a standard delete confirmation dialog.
/// Returns true if user confirmed, false otherwise.
Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  required String title,
  String? itemName,
  String? description,
}) async {
  final content = description ??
      (itemName != null
          ? "'$itemName'을(를) 삭제하시겠습니까?"
          : '정말 삭제하시겠습니까?');

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  return result ?? false;
}
