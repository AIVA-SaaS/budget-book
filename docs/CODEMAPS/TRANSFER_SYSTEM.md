# Transfer / 결제 / ADJUSTMENT 시스템 — Phase 22 코드맵

> Phase 22 (2026-04) 에서 확정된 이체·카드 결제·잔액 보정 도메인의 **단일 출처 레퍼런스**.
> 기획서: [`docs/sessions/2026-04-21_1_plan.md`](../sessions/2026-04-21_1_plan.md), [`docs/sessions/2026-04-22_2_plan.md`](../sessions/2026-04-22_2_plan.md)
> 하네스 인시던트: `amount_calculation` (5회째), `filter_propagation` (4회째), `db_schema` (2회째)

---

## 1. Overview

Phase 22 는 "이체가 지출에 이중 계산된다" 는 사용자 보고에서 출발해, 이체 1건이 수입/지출/이체 중 어디에 반영되어야 하는지를 `Boolean isCardSettlement` 단일 플래그로 구분하던 기존 구조를 **의미 기반 4값 enum `TransferKind`** 로 일반화한다. 네 값 — `CARD_SETTLEMENT`, `EXPENSE_TRANSFER`, `INCOME_TRANSFER`, `GENERIC` — 은 DB CHECK 제약, 서버 DTO, 클라이언트 entity, UI 드롭다운 옵션까지 **완전히 동일한 와이어 이름**으로 흐른다. 이와 함께 "실잔액 보정" 이라는 별도 요구사항을 위해 `TransactionType.ADJUSTMENT` 를 신설해 **통계 집계에선 제외되지만 잔액 계산엔 포함되는** 거래 유형을 분리했다.

두 번째 구조적 변화는 집계 경로의 단일화다. 이전에는 `StatisticsService`, `BudgetService`, `ReportService`, `MonthSummaryBar` 등이 각자 인라인 `sum(Transfer.amount)` + `if (!isCardSettlement)` 조건을 반복해 카드 결제 누락이 반복 재발했다. Phase 22 S1/S2 에서는 BE 의 [`ExpenseCalculator`](../../backend/src/main/kotlin/com/budgetbook/statistics/service/ExpenseCalculator.kt) 와 FE 의 [`LedgerSummary.from(...)`](../../frontend/lib/features/statistics/domain/entities/ledger_summary.dart) factory 를 **유일한 집계 진입점**으로 강제하고, kind/type 분기 로직을 이 두 모듈 안에서만 수행한다. 호출부는 합산이 아니라 "무엇의 총액인지" 만 질의한다.

---

## 2. TransferKind 매트릭스

정의 위치: BE [`TransferKind.kt`](../../backend/src/main/kotlin/com/budgetbook/transfer/domain/TransferKind.kt) / FE [`transfer.dart:15-32`](../../frontend/lib/features/transfer/domain/entities/transfer.dart)

| kind | 의미 | 지출 집계 | 수입 집계 | 이체 집계 | UI 동작 | 자동 판정 조건 | 예시 |
|---|---|:---:|:---:|:---:|---|---|---|
| `CARD_SETTLEMENT` | 카드 사용 거래(EXPENSE)의 지급 완료. 원본 거래가 이미 지출로 집계되어 있어 이 이체 자체는 모든 통계에서 제외. | 제외 | 제외 | 제외 | 카드 결제 페이지 전용 흐름. `POST /api/v1/transfers/card-settlement` 로 생성되고 선택한 거래들의 `paid_at` 이 함께 업데이트됨. | `src.type=BANK && dst.type=CREDIT` (기본값) | 국민은행 → 신한카드 결제일 출금 |
| `EXPENSE_TRANSFER` | "이체로 기록한 지출". OUT 금액을 지출 총액에 합산. 수입엔 영향 없음. | **포함** (source amount) | 제외 | 제외 | 이체 폼의 "종류" 드롭다운에서 사용자가 수동 선택. | 자동 판정 불가 — 사용자 명시 | 계좌에서 현금 인출 후 쓴 것으로 간주하고 싶을 때 |
| `INCOME_TRANSFER` | "이체로 기록한 수입". IN 금액을 수입 총액에 합산. 지출엔 영향 없음. | 제외 | **포함** (destination amount) | 제외 | 이체 폼에서 수동 선택. | 자동 판정 불가 — 사용자 명시 | 환급성 입금, 보너스성 이체를 수입으로 표시 |
| `GENERIC` | 순수 내부 이동 (은행↔은행, 현금↔은행 등). 지출/수입 중립, 별도 `totalTransfer` 로만 집계. | 제외 | 제외 | **포함** | 이체 폼 기본값. MonthSummaryBar "이체" 칸에만 반영. | 위 3가지에 해당하지 않는 모든 경우 (기본값) | 적금 계좌에서 생활비 통장으로 이체 |

> 제약: `CREDIT → CREDIT` 조합은 `TransferService.validateNotCreditToCredit` 에서 `TRANSFER_CREDIT_TO_CREDIT_NOT_ALLOWED` BusinessException 으로 차단됨 ([`TransferService.kt:284-288`](../../backend/src/main/kotlin/com/budgetbook/transfer/service/TransferService.kt)).

### 자주 쓰이는 kind 집합 상수

[`TransferKinds.kt`](../../backend/src/main/kotlin/com/budgetbook/transfer/domain/TransferKinds.kt) — 호출부가 매번 Set 리터럴을 만들지 않도록 의미 기반 상수를 고정:

```kotlin
object TransferKinds {
    val NON_CARD_SETTLEMENT: Set<TransferKind> = setOf(EXPENSE_TRANSFER, INCOME_TRANSFER, GENERIC)
    val EXPENSE_AFFECTING:   Set<TransferKind> = setOf(EXPENSE_TRANSFER)
    val INCOME_AFFECTING:    Set<TransferKind> = setOf(INCOME_TRANSFER)
    val TRANSFER_ONLY:       Set<TransferKind> = setOf(GENERIC)
}
```

---

## 3. TransactionType.ADJUSTMENT

정의 위치: [`Transaction.kt:90`](../../backend/src/main/kotlin/com/budgetbook/transaction/domain/Transaction.kt) (`enum class TransactionType { INCOME, EXPENSE, ADJUSTMENT }`)

### 목적
실제 계좌 잔액과 앱 내 잔액이 어긋났을 때의 **보정용 거래**. 이전에는 이런 수요를 위해 임시 EXPENSE/INCOME 거래를 만들어 통계를 왜곡시켰으나, ADJUSTMENT 는 **통계 집계에선 완전히 제외되고 잔액 계산에만 반영**되는 새로운 범주를 제공한다.

### 잔액 반영 vs 통계 제외
| 경로 | ADJUSTMENT 처리 |
|---|---|
| `ExpenseCalculator.totalExpense / totalIncome / totalTransfer` | **제외** — [`ExpenseCalculator.kt:100-102`](../../backend/src/main/kotlin/com/budgetbook/statistics/service/ExpenseCalculator.kt) 의 `require(type == EXPENSE || type == INCOME)` 로 호출 단계에서 방지 |
| `LedgerSummary.from` (FE) | **제외** (income/expense 버킷에 더하지 않음). 대신 `balance = income - expense + adjustmentSum` 식에서 부호 그대로 반영 ([`ledger_summary.dart:67-71, 113`](../../frontend/lib/features/statistics/domain/entities/ledger_summary.dart)) |
| `PaymentMethodService.recomputeBalance` | **포함** — 부호 있는 `amount` 가 balance 에 그대로 더해짐 |
| `pendingAmount` (미결제 집계) | 제외 — EXPENSE 만 합산 |

### UI — "잔액 수정" 다이얼로그
[`balance_adjustment_dialog.dart`](../../frontend/lib/features/payment_method/presentation/widgets/balance_adjustment_dialog.dart) (278 lines)

- 호출: 결제수단 상세 화면에서 "잔액 수정" 버튼
- 입력: 현재 앱 잔액 (read-only) + 실제 잔액 (사용자 입력, `-` 부호 허용)
- 제출: `actual - current` 를 `amount` 로 하는 `type=ADJUSTMENT` 거래 POST
- 이후: `onSuccess` 콜백이 PaymentMethod 리로드 + transaction 리로드를 트리거

### `amount` 부호 규칙
- `amount > 0` → 잔액 증가 (예: 현금을 빠뜨려서 실잔액이 앱보다 많을 때)
- `amount < 0` → 잔액 감소 (예: 실수로 이체 누락)
- `amount == 0` → 제출 거부 (차액이 없으면 생성 의미 없음)

DB CHECK 제약 ([`V54__add_transfer_kind_and_adjustment.sql:33-38`](../../backend/src/main/resources/db/migration/V54__add_transfer_kind_and_adjustment.sql)):
```sql
ALTER TABLE transactions ADD CONSTRAINT ck_transactions_amount
    CHECK (
        (type IN ('INCOME', 'EXPENSE') AND amount >= 0)
        OR type = 'ADJUSTMENT'
    );
```
→ EXPENSE/INCOME 은 음수 금지를 유지하고 **ADJUSTMENT 만** 부호 있는 amount 를 허용.

### ADJUSTMENT vs CARD_SETTLEMENT 분리 근거
두 개념 모두 "보정적" 성격이 있어 하나로 묶고 싶을 수 있으나 분리를 유지한다. `CARD_SETTLEMENT` 은 (1) 원본 EXPENSE 와의 결제 링크, (2) `Transaction.markAsPaid(paidAt)` 연쇄 호출, (3) `pendingAmount` 에서 제외되는 부수효과가 있다. ADJUSTMENT 는 이런 연쇄 없이 **순수 잔액 증감**만 표현한다.

---

## 4. Auto-judgment algorithm

`TransferService.resolveDefaultKind(sourceType, destType)` — [`TransferService.kt:290-304`](../../backend/src/main/kotlin/com/budgetbook/transfer/service/TransferService.kt)

```kotlin
internal fun resolveDefaultKind(
    sourceType: PaymentMethodType,
    destType: PaymentMethodType
): TransferKind = when {
    sourceType == BANK && destType == CREDIT -> TransferKind.CARD_SETTLEMENT
    else                                     -> TransferKind.GENERIC
}
```

| src → dst | 자동 판정 결과 | 비고 |
|---|---|---|
| `CREDIT → CREDIT` | — | 호출 전 `validateNotCreditToCredit` 에서 BusinessException |
| `BANK → CREDIT` | `CARD_SETTLEMENT` | 카드 결제의 표준 흐름. 전용 엔드포인트 `/card-settlement` 도 이 경로로 진입 |
| `CREDIT → BANK` | `GENERIC` | 환급성 입금이면 사용자가 `INCOME_TRANSFER` 로 수동 변경 가능 |
| `BANK ↔ BANK`, `CASH ↔ BANK`, `CASH ↔ CASH`, 기타 | `GENERIC` | 순수 내부 이동의 기본값 |
| (사용자 수동 지정) | `EXPENSE_TRANSFER` / `INCOME_TRANSFER` | 구조적으로 자동 판정 불가. 이체 폼의 "종류" 드롭다운에서만 선택 가능 |

**FE 동기화**: `transfer_form_page.dart` 의 `_recommendKind()` 가 source/destination 변경을 감지해 동일 규칙으로 기본값을 추천하고, 사용자가 드롭다운을 건드린 순간부터 `_kindOverridden = true` 로 잠근다 ([`transfer_form_page.dart:96-115`](../../frontend/lib/features/transfer/presentation/pages/transfer_form_page.dart)).

**우선순위**: `request.kind ?: resolveDefaultKind(...)` — 요청 본문에 `kind` 가 명시되면 자동 판정을 건너뛰고 그대로 사용.

---

## 5. Aggregation path — 단일 집계 진입점

### BE: `ExpenseCalculator`
[`ExpenseCalculator.kt`](../../backend/src/main/kotlin/com/budgetbook/statistics/service/ExpenseCalculator.kt) (108 lines) — `@Component` 로 DI

```
totalExpense(couple, from, to, userId, visibility)
    = sum(Transaction WHERE type=EXPENSE)
    + sum(Transfer.amount WHERE kind=EXPENSE_TRANSFER)

totalIncome(couple, from, to, userId, visibility)
    = sum(Transaction WHERE type=INCOME)
    + sum(Transfer.amount WHERE kind=INCOME_TRANSFER)

totalTransfer(couple, from, to)
    = sum(Transfer.amount WHERE kind=GENERIC)
```

호출부 (모두 유틸만 사용, 인라인 sum 없음):
- [`StatisticsService.kt:73-74, 228-233, 346-349`](../../backend/src/main/kotlin/com/budgetbook/statistics/service/StatisticsService.kt) — 월/기간/필터 집계
- `BudgetService`, `ReportService` — 동일

내부 구현은 `TransferRepository.sumAmountBySourceByKind` / `sumAmountByDestinationByKind` 를 `TransferKinds.EXPENSE_AFFECTING` 등 사전 정의 상수와 조합.

### FE: `LedgerSummary.from(...)`
[`ledger_summary.dart:52-115`](../../frontend/lib/features/statistics/domain/entities/ledger_summary.dart)

```dart
LedgerSummary.from({
  required List<Transaction> txs,
  required List<Transfer> tfs,
  String? pmFilter,  // 단일 결제수단 뷰 모드
}) → LedgerSummary { totalIncome, totalExpense, totalTransfer, balance }
```

- `pmFilter == null` (전체 월 뷰): GENERIC 이체는 amount 를 1회만 합산, EXPENSE/INCOME_TRANSFER 는 무조건 해당 버킷에 합산
- `pmFilter != null` (결제수단 단일 뷰): source/destination 중 필터 대상 방향만 계산해 이중 계산 방지
- ADJUSTMENT: income/expense 에는 제외, `balance = income - expense + adjustmentSum` 에만 반영

호출부: [`transaction_list_page.dart:452`](../../frontend/lib/features/transaction/presentation/pages/transaction_list_page.dart) 의 MonthSummaryBar 가 유일한 소비자. kind/type 분기는 전부 이 factory 안에서만 수행된다.

### 재발 방지 계약 (S1/S2)
- **BE**: `StatisticsService`, `BudgetService`, `ReportService` 등은 `ExpenseCalculator` 만 DI. 직접 `TransferRepository.sum*` 호출 금지.
- **FE**: 모든 화면은 `LedgerSummary.from()` 만 호출. 루프 안에서 `expense += t.amount` 패턴 금지 (리뷰 시 차단).

---

## 6. Card settlement flow

시나리오: "지난달 카드로 썼던 결제액이 이번달 1일에 은행에서 자동 출금" — 거래(EXPENSE)는 이미 기록되어 있고, 실제 은행 출금 시점에 결제 이체를 기록하고 싶다.

### 시퀀스

```
User                FE                          BE                             DB
 │                   │                           │                              │
 │ "결제" 화면 선택    │                           │                              │
 │ (대상 거래 체크)    │                           │                              │
 ├──────────────────▶│                           │                              │
 │                   │ POST /api/v1/transfers/   │                              │
 │                   │      card-settlement      │                              │
 │                   │ { src=BANK, dst=CREDIT,   │                              │
 │                   │   amount, transferDate,   │                              │
 │                   │   transactionIds: [...] } │                              │
 │                   ├──────────────────────────▶│                              │
 │                   │                           │ TransferService.             │
 │                   │                           │   createCardSettlement       │
 │                   │                           │   ├─ validate BANK → CREDIT  │
 │                   │                           │   ├─ new Transfer(           │
 │                   │                           │   │    kind=CARD_SETTLEMENT, │
 │                   │                           │   │    isCardSettlement=true)│
 │                   │                           │   │   save ───────────────▶ transfers INSERT
 │                   │                           │   └─ transactionRepository   │
 │                   │                           │       .markAsPaid(ids,       │
 │                   │                           │          paidAt=transferDate)│
 │                   │                           │       ─────────────────────▶ transactions
 │                   │                           │                              │   SET paid_at
 │                   │                           │   publish SyncEvent          │
 │                   │ ◀─── TransferResponse ────┤   (CARD_SETTLEMENT_CREATED)  │
 │ ◀───── refresh ───┤                           │                              │
```

### 핵심 포인트

1. **전용 엔드포인트**: 일반 `POST /transfers` 와 분리. `/card-settlement` 는 `transactionIds` 필드와 `dst.type = CREDIT` 검증을 추가로 수행 ([`TransferController.kt:47-62`](../../backend/src/main/kotlin/com/budgetbook/transfer/controller/TransferController.kt)).

2. **원자성**: Transfer 생성 + `markAsPaid` 가 동일 `@Transactional` 안에서 실행. 실패 시 둘 다 롤백.

3. **markAsPaid JPQL**: [`TransactionRepository.kt:440-450`](../../backend/src/main/kotlin/com/budgetbook/transaction/repository/TransactionRepository.kt)
    ```kotlin
    @Modifying
    @Query("""
        UPDATE Transaction t
        SET t.paidAt = :paidAt
        WHERE t.id IN :ids
        AND t.paidAt IS NULL
    """)
    fun markAsPaid(ids: List<UUID>, paidAt: LocalDate): Int
    ```
    `paid_at IS NULL` 조건으로 이미 결제 처리된 거래는 건너뜀 (멱등성).

4. **집계 결과**: 생성된 Transfer 는 `kind=CARD_SETTLEMENT` 이므로 `ExpenseCalculator` / `LedgerSummary.from` 양쪽에서 **모두 제외**. 원본 EXPENSE Transaction 1건만 지출로 카운트 → 이중 계산 없음.

5. **미결제 목록**: `PaymentMethodService` 가 카드별 `pendingAmount` 를 계산할 때 `paid_at IS NULL` 인 EXPENSE 만 합산하므로, `markAsPaid` 후 해당 거래는 자동으로 미결제 목록에서 사라짐.

---

## 7. File map

### Backend (Kotlin)

| 파일 | 용도 |
|---|---|
| [`transfer/domain/Transfer.kt`](../../backend/src/main/kotlin/com/budgetbook/transfer/domain/Transfer.kt) | JPA 엔티티. `kind: TransferKind` + `@Deprecated isCardSettlement: Boolean` (V55 까지 병행) |
| [`transfer/domain/TransferKind.kt`](../../backend/src/main/kotlin/com/budgetbook/transfer/domain/TransferKind.kt) | 4값 enum 정의 + kdoc 으로 집계 정책 명시 |
| [`transfer/domain/TransferKinds.kt`](../../backend/src/main/kotlin/com/budgetbook/transfer/domain/TransferKinds.kt) | `NON_CARD_SETTLEMENT`, `EXPENSE_AFFECTING`, `INCOME_AFFECTING`, `TRANSFER_ONLY` 상수 Set |
| [`transfer/service/TransferService.kt`](../../backend/src/main/kotlin/com/budgetbook/transfer/service/TransferService.kt) | CRUD + `resolveDefaultKind` 자동 판정 + `createCardSettlement` 전용 메서드 |
| [`transfer/controller/TransferController.kt`](../../backend/src/main/kotlin/com/budgetbook/transfer/controller/TransferController.kt) | REST 엔드포인트. `/card-settlement` 분리 |
| [`transfer/dto/TransferDtos.kt`](../../backend/src/main/kotlin/com/budgetbook/transfer/dto/TransferDtos.kt) | `CreateTransferRequest.kind: TransferKind?` (null=자동), `UpdateTransferRequest.kind: PatchValue<TransferKind>?`, `TransferResponse.kind: TransferKind` |
| [`transfer/repository/TransferRepository.kt`](../../backend/src/main/kotlin/com/budgetbook/transfer/repository/TransferRepository.kt) | `sumAmountBySourceByKind(kinds)` / `sumAmountByDestinationByKind(kinds)` + legacy `sumAmount...ExcludingSettlement` (V55 에서 제거) |
| [`transaction/domain/Transaction.kt`](../../backend/src/main/kotlin/com/budgetbook/transaction/domain/Transaction.kt) | `TransactionType { INCOME, EXPENSE, ADJUSTMENT }` + `paidAt: LocalDate?` |
| [`transaction/repository/TransactionRepository.kt`](../../backend/src/main/kotlin/com/budgetbook/transaction/repository/TransactionRepository.kt) | `markAsPaid(ids, paidAt)` + 통계 쿼리에서 `type IN (EXPENSE, INCOME)` 필터 |
| [`statistics/service/ExpenseCalculator.kt`](../../backend/src/main/kotlin/com/budgetbook/statistics/service/ExpenseCalculator.kt) | **BE 집계 단일 진입점.** `totalExpense`, `totalIncome`, `totalTransfer` |
| [`statistics/service/StatisticsService.kt`](../../backend/src/main/kotlin/com/budgetbook/statistics/service/StatisticsService.kt) | 월/기간 통계. `ExpenseCalculator` 만 호출 |
| [`statistics/dto/StatisticsDtos.kt`](../../backend/src/main/kotlin/com/budgetbook/statistics/dto/StatisticsDtos.kt) | `totalTransfer: Long` 필드 포함 |
| [`paymentmethod/service/PaymentMethodService.kt`](../../backend/src/main/kotlin/com/budgetbook/paymentmethod/service/PaymentMethodService.kt) | `recomputeBalance` 에 ADJUSTMENT 포함, `pendingAmount` 는 EXPENSE 만 |
| [`db/migration/V52__add_is_card_settlement_to_transfers.sql`](../../backend/src/main/resources/db/migration/V52__add_is_card_settlement_to_transfers.sql) | boolean 컬럼 도입 |
| [`db/migration/V53__backfill_card_settlement_data.sql`](../../backend/src/main/resources/db/migration/V53__backfill_card_settlement_data.sql) | 기존 BANK→CREDIT 이체 백필 + `paid_at` 채우기 |
| [`db/migration/V54__add_transfer_kind_and_adjustment.sql`](../../backend/src/main/resources/db/migration/V54__add_transfer_kind_and_adjustment.sql) | `kind` 컬럼 + CHECK + `type` CHECK 확장 (ADJUSTMENT) |

### Frontend (Dart)

| 파일 | 용도 |
|---|---|
| [`features/transfer/domain/entities/transfer.dart`](../../frontend/lib/features/transfer/domain/entities/transfer.dart) | `enum TransferKind { cardSettlement, expenseTransfer, incomeTransfer, generic }` + wire name 매핑 + derived `isCardSettlement` |
| [`features/transfer/data/models/transfer_model.dart`](../../frontend/lib/features/transfer/data/models/transfer_model.dart) | JSON → entity. `kind` 우선, 부재 시 legacy `isCardSettlement` fallback |
| [`features/transfer/presentation/pages/transfer_form_page.dart`](../../frontend/lib/features/transfer/presentation/pages/transfer_form_page.dart) | "종류" 드롭다운 (3개: 순수/지출/수입) + `_recommendKind` 자동 추천 + 수동 override 잠금 |
| [`features/transaction/domain/entities/transaction.dart`](../../frontend/lib/features/transaction/domain/entities/transaction.dart) | `isExpense`, `isIncome`, `isAdjustment` getter |
| [`features/statistics/domain/entities/ledger_summary.dart`](../../frontend/lib/features/statistics/domain/entities/ledger_summary.dart) | **FE 집계 단일 진입점.** `LedgerSummary.from(txs, tfs, pmFilter?)` |
| [`features/transaction/presentation/pages/transaction_list_page.dart`](../../frontend/lib/features/transaction/presentation/pages/transaction_list_page.dart) | `LedgerSummary.from` 호출. kind/type 인라인 분기 없음 |
| [`features/transaction/presentation/widgets/month_summary_bar.dart`](../../frontend/lib/features/transaction/presentation/widgets/month_summary_bar.dart) | 수입/지출/이체/합계 4칸 표시 |
| [`features/payment_method/presentation/widgets/balance_adjustment_dialog.dart`](../../frontend/lib/features/payment_method/presentation/widgets/balance_adjustment_dialog.dart) | "잔액 수정" 다이얼로그. 차액을 ADJUSTMENT 거래로 POST |
| [`core/models/unified_filter_state.dart`](../../frontend/lib/core/models/unified_filter_state.dart) | `Set<String> transactionTypes` (`{EXPENSE, INCOME, TRANSFER}`) 다중 선택 |
| [`core/widgets/filters/unified_filter_bar.dart`](../../frontend/lib/core/widgets/filters/unified_filter_bar.dart) | SegmentedButton → `SelectableChipGroup` 다중 칩 |

---

## 8. Migration history

| 버전 | 파일 | 내용 | 적용 상태 |
|---|---|---|---|
| V52 | [`V52__add_is_card_settlement_to_transfers.sql`](../../backend/src/main/resources/db/migration/V52__add_is_card_settlement_to_transfers.sql) | `transfers.is_card_settlement BOOLEAN NOT NULL DEFAULT FALSE` 추가 + `idx_transfers_is_card_settlement` 인덱스 | ✅ 배포 완료 |
| V53 | [`V53__backfill_card_settlement_data.sql`](../../backend/src/main/resources/db/migration/V53__backfill_card_settlement_data.sql) | ① 기존 BANK→CREDIT 이체를 `is_card_settlement=true` 로 백필 ② 대응 거래의 `paid_at` 을 이체 일자로 자동 설정 | ✅ 배포 완료 |
| V54 | [`V54__add_transfer_kind_and_adjustment.sql`](../../backend/src/main/resources/db/migration/V54__add_transfer_kind_and_adjustment.sql) | ① `transfers.kind VARCHAR(20) NOT NULL DEFAULT 'GENERIC'` ② `is_card_settlement=true` → `kind='CARD_SETTLEMENT'` 백필 ③ `transfers_kind_check` CHECK 제약 ④ `idx_transfers_couple_date_kind` 인덱스 ⑤ `transactions.type` CHECK 에 `ADJUSTMENT` 추가 ⑥ `transactions.amount` CHECK 을 ADJUSTMENT 한정 음수 허용으로 완화 | ✅ 배포 완료 |
| **V55** | (예정) `V55__drop_is_card_settlement.sql` | `ALTER TABLE transfers DROP COLUMN is_card_settlement` — deprecated 컬럼 완전 제거. `Transfer.isCardSettlement` 프로퍼티/컬럼 삭제, `sumAmountBy...ExcludingSettlement` 2개 메서드 삭제, `TransferService` 의 sync 쓰기 3곳 제거 | ⏳ Phase 22 라이브 검증 통과 후 착수 (`T3`) |

### V52 → V54 진행 논리
1. **V52** 는 최소 침습적 플래그 도입. 기본값 `FALSE` 로 기존 데이터 무영향.
2. **V53** 은 V52 가 배포되기 **전부터** 존재하던 BANK→CREDIT 이체를 한 번에 정돈. "99% 는 카드 결제 용도" 라는 도메인 가정에 기반 (기획서 §V53 step 1 주석).
3. **V54** 는 `is_card_settlement: Boolean` 의 표현력 한계를 의미 기반 4값으로 확장. `is_card_settlement` 컬럼은 배포 순간 읽는 구버전 코드가 있을 수 있어 **일시 유지**. Transfer 엔티티와 TransferService 는 V54 배포 기간 동안 `kind` + `isCardSettlement` 를 **이중 기입** (`TransferService.kt:71-72, 145-146, 262-264`) 해 양쪽 호환 — V55 에서 한 번에 정리.

---

## 9. Known deprecations

| 위치 | 항목 | 대체 | 제거 예정 |
|---|---|---|---|
| [`Transfer.kt:70-75`](../../backend/src/main/kotlin/com/budgetbook/transfer/domain/Transfer.kt) | `@Deprecated var isCardSettlement: Boolean` (DB 컬럼 + JPA 필드) | `kind == TransferKind.CARD_SETTLEMENT` | V55 |
| [`TransferRepository.kt:120-143`](../../backend/src/main/kotlin/com/budgetbook/transfer/repository/TransferRepository.kt) | `@Deprecated fun sumAmountBySourceExcludingSettlement` | `sumAmountBySourceByKind(kinds = TransferKinds.NON_CARD_SETTLEMENT)` | V55 |
| [`TransferRepository.kt:145-167`](../../backend/src/main/kotlin/com/budgetbook/transfer/repository/TransferRepository.kt) | `@Deprecated fun sumAmountByDestinationExcludingSettlement` | `sumAmountByDestinationByKind(kinds = TransferKinds.NON_CARD_SETTLEMENT)` | V55 |
| [`TransferService.kt:29`](../../backend/src/main/kotlin/com/budgetbook/transfer/service/TransferService.kt) | 클래스 수준 `@Suppress("DEPRECATION")` | 제거 — 남은 `isCardSettlement` 참조 3곳 (`createTransfer`, `updateTransfer`, `createCardSettlement`) 과 `createTransferInternal` 의 sync 쓰기 삭제 | V55 |
| `TransferServiceTest` 외 4건 | Deprecated repo 메서드 mocking | 새 `...ByKind` 메서드 mocking 으로 교체 | V55 |
| [`transfer_model.dart:38-45`](../../frontend/lib/features/transfer/data/models/transfer_model.dart) | `json['isCardSettlement']` legacy fallback | BE 가 V55 배포되어 `kind` 가 항상 존재하게 되면 fallback 제거 | V55 BE 배포 후 |
| [`transfer.dart:77`](../../frontend/lib/features/transfer/domain/entities/transfer.dart) | `bool get isCardSettlement => kind == TransferKind.cardSettlement` | (선택) 호출부 감사 후 `t.kind == cardSettlement` 로 inline 치환 | 미정 — 호출부 많으면 유지 가능 |

### V55 PR 체크리스트 (T3)
1. `V55__drop_is_card_settlement.sql` — `DROP COLUMN is_card_settlement;`
2. `Transfer.kt`: `@Deprecated isCardSettlement` 프로퍼티 + 컬럼 삭제
3. `TransferService.kt`: `@Suppress("DEPRECATION")` 제거 + sync 쓰기 3곳 삭제
4. `TransferRepository.kt`: `sumAmountBy...ExcludingSettlement` 2개 메서드 삭제
5. 영향받는 테스트 4건의 mock 교체
6. 주석 정리 (Transaction.kt kdoc, TransferController.kt kdoc 의 "is_card_settlement" 표현)
7. FE `transfer_model.dart` legacy fallback 제거 (BE 배포 후 별도 PR)

---

## 부록 A. Transfer 생성 경로 요약

| 진입점 | 메서드 | 기본 kind | 용도 |
|---|---|---|---|
| `POST /api/v1/transfers` | `TransferService.createTransfer` | `request.kind ?: resolveDefaultKind` | 사용자 수동 생성 (이체 폼) |
| `POST /api/v1/transfers/card-settlement` | `TransferService.createCardSettlement` | 강제 `CARD_SETTLEMENT` | 카드 결제 전용 (거래 연결 + markAsPaid 포함) |
| 내부 호출 (auto-settlement 등) | `TransferService.createTransferInternal` | `resolveDefaultKind` | 시스템 주도 생성 (주간 자동 정산 등) |

## 부록 B. 집계 규칙 요약표

| 항목 | Transaction 기여 | Transfer 기여 | 비고 |
|---|---|---|---|
| `totalExpense` | `type=EXPENSE` | `kind=EXPENSE_TRANSFER` (source) | ADJUSTMENT 제외 |
| `totalIncome` | `type=INCOME` | `kind=INCOME_TRANSFER` (destination) | ADJUSTMENT 제외 |
| `totalTransfer` | 없음 | `kind=GENERIC` | CARD_SETTLEMENT/EXPENSE_TRANSFER/INCOME_TRANSFER 제외 |
| `balance` (FE) | EXPENSE/INCOME + ADJUSTMENT 부호 합 | — | `income - expense + adjustmentSum` |
| PaymentMethod `balance` (BE) | 모든 type (ADJUSTMENT 포함) | 모든 kind (CARD_SETTLEMENT 포함, source/destination 차감·가산) | 계좌 실잔액 계산 |
| PaymentMethod `pendingAmount` | `type=EXPENSE AND paid_at IS NULL` | 없음 | 미결제 카드 사용액 |

---

*Last updated: 2026-04-22 — Phase 22 PR #120/#121/#122 머지 후 기준. V55 DROP PR 은 라이브 검증(T1) 통과 후 착수 예정.*
