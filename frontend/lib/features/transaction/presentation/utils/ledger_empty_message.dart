// 장부(거래 탭) 빈 상태 문구의 **단일 생성기**.
//
// 배경 (2026-08-10): 결과가 0건일 때 필터와 무관하게 항상 "거래 내역이 없습니다" 만
// 떠서, 사용자가 "왜 비었는지"(= 어떤 필터 때문인지) 알 수 없었다.
// 선택한 조건에 맞는 문구를 돌려주고, 필터가 걸려 있으면 액션 버튼을
// `거래 추가` 대신 `필터 초기화` 로 바꾼다.
//
// 순수 함수로 유지한다(getIt/BuildContext 의존 없음) — 카테고리명 같은 **값 라벨**은
// 상단 필터 칩이 이미 보여주므로 문구에는 축 이름만 쓴다.
import 'package:budget_book/core/models/unified_filter_state.dart';

class LedgerEmptyMessage {
  final String title;
  final String? subtitle;

  /// 필터/검색어가 하나라도 활성인가. true 면 액션은 `필터 초기화`.
  final bool hasFilters;

  const LedgerEmptyMessage({
    required this.title,
    this.subtitle,
    required this.hasFilters,
  });
}

/// 활성 축 하나를 문구 재료로 표현한 것.
class _Axis {
  /// 이 축이 단독일 때(또는 최우선일 때) 쓰는 제목.
  final String title;

  /// `적용된 필터: …` 요약에 들어가는 짧은 이름.
  final String chip;

  const _Axis(this.title, this.chip);
}

/// 필터 상태 → 빈 상태 문구.
///
/// [keyword] 는 검색창처럼 VO 밖의 키워드 주입용(`gateLedger` 와 같은 관례).
///
/// 제목은 **우선순위 최상위 축 1개**로 정하고, 축이 2개 이상이면 부제에
/// `적용된 필터: A · B` 를 붙인다.
LedgerEmptyMessage buildLedgerEmptyMessage(
  UnifiedFilterState filter, {
  String? keyword,
}) {
  final kw = (keyword ?? filter.keyword)?.trim() ?? '';
  final axes = _activeAxes(filter, kw);

  if (axes.isEmpty) {
    return const LedgerEmptyMessage(
      title: '거래 내역이 없습니다',
      subtitle: '이 달에 기록된 거래가 없습니다',
      hasFilters: false,
    );
  }

  final subtitle = axes.length == 1
      ? '필터를 해제하면 이 달의 다른 내역을 볼 수 있습니다'
      : '적용된 필터: ${axes.map((a) => a.chip).join(' · ')}';

  return LedgerEmptyMessage(
    title: axes.first.title,
    subtitle: subtitle,
    hasFilters: true,
  );
}

/// 활성 축을 **우선순위 순서**로 수집한다.
/// 순서 = 제목 선정 순서 = `적용된 필터:` 나열 순서.
///
/// 축을 추가할 때는 `UnifiedFilterState` 의 새 필드를 여기에도 반영한다
/// (`ledger_empty_message_test.dart` 의 필드 수 가드가 이를 강제한다).
List<_Axis> _activeAxes(UnifiedFilterState f, String keyword) {
  final axes = <_Axis>[];

  if (f.needsReviewOnly) {
    axes.add(const _Axis('확인/입력 필요한 거래가 없습니다', '확인 필요'));
  }
  if (f.transactionTypes.isNotEmpty) {
    final label = _typeLabel(f.transactionTypes);
    axes.add(_Axis('$label 내역이 없습니다', label));
  }
  if (f.visibility == 'PRIVATE') {
    axes.add(const _Axis('개인 거래가 없습니다', '개인'));
  } else if (f.visibility == 'SHARED') {
    axes.add(const _Axis('공유 거래가 없습니다', '공유'));
  }
  if (keyword.isNotEmpty) {
    axes.add(_Axis("'$keyword' 검색 결과가 없습니다", "검색어 '$keyword'"));
  }
  if (f.categoryIds.isNotEmpty || f.categoryGroupIds.isNotEmpty) {
    axes.add(const _Axis('선택한 카테고리의 거래가 없습니다', '카테고리'));
  }
  if (f.paymentMethodIds.isNotEmpty) {
    axes.add(const _Axis('선택한 결제수단의 거래가 없습니다', '결제수단'));
  }
  if (f.pocketIds.isNotEmpty) {
    axes.add(const _Axis('선택한 포켓의 거래가 없습니다', '포켓'));
  }
  if (f.amountMin != null || f.amountMax != null) {
    axes.add(const _Axis('해당 금액대의 거래가 없습니다', '금액'));
  }
  if (f.hasDateRange) {
    axes.add(const _Axis('선택한 기간에 거래가 없습니다', '기간'));
  }

  // 게이팅과 무관한 축(표시 전용): dateRangeLabel / categoryName /
  // paymentMethodName. 장부 필터바 미노출 축: status.
  return axes;
}

/// {EXPENSE, TRANSFER} → '지출/이체'. Set 순서에 의존하지 않도록 고정 순서로 정렬.
String _typeLabel(Set<String> types) {
  const order = ['EXPENSE', 'INCOME', 'TRANSFER'];
  final ordered = [
    ...order.where(types.contains),
    ...types.where((t) => !order.contains(t)),
  ];
  return ordered.map((t) => kTransactionTypeLabels[t] ?? t).join('/');
}
