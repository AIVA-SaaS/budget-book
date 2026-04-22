-- Phase 22: TransferKind 확장 + TransactionType.ADJUSTMENT 추가
--
-- 1. transfers.kind 컬럼 추가: 기존 is_card_settlement 를 의미 기반 4값으로 일반화
--    - CARD_SETTLEMENT : 카드 결제 (통계 제외) — 기존 is_card_settlement=true 에서 백필
--    - EXPENSE_TRANSFER: 이체로 기록된 지출 (지출 집계 포함)
--    - INCOME_TRANSFER : 이체로 기록된 수입 (수입 집계 포함)
--    - GENERIC         : 순수 내부 이동 (totalTransfer 별도 집계)
--
-- 2. transactions.type 에 ADJUSTMENT 추가: 실잔액 보정 (통계 제외/잔액 포함)
--
-- is_card_settlement 컬럼은 당분간 유지 (deprecated), V55 에서 DROP 예정.

-- transfers.kind 컬럼 추가 (기본값 GENERIC)
ALTER TABLE transfers ADD COLUMN kind VARCHAR(20) NOT NULL DEFAULT 'GENERIC';

-- 기존 카드 결제 이체 백필
UPDATE transfers SET kind = 'CARD_SETTLEMENT' WHERE is_card_settlement = true;

-- kind 값 CHECK 제약
ALTER TABLE transfers ADD CONSTRAINT transfers_kind_check
    CHECK (kind IN ('CARD_SETTLEMENT', 'EXPENSE_TRANSFER', 'INCOME_TRANSFER', 'GENERIC'));

-- kind 기반 통계 쿼리 가속용 인덱스 (couple_id, transfer_date, kind)
CREATE INDEX idx_transfers_couple_date_kind ON transfers (couple_id, transfer_date, kind);

-- transactions.type CHECK 제약 확장: ADJUSTMENT 추가
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS ck_transactions_type;
ALTER TABLE transactions ADD CONSTRAINT ck_transactions_type
    CHECK (type IN ('INCOME', 'EXPENSE', 'ADJUSTMENT'));

-- ADJUSTMENT 는 부호 있는 금액 (음수 가능). 기존 ck_transactions_amount (amount > 0) 는
-- V46 에서 이미 '>= 0' 으로 완화되었는지 확인 필요. 여기서는 ADJUSTMENT 만 음수 허용하도록 완화.
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS ck_transactions_amount;
ALTER TABLE transactions ADD CONSTRAINT ck_transactions_amount
    CHECK (
        (type IN ('INCOME', 'EXPENSE') AND amount >= 0)
        OR type = 'ADJUSTMENT'
    );
