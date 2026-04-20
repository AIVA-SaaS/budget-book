import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/utils/date_helpers.dart';

void main() {
  group('DateHelper.formatDateShort', () {
    test('formats month/day without year', () {
      expect(DateHelper.formatDateShort(DateTime(2026, 3, 5)), '3/5');
      expect(DateHelper.formatDateShort(DateTime(2026, 12, 31)), '12/31');
    });

    test('formatDateShortFromStr parses ISO string', () {
      expect(DateHelper.formatDateShortFromStr('2026-04-20'), '4/20');
    });

    test('formatIso returns yyyy-MM-dd', () {
      expect(DateHelper.formatIso(DateTime(2026, 4, 5)), '2026-04-05');
    });
  });
}
