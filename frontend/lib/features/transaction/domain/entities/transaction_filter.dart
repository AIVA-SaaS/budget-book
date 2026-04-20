import 'package:equatable/equatable.dart';

/// 거래 목록 필터 상태의 단일 값 객체 (value object).
///
/// TransactionBloc 의 흩어진 `_currentXxx` 필드들을 하나로 묶어
/// - MonthSyncHandler 같은 외부 consumer 가 **필터 한 필드만** 빠뜨리는 일을 방지
/// - 새 필터 추가 시 이 파일과 LoadTransactions 시그니처 양쪽 수정이 강제됨
///
/// 과거 인시던트(2026-04-15 "월 이동 후 필터 drop") 회귀 방지용 구조적 장치.
class TransactionFilter extends Equatable {
  final String? keyword;
  final String? categoryId;
  final String? paymentMethodId;
  final String? pocketId;
  final int? amountMin;
  final int? amountMax;
  final String? dateFrom;
  final String? dateTo;
  final String? type;
  final String? visibility;

  const TransactionFilter({
    this.keyword,
    this.categoryId,
    this.paymentMethodId,
    this.pocketId,
    this.amountMin,
    this.amountMax,
    this.dateFrom,
    this.dateTo,
    this.type,
    this.visibility,
  });

  /// 비어있는 필터 (기본값).
  static const TransactionFilter empty = TransactionFilter();

  /// 하나라도 필터가 켜져 있는지.
  bool get hasAny =>
      keyword != null ||
      categoryId != null ||
      paymentMethodId != null ||
      pocketId != null ||
      amountMin != null ||
      amountMax != null ||
      dateFrom != null ||
      dateTo != null ||
      type != null ||
      visibility != null;

  TransactionFilter copyWith({
    String? keyword,
    String? categoryId,
    String? paymentMethodId,
    String? pocketId,
    int? amountMin,
    int? amountMax,
    String? dateFrom,
    String? dateTo,
    String? type,
    String? visibility,
  }) {
    return TransactionFilter(
      keyword: keyword ?? this.keyword,
      categoryId: categoryId ?? this.categoryId,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      pocketId: pocketId ?? this.pocketId,
      amountMin: amountMin ?? this.amountMin,
      amountMax: amountMax ?? this.amountMax,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      type: type ?? this.type,
      visibility: visibility ?? this.visibility,
    );
  }

  @override
  List<Object?> get props => [
        keyword,
        categoryId,
        paymentMethodId,
        pocketId,
        amountMin,
        amountMax,
        dateFrom,
        dateTo,
        type,
        visibility,
      ];
}

/// 필터 VO → 네트워크 queryParams 변환의 단일 접근점.
///
/// DataSource 가 개별 필드를 인라인으로 조립하다가 한 필드를 빠뜨리는 사고
/// (예: 2026-04-20 visibility 필터 BE 미전달, 4회째 재발) 재발 방지를 위한
/// S2 구조적 수정. 신규 필터 추가 시 이 한 곳만 수정하면 FE→BE 전달이 보장된다.
///
/// 주의: 'ALL' visibility 는 BE 기본 동작(공유 + 본인 개인)과 동일하므로
/// queryParams 에 포함하지 않는다 (불필요한 네트워크 바이트 + BE 와일드카드 방지).
extension TransactionFilterQueryParams on TransactionFilter {
  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type;
    if (categoryId != null) params['categoryId'] = categoryId;
    if (keyword != null && keyword!.isNotEmpty) params['keyword'] = keyword;
    if (paymentMethodId != null) params['paymentMethodId'] = paymentMethodId;
    if (pocketId != null) params['pocketId'] = pocketId;
    if (amountMin != null) params['amountMin'] = amountMin;
    if (amountMax != null) params['amountMax'] = amountMax;
    if (dateFrom != null) params['dateFrom'] = dateFrom;
    if (dateTo != null) params['dateTo'] = dateTo;
    if (visibility != null && visibility != 'ALL') {
      params['visibility'] = visibility;
    }
    return params;
  }
}
