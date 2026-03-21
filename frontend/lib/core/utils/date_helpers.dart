import 'package:intl/intl.dart';

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
}
