-- V61: Add needs_review flag to transactions for "확인/입력 필요" marker.
-- 사용자가 거래 등록 후 "나중에 확인 필요" 또는 "내용 입력 필요" 로 마킹할 수 있는 플래그.
-- partial index 로 "확인 필요만 보기" 필터 페이징을 빠르게 한다.
-- 기존 row 는 default false 로 backfill 된다 (NOT NULL DEFAULT false).

ALTER TABLE transactions
    ADD COLUMN IF NOT EXISTS needs_review BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_transactions_needs_review
    ON transactions (couple_id, transaction_date DESC)
    WHERE needs_review = true;
