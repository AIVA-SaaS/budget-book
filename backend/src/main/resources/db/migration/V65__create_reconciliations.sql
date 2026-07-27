-- V65 (2026-07-27) — 정산 스냅샷 (reconciliation)
--
-- 장부를 대조한 시점의 스냅샷을 기록한다. 어떤 스냅샷에도 담기지 않은 항목은
-- "미기록" 으로 남아 월말 누락 점검에 쓰인다.
--
-- 이름이 비슷한 기존 개념과 무관한 별도 테이블이다:
--   - 카드 결제      : transfers.kind = 'CARD_SETTLEMENT'
--   - 주간 예산 정산 : weekly_budget_settlements
--
-- 설계 결정 3가지 (docs/sessions/2026-07-27_1_plan.md §2.3)
--  1) 원본 삭제 시 FK 는 SET NULL + snapshot_* 컬럼으로 당시 값을 보존한다.
--     CASCADE 면 정산 이력이 조용히 사라져 "스냅샷" 의 의미가 무너진다.
--     그래서 XOR NOT NULL 대신 item_kind 판별자 + 조건부 CHECK 를 쓴다.
--  2) "한 항목은 최대 1개 스냅샷" 불변식을 partial unique index 로 DB 강제한다.
--     서비스 검증만 두면 부부가 동시에 정산할 때 중복 기록이 생겨 상단(미기록)/
--     하단(기록) 목록이 겹친다.
--  3) 거래와 이체 **양쪽** 을 담는다. 장부 목록은 transactions + transfers 병합이므로
--     거래만 지원하면 이체가 영구 미기록으로 남는다.

CREATE TABLE reconciliations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id       UUID        NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    year_month      VARCHAR(7)  NOT NULL,
    seq             INTEGER     NOT NULL,
    label           VARCHAR(100),
    item_count      INTEGER     NOT NULL DEFAULT 0,
    total_income    BIGINT      NOT NULL DEFAULT 0,
    total_expense   BIGINT      NOT NULL DEFAULT 0,
    total_transfer  BIGINT      NOT NULL DEFAULT 0,
    reconciled_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    reconciled_by   UUID        NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uk_reconciliations_couple_ym_seq UNIQUE (couple_id, year_month, seq),
    CONSTRAINT ck_reconciliations_year_month CHECK (year_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
    CONSTRAINT ck_reconciliations_seq CHECK (seq >= 1),
    CONSTRAINT ck_reconciliations_item_count CHECK (item_count >= 0)
);

CREATE INDEX idx_reconciliations_couple_ym ON reconciliations (couple_id, year_month);

CREATE TABLE reconciliation_items (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reconciliation_id    UUID        NOT NULL REFERENCES reconciliations(id) ON DELETE CASCADE,
    item_kind            VARCHAR(20) NOT NULL,
    -- 원본이 삭제되면 NULL 이 되고, 아래 snapshot_* 값으로 "삭제된 거래" 를 표시한다.
    transaction_id       UUID REFERENCES transactions(id) ON DELETE SET NULL,
    transfer_id          UUID REFERENCES transfers(id)    ON DELETE SET NULL,
    snapshot_amount      BIGINT      NOT NULL,
    snapshot_date        DATE        NOT NULL,
    snapshot_description VARCHAR(255),
    snapshot_kind        VARCHAR(20) NOT NULL,
    -- 원본 삭제 후 조회자 게이팅에 쓰는 폴백 값 (원본이 살아 있으면 원본 값이 우선).
    snapshot_visibility  VARCHAR(10) NOT NULL DEFAULT 'SHARED',
    snapshot_owner_id    UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_recon_items_kind CHECK (item_kind IN ('TRANSACTION', 'TRANSFER')),
    CONSTRAINT ck_recon_items_ref CHECK (
        (item_kind = 'TRANSACTION' AND transfer_id IS NULL) OR
        (item_kind = 'TRANSFER'    AND transaction_id IS NULL)
    ),
    CONSTRAINT ck_recon_items_visibility CHECK (snapshot_visibility IN ('SHARED', 'PRIVATE'))
);

-- 불변식: 한 거래/이체는 전 기간에 걸쳐 최대 1개 스냅샷에만 속한다.
-- (PostgreSQL 은 NULL 을 서로 다른 값으로 보므로 partial index 로 NULL 을 제외한다.)
CREATE UNIQUE INDEX uk_recon_items_transaction
    ON reconciliation_items (transaction_id) WHERE transaction_id IS NOT NULL;
CREATE UNIQUE INDEX uk_recon_items_transfer
    ON reconciliation_items (transfer_id) WHERE transfer_id IS NOT NULL;

CREATE INDEX idx_recon_items_reconciliation ON reconciliation_items (reconciliation_id);
