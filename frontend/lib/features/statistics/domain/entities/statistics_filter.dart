import 'package:equatable/equatable.dart';

/// 통계 화면 필터 상태의 단일 value object.
///
/// TransactionFilter 와 동일한 설계 철학:
/// - 흩어진 필터 필드들을 하나로 묶어 **drop 방지**
/// - 신규 필터 추가 시 여기와 `LoadAllStatistics` / `StatisticsState` / `currentFilter`
///   getter 를 **동시 수정** 하지 않으면 round-trip 테스트 실패 → PR CI 차단
/// - MonthSyncHandler 등 외부 consumer 가 "필드 한 개만 꺼내 전달" 하는 패턴 금지
class StatisticsFilter extends Equatable {
  /// 'EXPENSE' / 'INCOME' — 카테고리 분포 조회 시 사용.
  final String categoryType;

  /// 'ALL' / 'SHARED' / 'PRIVATE' — 가시성 필터.
  final String visibilityFilter;

  /// 커스텀 날짜 범위 from (ISO yyyy-MM-dd). null 이면 year/month 기준.
  final String? dateFrom;

  /// 커스텀 날짜 범위 to.
  final String? dateTo;

  /// 날짜 범위 라벨 (예: "3/5~3/20"). UI 표시용.
  final String? dateRangeLabel;

  const StatisticsFilter({
    this.categoryType = 'EXPENSE',
    this.visibilityFilter = 'ALL',
    this.dateFrom,
    this.dateTo,
    this.dateRangeLabel,
  });

  static const StatisticsFilter initial = StatisticsFilter();

  /// 커스텀 날짜 범위 활성 여부.
  bool get hasDateRange => dateFrom != null && dateTo != null;

  /// 하나라도 비기본값이면 필터 적용 중.
  bool get hasAny =>
      categoryType != 'EXPENSE' ||
      visibilityFilter != 'ALL' ||
      hasDateRange;

  StatisticsFilter copyWith({
    String? categoryType,
    String? visibilityFilter,
    String? dateFrom,
    String? dateTo,
    String? dateRangeLabel,
    bool clearDateRange = false,
  }) {
    return StatisticsFilter(
      categoryType: categoryType ?? this.categoryType,
      visibilityFilter: visibilityFilter ?? this.visibilityFilter,
      dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
      dateRangeLabel:
          clearDateRange ? null : (dateRangeLabel ?? this.dateRangeLabel),
    );
  }

  @override
  List<Object?> get props =>
      [categoryType, visibilityFilter, dateFrom, dateTo, dateRangeLabel];
}
