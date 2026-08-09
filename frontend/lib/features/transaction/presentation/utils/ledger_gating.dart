// 장부(거래 + 이체 병합 뷰)의 **단일 게이팅 진입점**.
//
// 배경 (2026-08-10, 4회째 재발):
//   거래 목록은 `TransactionBloc`(거래) 과 `TransferBloc`(이체) 를 FE 에서 병합한다.
//   거래 쪽 필터는 `UnifiedFilterState.toTransactionFilter()` 라는 VO 단일 변환기로
//   BE 까지 관통하지만, **이체 쪽 게이팅은 페이지 안에 인라인으로 필드를 나열**하고
//   있었다. 그래서 새 필터가 추가될 때마다 이체 스트림에서만 축이 누락됐다:
//     - `needsReviewOnly`(확인/입력 필요만) 켜도 이체가 그대로 노출
//     - 카테고리/포켓 필터를 걸어도 이체가 그대로 노출
//     - 금액범위가 이체에 미적용
//     - 결제수단은 복수 선택인데 `paymentMethodIds.first` 1개만 적용
//
// 구조적 수정:
//   1) 이 파일이 **유일한** 게이팅 지점이다. 페이지는 `gateLedger()` 결과만 소비하고
//      (목록/달력/합계바/러닝밸런스가 같은 리스트를 본다) 이체를 직접 거르지 않는다.
//   2) `UnifiedFilterState` 의 **모든 축**을 아래 `_transferMatches` 에서 명시적으로
//      분류한다 — "이체에 적용 / 이체에 없는 축이라 전량 제외 / 게이팅과 무관".
//   3) `kUnifiedFilterAxisCount` 가드: 필터 VO 에 필드가 추가되면 테스트가 실패해
//      이 파일을 갱신하지 않고는 CI 를 통과할 수 없다.
//
// 관련 메모리: reference_transaction_merged_transfer_stream_drift,
//              feedback_filter_vo_single_source, reference_month_move_filter_drop
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// `UnifiedFilterState` 의 축(=필드) 개수.
///
/// 필터 VO 에 필드를 추가/삭제하면 `ledger_gating_test.dart` 가 실패한다.
/// **먼저** 아래 `_transferMatches` 에 그 축의 이체 판정을 명시한 뒤 이 값을 갱신하라.
/// (새 필터가 이체 스트림에서만 조용히 누락되던 사고의 구조적 봉인)
const int kUnifiedFilterAxisCount = 16;

/// 게이팅 결과. 목록/달력/합계/러닝밸런스가 **이 두 리스트만** 소비한다.
class GatedLedger {
  final List<Transaction> transactions;
  final List<Transfer> transfers;

  const GatedLedger({required this.transactions, required this.transfers});
}

/// 필터 상태를 거래·이체 두 스트림에 **동일한 기준**으로 적용한다.
///
/// - [transactions] 는 BE 가 이미 좁힌 결과다. 여기서는 BE 가 알지 못하는
///   FE 전용 pseudo-type(`TRANSFER`) 때문에 타입 게이팅만 추가로 건다.
/// - [transfers] 는 월 단위 원본이므로 모든 축을 FE 에서 판정한다.
/// - [keyword] 는 검색창처럼 VO 밖에 있는 키워드 주입용
///   (`toTransactionFilter(keywordOverride:)` 와 같은 관례).
GatedLedger gateLedger({
  required List<Transaction> transactions,
  required List<Transfer> transfers,
  required UnifiedFilterState filter,
  String? keyword,
}) {
  final types = filter.transactionTypes;

  // 거래: 클라 타입 게이팅. TRANSFER 는 거래 타입이 아니므로 TRANSFER 단독 선택은
  // 거래 0건이 된다(BE 에는 TRANSFER 가 전달되지 않아 서버가 좁히지 못한다).
  final gatedTransactions = types.isEmpty
      ? transactions
      : transactions.where((t) => types.contains(t.type)).toList();

  // 이체: 축 전수 판정.
  final effectiveKeyword =
      (keyword ?? filter.keyword)?.trim().toLowerCase() ?? '';
  final gatedTransfers = _transfersExcludedWholesale(filter)
      ? const <Transfer>[]
      : transfers
          .where((t) => _transferMatches(t, filter, effectiveKeyword))
          .toList();

  return GatedLedger(
    transactions: gatedTransactions,
    transfers: gatedTransfers,
  );
}

/// 이체 엔티티에 **존재하지 않는 축**이 활성이면 이체는 논리적으로 매칭 불가 →
/// 전량 제외한다. (필터를 무시하고 노출하던 것이 버그였다)
///
/// `Transfer` 에는 `needsReview` / category / pocket 필드가 없다
/// (`features/transfer/domain/entities/transfer.dart`).
bool _transfersExcludedWholesale(UnifiedFilterState f) {
  // 축: needsReviewOnly — 이체엔 "확인/입력 필요" 개념이 없다.
  if (f.needsReviewOnly) return true;
  // 축: categoryIds / categoryGroupIds — 이체엔 카테고리가 없다.
  if (f.categoryIds.isNotEmpty || f.categoryGroupIds.isNotEmpty) return true;
  // 축: pocketIds — 이체엔 포켓이 없다(포켓 이체는 별도 기능).
  if (f.pocketIds.isNotEmpty) return true;
  // 축: visibility — 이체엔 visibility 가 없어 현재 전부 "공유" 취급.
  //     개인(PRIVATE) 필터에서는 숨긴다. 개인 자산(ASSET-PRIVATE) 도입 시
  //     source/dest 자산의 visibility 로 파생하도록 여기를 고친다.
  if (f.visibility == 'PRIVATE') return true;
  // 축: transactionTypes — TRANSFER 미포함 선택이면 이체 제외(빈 셋 = 전체).
  if (f.transactionTypes.isNotEmpty &&
      !f.transactionTypes.contains('TRANSFER')) {
    return true;
  }
  return false;
}

/// 이체에 **실제로 적용 가능한 축**의 행 단위 판정.
///
/// 나머지 축의 처리는 아래 주석이 전부다 — 축을 추가하면 반드시 여기(또는
/// [_transfersExcludedWholesale])에 분류를 남긴다.
///   - dateRangeLabel / categoryName / paymentMethodName: 표시 전용 라벨, 게이팅 무관
///   - status: 장부 필터바에 노출되지 않는 축(지출계획 등 타 화면 전용), 게이팅 무관
bool _transferMatches(
  Transfer t,
  UnifiedFilterState f,
  String keywordLower,
) {
  // 축: dateFrom / dateTo — transferDate 는 'yyyy-MM-dd' 문자열이라 사전식 비교가 안전.
  if (f.dateFrom != null && t.transferDate.compareTo(_ymd(f.dateFrom!)) < 0) {
    return false;
  }
  if (f.dateTo != null && t.transferDate.compareTo(_ymd(f.dateTo!)) > 0) {
    return false;
  }

  // 축: paymentMethodIds — **복수 선택 전체**를 OR 매칭 (출금/입금 어느 쪽이든).
  //     기존에는 `.first` 만 봐서 2개 이상 선택 시 나머지가 무시됐다.
  if (f.paymentMethodIds.isNotEmpty) {
    final hit = f.paymentMethodIds.contains(t.sourcePaymentMethod.id) ||
        f.paymentMethodIds.contains(t.destinationPaymentMethod.id);
    if (!hit) return false;
  }

  // 축: amountMin / amountMax — 이체 금액도 금액범위 필터를 따른다.
  if (f.amountMin != null && t.amount < f.amountMin!) return false;
  if (f.amountMax != null && t.amount > f.amountMax!) return false;

  // 축: keyword — 설명 + 출금/입금 결제수단명.
  if (keywordLower.isNotEmpty) {
    final desc = t.description?.toLowerCase() ?? '';
    final src = t.sourcePaymentMethod.name.toLowerCase();
    final dst = t.destinationPaymentMethod.name.toLowerCase();
    if (!desc.contains(keywordLower) &&
        !src.contains(keywordLower) &&
        !dst.contains(keywordLower)) {
      return false;
    }
  }

  return true;
}

/// DateTime → 'yyyy-MM-dd' (intl 의존 없이 순수 함수 유지).
String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
