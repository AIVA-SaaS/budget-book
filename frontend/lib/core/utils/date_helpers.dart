import 'package:intl/intl.dart';

/// Week range within a month (start/end clipped to month boundaries).
class WeekRange {
  final DateTime start;
  final DateTime end;
  final int weekNumber; // 1-based

  const WeekRange({
    required this.start,
    required this.end,
    required this.weekNumber,
  });

  int get days => end.difference(start).inDays + 1;
}

class DateHelper {
  DateHelper._();

  /// 거래 목록 날짜 헤더: "3월 20일 (목)"
  static String formatDateHeader(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('M월 d일 (E)', 'ko').format(date);
  }

  /// 거래 상세 날짜: "2026년 3월 20일 (목)"
  static String formatDateFull(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date);
  }

  /// 시간 포함: "2026-03-20 14:30"
  static String formatDateTime(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  /// 짧은 형식 "M/d" — 필터/차트/주간 리스트용.
  /// 이전엔 각 파일마다 `DateFormat('M/d')` 를 로컬 인스턴스로 썼음. 중앙화.
  static String formatDateShort(DateTime date) {
    return DateFormat('M/d').format(date);
  }

  /// 짧은 형식 문자열 입력 지원 (yyyy-MM-dd → M/d).
  static String formatDateShortFromStr(String dateStr) {
    return formatDateShort(DateTime.parse(dateStr));
  }

  /// 내부 저장/API 포맷 "yyyy-MM-dd".
  static String formatIso(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  /// Calculate Monday-Sunday week ranges for a given month,
  /// clipped to month boundaries. Mirrors BE WeeklyBudgetService.calculateWeekRanges.
  static List<WeekRange> calculateWeekRanges(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final ranges = <WeekRange>[];

    // Find Monday on or before firstDay
    var weekStart = firstDay.subtract(Duration(days: (firstDay.weekday - DateTime.monday) % 7));
    if (weekStart.isAfter(firstDay)) {
      weekStart = weekStart.subtract(const Duration(days: 7));
    }

    var weekNumber = 1;
    while (!weekStart.isAfter(lastDay)) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final effectiveStart = weekStart.isBefore(firstDay) ? firstDay : weekStart;
      final effectiveEnd = weekEnd.isAfter(lastDay) ? lastDay : weekEnd;
      ranges.add(WeekRange(
        start: effectiveStart,
        end: effectiveEnd,
        weekNumber: weekNumber,
      ));
      weekNumber++;
      weekStart = weekStart.add(const Duration(days: 7));
    }

    return ranges;
  }

  /// Pro-rata budget for a week range: weeklyAmount * days / 7.
  /// Mirrors BE WeeklyBudgetService.calculateProRataBudget.
  static int calculateProRataBudget(int weeklyAmount, WeekRange week) {
    return (weeklyAmount * week.days) ~/ 7;
  }

  /// Check if a date falls within a week range.
  static bool isDateInWeekRange(DateTime date, WeekRange week) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return !dateOnly.isBefore(week.start) && !dateOnly.isAfter(week.end);
  }
}
