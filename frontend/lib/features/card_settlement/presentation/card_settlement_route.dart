import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// 카드 정산(Transfer kind=CARD_SETTLEMENT) 편집 진입 라우트를 조립한다.
///
/// 일반 이체 폼(`/transfers/edit/:id`)에서는 정산 수정 시 미결제 금액이
/// 재계산되지 않으므로, 정산은 전용 편집 플로우(`/card-settlement`)로 보낸다.
///
/// - card = destination(CREDIT), bank = source(BANK)
/// - year/month 는 정산 거래 날짜의 달 (해당 월 후보 + 기존 링크 거래 조회)
String cardSettlementEditRoute(Transfer transfer) {
  final cardId = transfer.destinationPaymentMethod.id;
  final bankId = transfer.sourcePaymentMethod.id;
  final date = transfer.transferDate; // yyyy-MM-dd
  // transferDate 의 연/월을 후보 조회 기준으로 사용.
  int? year;
  int? month;
  final parsed = DateTime.tryParse(date);
  if (parsed != null) {
    year = parsed.year;
    month = parsed.month;
  }
  final params = <String, String>{
    'settlementTransferId': transfer.id,
    'cardId': cardId,
    'bankId': bankId,
    'amount': transfer.amount.toString(),
    'date': date,
    if (year != null) 'year': year.toString(),
    if (month != null) 'month': month.toString(),
  };
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  return '/card-settlement?$query';
}

/// 일반 이체 편집과 정산 편집을 분기하는 라우트 헬퍼.
/// 정산이면 전용 편집 플로우, 아니면 기존 이체 폼.
String transferEditRoute(Transfer transfer) {
  if (transfer.isCardSettlement) {
    return cardSettlementEditRoute(transfer);
  }
  return '/transfers/edit/${transfer.id}';
}
