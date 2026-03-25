import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// 금액 관련 공통 유틸리티.
/// 쉼표 포맷팅, 한글 단위(만/억) 변환을 제공한다.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _numberFormat = NumberFormat('#,###');

  /// 숫자를 쉼표 포맷 문자열로 변환 (예: 1234567 → "1,234,567")
  static String format(num amount) {
    return _numberFormat.format(amount);
  }

  /// 부호 포함 쉼표 포맷 (예: 150000 → "+150,000원", -50000 → "-50,000원", 0 → "0원")
  static String formatWithSign(int amount) {
    if (amount == 0) return '0원';
    final prefix = amount > 0 ? '+' : '';
    return '$prefix${_numberFormat.format(amount)}원';
  }

  /// 쉼표 포맷 문자열에서 숫자 추출 (예: "1,234,567" → 1234567)
  static int? parse(String text) {
    final digits = text.replaceAll(',', '');
    return int.tryParse(digits);
  }

  /// 한글 단위 변환 (예: 200000 → "20만원", 150000000 → "1억 5,000만원")
  static String toKoreanUnit(int amount) {
    if (amount == 0) return '0원';

    final isNegative = amount < 0;
    final abs = amount.abs();

    if (abs < 10000) {
      return '${isNegative ? '-' : ''}${_numberFormat.format(abs)}원';
    }

    final eok = abs ~/ 100000000; // 억
    final man = (abs % 100000000) ~/ 10000; // 만
    final remainder = abs % 10000;

    final parts = <String>[];
    if (eok > 0) parts.add('${_numberFormat.format(eok)}억');
    if (man > 0) parts.add('${_numberFormat.format(man)}만');
    if (remainder > 0) parts.add(_numberFormat.format(remainder));

    return '${isNegative ? '-' : ''}${parts.join(' ')}원';
  }
}

/// 금액 입력 시 실시간 쉼표 포맷팅을 적용하는 TextInputFormatter.
/// 숫자만 허용하며 입력 중 자동으로 쉼표를 삽입한다.
class CurrencyInputFormatter extends TextInputFormatter {
  static final _numberFormat = NumberFormat('#,###');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 빈 값 허용
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // 숫자만 추출
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(digits);
    if (number == null) return oldValue;

    final formatted = _numberFormat.format(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
