// 장부(거래 + 이체 병합 뷰)의 표시용 게이팅.
//
// ## 이력 — 판정이 두 곳이었다는 것이 문제였다
//
// 거래 목록은 `TransactionBloc`(거래) 과 이체 목록을 FE 에서 병합한다.
// 2026-08-10 회차에서 **이체 축 판정을 이 파일로 모아** 인라인 나열을 없앴다
// (needsReviewOnly/카테고리/포켓/금액 누락, 결제수단 `.first` 1개만 적용).
//
// 그런데 BE 합계는 여전히 **다른 규칙**을 썼다 — "필터가 하나라도 켜지면 이체를 전량
// 제외"(`totalTransfer = 0`). 그래서 같은 화면에서 합계와 행이 다른 집합을 셌고,
// 기간 필터가 월을 넘으면 이체 행이 통째로 빠졌다(측정: 범위 내 이체 금액 77% 누락).
//
// ## 2026-08-12 — 이체 판정은 **서버**로 옮겼다
//
// 이체 목록 API 와 합계 API 가 같은 `TransferGating`(BE) 을 쓴다. 목록 쿼리와 집계가
// 같은 함수를 타므로 한쪽만 어긋날 수 없다. FE 는 받은 이체를 **그대로 표시**한다.
//
// 이 파일에 이체 축 판정을 다시 넣지 마라 — 그러면 판정이 또 두 곳이 되고,
// `ledger_gating_test.dart` 의 가드가 실패한다.
//
// 관련 메모리: reference_transaction_merged_transfer_stream_drift,
//              feedback_filter_vo_single_source, reference_month_move_filter_drop
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// `UnifiedFilterState` 의 축(=필드) 개수.
///
/// 필터 VO 에 필드를 추가/삭제하면 `ledger_gating_test.dart` 가 실패한다.
/// 그때 확인할 것은 **서버**다:
///   1. `CommonFilterParams` 에 그 축이 있는가
///   2. `LedgerFilterAxis` 에 항목을 추가했는가 (BE 리플렉션 가드가 강제)
///   3. `TransferGating` 이 그 축을 어떻게 다루는지 선언했는가 (exhaustive when 이 강제)
/// 그런 다음 이 값을 갱신하라.
const int kUnifiedFilterAxisCount = 16;

/// 실효 검색어 결정 규칙 — FE 표시와 BE 전송이 **같은 규칙**을 쓰도록 한 곳에 둔다.
///
/// `toTransactionFilter(keywordOverride:)` 는 override 가 null 이면 VO 의 keyword 로
/// 되돌아간다. 화면이 빈 검색창(`''`)을 넘길 때 FE 만 "검색어 없음"으로 판단하면
/// 서버가 좁힌 목록과 화면 표시가 어긋난다.
String resolveLedgerKeyword(UnifiedFilterState filter, String? override) {
  final o = override?.trim() ?? '';
  if (o.isNotEmpty) return o;
  return filter.keyword?.trim() ?? '';
}

/// 게이팅 결과. 목록/달력/합계/러닝밸런스가 **이 두 리스트만** 소비한다.
class GatedLedger {
  final List<Transaction> transactions;
  final List<Transfer> transfers;

  const GatedLedger({required this.transactions, required this.transfers});
}

/// 서버가 좁힌 두 스트림을 표시용으로 정리한다.
///
/// - [transactions] 는 BE 가 이미 필터·타입까지 좁힌 결과다. 여기서 타입 게이팅을
///   한 번 더 하는 이유는 **응답 대기 중 옛 목록이 잠깐 보이는 것**을 막기 위한
///   과도기 방어뿐이다(서버 판정과 같은 규칙이므로 결과를 바꾸지 않는다).
/// - [transfers] 는 서버가 이미 축 전수를 판정했다 → **손대지 않는다**.
GatedLedger gateLedger({
  required List<Transaction> transactions,
  required List<Transfer> transfers,
  required UnifiedFilterState filter,
  String? keyword,
}) {
  final types = filter.transactionTypes;

  // 거래: 타입 표시 게이팅. TRANSFER 는 거래 타입이 아니므로 TRANSFER 단독 선택은
  // 거래 0건이 된다(서버도 같은 판정을 한다 — `LedgerTypeSelection`).
  final gatedTransactions = types.isEmpty
      ? transactions
      : transactions.where((t) => types.contains(t.type)).toList();

  return GatedLedger(
    transactions: gatedTransactions,
    transfers: transfers,
  );
}
