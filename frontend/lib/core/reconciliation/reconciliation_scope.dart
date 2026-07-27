import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// "무엇이 정산 대상인가" 의 FE 단일 정의 — 서버 `ReconciliationScope` 와 1:1.
///
/// 미기록 **목록**은 서버 필터(`reconciled=false`)가 이미 걸러 주지만, "이 날은 전부
/// 정산됐나" 같은 **로컬 판정**은 FE 가 직접 해야 한다. 그 판정에서 잔액 수정을 빼지 않으면
/// 잔액 수정이 있는 날은 나머지를 다 정산해도 완료 표시가 영영 뜨지 않는다.
///
/// 새 판정 지점이 생기면 여기 함수를 쓸 것 — 위젯 안에서 `type == 'ADJUSTMENT'` 를 직접
/// 비교하지 말 것(같은 규칙이 흩어지면 한 곳만 고치는 사고가 난다).
class ReconciliationScope {
  const ReconciliationScope._();

  /// 잔액 수정(ADJUSTMENT)은 통장에 대응하는 사건이 없어 대조 대상이 아니다.
  static bool isReconcilableTransaction(Transaction t) => t.type != 'ADJUSTMENT';

  /// 이체는 전부 대상. 카드 결제(CARD_SETTLEMENT)는 소계에서만 빠지고, 실제 출금이므로
  /// 대조 대상이다 (서버 정의와 동일).
  static bool isReconcilableTransfer(Transfer t) => true;

  /// 대상 항목이 하나라도 있고, 그것들이 전부 정산됐는가.
  ///
  /// 대상이 0건이면 false — "정산할 게 없는 날" 을 완료로 칠하면 사용자가 정산 여부를
  /// 구분할 수 없다.
  static bool allReconciled({
    required Iterable<Transaction> transactions,
    required Iterable<Transfer> transfers,
  }) {
    final tx = transactions.where(isReconcilableTransaction);
    final tf = transfers.where(isReconcilableTransfer);
    if (tx.isEmpty && tf.isEmpty) return false;
    return tx.every((t) => t.isReconciled) && tf.every((t) => t.isReconciled);
  }
}
