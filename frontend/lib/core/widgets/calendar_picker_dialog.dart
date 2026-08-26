import 'package:flutter/material.dart';
import '../../core/theme/bb_scale.dart';

/// Shows a compact calendar-only date picker dialog without the Material3 header panel.
Future<DateTime?> showCalendarPickerDialog({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      DateTime selected = initialDate;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    Text(
                      '날짜 선택',
                      style: TextStyle(
                          fontSize: context.bbType.title, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: context.bbType.iconMd),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              CalendarDatePicker(
                initialDate: initialDate,
                firstDate: firstDate ?? DateTime(2020),
                lastDate: lastDate ?? DateTime(2030, 12, 31),
                onDateChanged: (d) => selected = d,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, selected),
                    child: const Text('선택'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
