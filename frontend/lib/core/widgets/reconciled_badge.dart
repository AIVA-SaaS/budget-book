import 'package:flutter/material.dart';
import '../../core/theme/bb_scale.dart';

/// 정산 완료 배지 — **모든 노출 지점의 단일 소스**.
///
/// 거래 타일 / 이체 타일 / 거래 상세 / 이체 상세 / 달력 셀 5곳에서 같은 위젯을 쓴다.
/// 과거 "한 곳만 수정하고 나머지를 빠뜨리는" 사고를 막기 위해 아이콘·색·툴팁을 여기서만
/// 정의한다. 새 노출 지점이 생기면 이 위젯을 가져다 쓸 것 (직접 Icon 을 그리지 말 것).
class ReconciledBadge extends StatelessWidget {
  /// 정산 회차 (`N차`). null 이면 회차 없이 체크만 표시.
  final int? seq;

  /// 정산 후 원본 금액/날짜가 변경됨 → 경고 색 + 문구.
  final bool changed;

  /// 축약 모드 (달력 셀처럼 공간이 없는 곳). 점 하나만 그린다.
  final bool compact;

  const ReconciledBadge({
    super.key,
    this.seq,
    this.changed = false,
    this.compact = false,
  });

  static const Color _okColor = Color(0xFF2E7D32); // green.shade800
  static const Color _changedColor = Color(0xFFE65100); // orange.shade900

  @override
  Widget build(BuildContext context) {
    final color = changed ? _changedColor : _okColor;
    final tooltip = changed
        ? '정산 후 수정됨${seq != null ? ' · $seq차 정산' : ''}'
        : '정산 완료${seq != null ? ' · $seq차' : ''}';

    if (compact) {
      return Tooltip(
        message: tooltip,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              changed ? Icons.error_outline : Icons.check_circle,
              size: context.bbType.iconSm,
              color: color,
            ),
            const SizedBox(width: 2),
            Text(
              // 2026-07-28 — 회차가 없어도 **텍스트를 항상 붙인다**.
              // 아이콘 글리프가 뜨지 않는 기기가 있어(정산 뷰 토글 사례) 아이콘만으로는
              // 배지 존재 자체가 보이지 않을 수 있다.
              seq != null ? '$seq차' : '정산',
              style: TextStyle(
                fontSize: context.bbType.caption,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
