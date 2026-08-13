import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import 'package:budget_book/core/models/unified_filter_state.dart';

/// 거래 목록 필터 상태의 단일 값 객체 (value object).
///
/// TransactionBloc 의 흩어진 `_currentXxx` 필드들을 하나로 묶어
/// - MonthSyncHandler 같은 외부 consumer 가 **필터 한 필드만** 빠뜨리는 일을 방지
/// - 새 필터 추가 시 이 파일과 LoadTransactions 시그니처 양쪽 수정이 강제됨
///
/// 과거 인시던트(2026-04-15 "월 이동 후 필터 drop") 회귀 방지용 구조적 장치.
///
/// PR-C3: 카테고리/결제수단/포켓을 **복수 선택**할 수 있게 `Set<String>` 필드 추가.
/// 단수 필드(`categoryId` 등)는 거래 폼/상세 등 별도 단수 consumer 를 위해 유지한다.
class TransactionFilter extends Equatable {
  final String? keyword;
  final String? categoryId;
  final Set<String> categoryIds;
  final Set<String> categoryGroupIds;
  final String? paymentMethodId;
  final Set<String> paymentMethodIds;
  final String? pocketId;
  final Set<String> pocketIds;
  final int? amountMin;
  final int? amountMax;
  final String? dateFrom;
  final String? dateTo;

  /// Legacy single-value type filter (deprecated). Prefer [transactionTypes].
  /// Kept for transitional callers; when both are set, [transactionTypes]
  /// wins in [toQueryParams].
  final String? type;

  /// Multi-select transaction types. Values: 'EXPENSE', 'INCOME', 'TRANSFER'.
  /// Phase 22 §3: Transfer 포함 시 FE 는 `/transfers` 와 병합해 LedgerItem 으로 표시한다.
  /// 빈 셋은 "전체" 를 의미한다.
  final Set<String> transactionTypes;
  final String? visibility;

  /// V61 (2026-05-06) — true 면 needs_review=true 거래만 (확인/입력 필요만 보기).
  /// null/false 모두 미적용으로 처리.
  final bool? needsReviewOnly;

  /// V65 (2026-07-27) — 정산 스냅샷 필터.
  /// `false` = 미기록만, `true` = 기록된 것만, `null` = 전체.
  /// 목록이 페이지네이션되므로 미기록 판정을 클라이언트에서 하면 미로드 페이지 항목이
  /// 누락된다 → 서버 필터를 쓴다.
  final bool? reconciled;

  const TransactionFilter({
    this.keyword,
    this.categoryId,
    this.categoryIds = const {},
    this.categoryGroupIds = const {},
    this.paymentMethodId,
    this.paymentMethodIds = const {},
    this.pocketId,
    this.pocketIds = const {},
    this.amountMin,
    this.amountMax,
    this.dateFrom,
    this.dateTo,
    this.type,
    this.transactionTypes = const {},
    this.visibility,
    this.needsReviewOnly,
    this.reconciled,
  });

  /// 비어있는 필터 (기본값).
  static const TransactionFilter empty = TransactionFilter();

  /// 하나라도 필터가 켜져 있는지.
  bool get hasAny =>
      keyword != null ||
      categoryId != null ||
      categoryIds.isNotEmpty ||
      categoryGroupIds.isNotEmpty ||
      paymentMethodId != null ||
      paymentMethodIds.isNotEmpty ||
      pocketId != null ||
      pocketIds.isNotEmpty ||
      amountMin != null ||
      amountMax != null ||
      dateFrom != null ||
      dateTo != null ||
      type != null ||
      transactionTypes.isNotEmpty ||
      visibility != null ||
      needsReviewOnly == true ||
      reconciled != null;

  TransactionFilter copyWith({
    String? keyword,
    String? categoryId,
    Set<String>? categoryIds,
    Set<String>? categoryGroupIds,
    String? paymentMethodId,
    Set<String>? paymentMethodIds,
    String? pocketId,
    Set<String>? pocketIds,
    int? amountMin,
    int? amountMax,
    String? dateFrom,
    String? dateTo,
    String? type,
    Set<String>? transactionTypes,
    String? visibility,
    bool? needsReviewOnly,
    bool? reconciled,
    /// 명시적 기간 필터 해제용. `??` 기반 copyWith 로는 null 을 넣어 지울 수 없으므로
    /// UnifiedFilterState.copyWith 와 같은 clear 플래그 관례를 따른다.
    bool clearDateRange = false,
  }) {
    if (clearDateRange) {
      return TransactionFilter(
        keyword: keyword ?? this.keyword,
        categoryId: categoryId ?? this.categoryId,
        categoryIds: categoryIds ?? this.categoryIds,
        categoryGroupIds: categoryGroupIds ?? this.categoryGroupIds,
        paymentMethodId: paymentMethodId ?? this.paymentMethodId,
        paymentMethodIds: paymentMethodIds ?? this.paymentMethodIds,
        pocketId: pocketId ?? this.pocketId,
        pocketIds: pocketIds ?? this.pocketIds,
        amountMin: amountMin ?? this.amountMin,
        amountMax: amountMax ?? this.amountMax,
        dateFrom: null,
        dateTo: null,
        type: type ?? this.type,
        transactionTypes: transactionTypes ?? this.transactionTypes,
        visibility: visibility ?? this.visibility,
        needsReviewOnly: needsReviewOnly ?? this.needsReviewOnly,
        reconciled: reconciled ?? this.reconciled,
      );
    }
    return TransactionFilter(
      keyword: keyword ?? this.keyword,
      categoryId: categoryId ?? this.categoryId,
      categoryIds: categoryIds ?? this.categoryIds,
      categoryGroupIds: categoryGroupIds ?? this.categoryGroupIds,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      paymentMethodIds: paymentMethodIds ?? this.paymentMethodIds,
      pocketId: pocketId ?? this.pocketId,
      pocketIds: pocketIds ?? this.pocketIds,
      amountMin: amountMin ?? this.amountMin,
      amountMax: amountMax ?? this.amountMax,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      type: type ?? this.type,
      transactionTypes: transactionTypes ?? this.transactionTypes,
      visibility: visibility ?? this.visibility,
      needsReviewOnly: needsReviewOnly ?? this.needsReviewOnly,
      reconciled: reconciled ?? this.reconciled,
    );
  }

  /// URL 내비게이션이 **소유하는** 필터(카테고리/그룹/결제수단/포켓 선택)만 통째로
  /// 덮어쓴다. 인자를 생략하면 해제(wipe) — `copyWith` 의 `??` carry 와 의미가 다르다.
  ///
  /// content 필터(keyword·금액·기간·type·visibility·needsReviewOnly)는 항상 보존되므로,
  /// 새 content 필터를 추가해도 라우터는 수정할 필요가 없다
  /// (라우터가 필드를 나열하다 needsReviewOnly 를 빠뜨렸던 사고 재발 방지).
  TransactionFilter withNavigationFilters({
    String? categoryId,
    String? paymentMethodId,
    Set<String> categoryIds = const {},
    Set<String> categoryGroupIds = const {},
    Set<String> paymentMethodIds = const {},
    Set<String> pocketIds = const {},
  }) {
    return TransactionFilter(
      // nav 소유 필드 — 인자 그대로 (null/빈 값 = 해제)
      categoryId: categoryId,
      paymentMethodId: paymentMethodId,
      categoryIds: categoryIds,
      categoryGroupIds: categoryGroupIds,
      paymentMethodIds: paymentMethodIds,
      pocketIds: pocketIds,
      // content 필드 — 보존
      keyword: keyword,
      pocketId: pocketId,
      amountMin: amountMin,
      amountMax: amountMax,
      dateFrom: dateFrom,
      dateTo: dateTo,
      type: type,
      transactionTypes: transactionTypes,
      visibility: visibility,
      needsReviewOnly: needsReviewOnly,
      reconciled: reconciled,
    );
  }

  @override
  List<Object?> get props => [
        keyword,
        categoryId,
        categoryIds,
        categoryGroupIds,
        paymentMethodId,
        paymentMethodIds,
        pocketId,
        pocketIds,
        amountMin,
        amountMax,
        dateFrom,
        dateTo,
        type,
        transactionTypes,
        visibility,
        needsReviewOnly,
        reconciled,
      ];
}

/// UI 필터 상태(UnifiedFilterState) → 도메인 필터 VO 변환의 **단일** 접근점.
///
/// 거래 목록 페이지가 `_filterState` 의 필드를 직접 나열해 LoadTransactions 를 만들면
/// 새 필터가 추가될 때 화면마다 누락이 생긴다(2026-04-15 인시던트 계열).
/// 페이지는 이 변환기만 호출하고, 새 필터는 여기 한 곳에 매핑을 추가한다.
extension UnifiedFilterStateToTransactionFilter on UnifiedFilterState {
  /// [keywordOverride] — 검색창 텍스트처럼 UI 상태 밖에 있는 키워드를 주입할 때 사용.
  TransactionFilter toTransactionFilter({String? keywordOverride}) {
    final fmt = DateFormat('yyyy-MM-dd');
    return TransactionFilter(
      keyword: keywordOverride ?? keyword,
      categoryIds: categoryIds,
      categoryGroupIds: categoryGroupIds,
      paymentMethodIds: paymentMethodIds,
      pocketIds: pocketIds,
      amountMin: amountMin,
      amountMax: amountMax,
      dateFrom: dateFrom != null ? fmt.format(dateFrom!) : null,
      dateTo: dateTo != null ? fmt.format(dateTo!) : null,
      transactionTypes: transactionTypes,
      visibility: visibility,
      // BE 는 true 일 때만 의미가 있다 (false/null 모두 미적용).
      needsReviewOnly: needsReviewOnly ? true : null,
      // 정산 필터는 UnifiedFilterState 에 없다 — 정산 뷰가 직접 지정한다.
      // (UI 필터바에 노출되면 리스트/달력 모드의 합계 정의가 흔들린다.)
    );
  }
}

/// 필터 VO → 네트워크 queryParams 변환의 단일 접근점.
///
/// DataSource 가 개별 필드를 인라인으로 조립하다가 한 필드를 빠뜨리는 사고
/// (예: 2026-04-20 visibility 필터 BE 미전달, 4회째 재발) 재발 방지를 위한
/// S2 구조적 수정. 신규 필터 추가 시 이 한 곳만 수정하면 FE→BE 전달이 보장된다.
///
/// 주의: 'ALL' visibility 는 BE 기본 동작(공유 + 본인 개인)과 동일하므로
/// queryParams 에 포함하지 않는다 (불필요한 네트워크 바이트 + BE 와일드카드 방지).
///
/// PR-C3: 복수 필드(`categoryIds`, `categoryGroupIds`, `paymentMethodIds`,
/// `pocketIds`)도 함께 직렬화한다. Dio ListFormat.multi 기준으로
/// `?categoryIds=a&categoryIds=b` 형식으로 전달되어 Spring `@RequestParam List<UUID>` 와 호환.
///
/// 2026-08-12 — 'TRANSFER' 는 이제 **서버로 그대로 전송**한다.
///
/// 이전에는 FE 전용 의사-타입이라 전송 직전에 잘라냈다. 그러면 서버는 "타입 필터 없음" 으로
/// 해석해 거래 전체를 세고, FE 가 클라이언트에서 다시 걸렀다 — 판정이 두 곳에 생겨
/// 합계와 행이 다른 집합을 세는 원인이 됐다. 이제 서버가 두 스트림을 모두 판정한다
/// (`LedgerTypeSelection`): TRANSFER 단독이면 거래 0건, 이체는 노출.
extension TransactionFilterQueryParams on TransactionFilter {
  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};

    // Multi-select wins over legacy singular `type`.
    // TRANSFER 포함해 그대로 보낸다 — 서버가 거래/이체 양쪽 판정에 쓴다.
    if (transactionTypes.isNotEmpty) {
      params['transactionTypes'] = transactionTypes.toList();
      // 단수 `type` 은 **거래 타입 1개**일 때만 함께 보낸다(구 BE 호환).
      // TRANSFER 는 거래 타입이 아니므로 여기로 보내면 400 이다.
      final txTypes = transactionTypes
          .where((t) => t == 'EXPENSE' || t == 'INCOME' || t == 'ADJUSTMENT')
          .toList();
      if (transactionTypes.length == 1 && txTypes.length == 1) {
        params['type'] = txTypes.first;
      }
    } else if (type != null) {
      params['type'] = type;
    }

    if (categoryId != null) params['categoryId'] = categoryId;
    if (categoryIds.isNotEmpty) params['categoryIds'] = categoryIds.toList();
    if (categoryGroupIds.isNotEmpty) {
      params['categoryGroupIds'] = categoryGroupIds.toList();
    }
    if (keyword != null && keyword!.isNotEmpty) params['keyword'] = keyword;
    if (paymentMethodId != null) params['paymentMethodId'] = paymentMethodId;
    if (paymentMethodIds.isNotEmpty) {
      params['paymentMethodIds'] = paymentMethodIds.toList();
    }
    if (pocketId != null) params['pocketId'] = pocketId;
    if (pocketIds.isNotEmpty) params['pocketIds'] = pocketIds.toList();
    if (amountMin != null) params['amountMin'] = amountMin;
    if (amountMax != null) params['amountMax'] = amountMax;
    if (dateFrom != null) params['dateFrom'] = dateFrom;
    if (dateTo != null) params['dateTo'] = dateTo;
    if (visibility != null && visibility != 'ALL') {
      params['visibility'] = visibility;
    }
    // V61 (2026-05-06) — true 일 때만 전송 (false/null 모두 미적용).
    if (needsReviewOnly == true) {
      params['needsReviewOnly'] = true;
    }
    // V65 — false 도 의미가 있다("미기록만"). null 일 때만 생략.
    if (reconciled != null) {
      params['reconciled'] = reconciled;
    }
    return params;
  }

  /// Does this filter want transfers included in the merged ledger view?
  /// True when the multi-select explicitly contains 'TRANSFER', OR when no
  /// type filter is set (which means "all", implicitly including transfers).
  bool get includeTransfers =>
      transactionTypes.isEmpty || transactionTypes.contains('TRANSFER');

  /// True when the multi-select contains *any* transaction-type filter that
  /// excludes transfers. Used to gate display in the merged list.
  bool get transactionOnly =>
      transactionTypes.isNotEmpty && !transactionTypes.contains('TRANSFER');
}
