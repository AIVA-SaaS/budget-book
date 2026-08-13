import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

/// 합계에서 제외되는 행의 **단일 판정**.
///
/// ## 왜 필요한가 (2026-08-12)
///
/// 두 종류의 행은 목록에 보이지만 상단 합계의 어느 칸에도 들어가지 않는다:
///  - `ADJUSTMENT`(잔액 수정): 통계 범주 밖 — 잔액만 움직인다
///  - `CARD_SETTLEMENT`(카드 정산 이체): 원본 지출 거래로 이미 집계됨 (이중 계산 방지)
///
/// 규칙 자체는 의도된 것이지만, 행에 아무 표시가 없으면 사용자에게는
/// **"합계에서 빠진 행"** 으로 보인다(실측: 잔액 수정 17건 · 카드정산 8건).
/// 그래서 행에 배지를 붙인다.
///
/// 판정을 타일마다 각자 하면 그것이 다음 drift 다 — 두 타일이 이 함수만 쓴다.
/// 집계식 정본은 `LedgerSummary`(FE) 와 `ExpenseCalculator`(BE) 이며,
/// 이 함수는 그 규칙의 "제외" 쪽을 그대로 반영한다.
bool isTransactionExcludedFromTotals(Transaction transaction) =>
    transaction.isAdjustment;

bool isTransferExcludedFromTotals(Transfer transfer) =>
    transfer.kind == TransferKind.cardSettlement;

/// 배지 문구 — 두 종류가 같은 이유로 제외되는 것은 아니라서 사유를 구분한다.
const String kExcludedFromTotalsLabel = '합계 제외';

/// 배지 툴팁 — 왜 제외되는지 한 줄로 설명한다.
const String kAdjustmentExclusionReason = '잔액 수정은 수입·지출 합계에 포함되지 않습니다';
const String kCardSettlementExclusionReason = '카드 정산은 원본 지출로 이미 집계되었습니다';
