import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 장부(거래/이체) 목록의 **날짜 구분 헤더 — 표기 단일 소스**.
///
/// 리스트 모드와 정산 뷰가 같은 날짜 표기를 써야 한다. 각자 `DateFormat` 을 쓰면
/// "리스트는 7월 26일 (일), 정산은 07/26" 처럼 갈라진다. 포맷·배경·여백만 여기서 정의하고,
/// 좌우에 붙는 것(체크박스 / 일별 합계 / 거래 추가 버튼)은 [leading]·[trailing] 슬롯으로 받는다
/// — 두 화면의 요구가 다르므로 위젯을 하나로 합치지 않고 **표기만** 공유한다.
class LedgerDateHeader extends StatelessWidget {
  /// `yyyy-MM-dd`. 파싱 실패 시 문자열 그대로 표시한다.
  final String dateStr;

  /// 날짜 라벨 왼쪽 (정산 뷰의 그룹 체크박스).
  final Widget? leading;

  /// 날짜 라벨 오른쪽 끝 (리스트 모드의 일별 합계·추가 버튼).
  final List<Widget> trailing;

  final VoidCallback? onTap;

  const LedgerDateHeader({
    super.key,
    required this.dateStr,
    this.leading,
    this.trailing = const [],
    this.onTap,
  });

  /// `2026-07-26` → `7월 26일 (일)`. 파싱 실패 시 입력 그대로.
  static String format(String dateStr) {
    try {
      return DateFormat('M월 d일 (E)', 'ko').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: leading != null ? 4 : 16,
        right: 16,
        top: 8,
        bottom: 8,
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          if (leading != null) leading!,
          Text(
            format(dateStr),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          ...trailing,
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
