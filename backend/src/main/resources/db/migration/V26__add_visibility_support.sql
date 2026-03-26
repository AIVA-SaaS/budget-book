-- V26: Add visibility (SHARED / PRIVATE) support to major entities
-- Allows individual household members to mark records as private so
-- that only the owner can see them.

-- ============================================================
-- 1. transactions: visibility + owner_id
-- ============================================================
ALTER TABLE transactions
    ADD COLUMN visibility VARCHAR(10) NOT NULL DEFAULT 'SHARED',
    ADD COLUMN owner_id UUID REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE transactions
    ADD CONSTRAINT ck_transactions_visibility
    CHECK (visibility IN ('SHARED', 'PRIVATE'));

ALTER TABLE transactions
    ADD CONSTRAINT ck_private_tx_requires_owner
    CHECK (visibility = 'SHARED' OR owner_id IS NOT NULL);

-- Back-fill: existing transactions are shared; owner defaults to author
UPDATE transactions SET owner_id = author_id;

CREATE INDEX idx_transactions_visibility_owner
    ON transactions (visibility, owner_id);

-- ============================================================
-- 2. categories: visibility + owner_id
-- ============================================================
ALTER TABLE categories
    ADD COLUMN visibility VARCHAR(10) NOT NULL DEFAULT 'SHARED',
    ADD COLUMN owner_id UUID REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE categories
    ADD CONSTRAINT ck_categories_visibility
    CHECK (visibility IN ('SHARED', 'PRIVATE'));

ALTER TABLE categories
    ADD CONSTRAINT ck_private_cat_requires_owner
    CHECK (visibility = 'SHARED' OR owner_id IS NOT NULL);

-- ============================================================
-- 3. category_groups: visibility + owner_id
-- ============================================================
ALTER TABLE category_groups
    ADD COLUMN visibility VARCHAR(10) NOT NULL DEFAULT 'SHARED',
    ADD COLUMN owner_id UUID REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE category_groups
    ADD CONSTRAINT ck_catgroups_visibility
    CHECK (visibility IN ('SHARED', 'PRIVATE'));

ALTER TABLE category_groups
    ADD CONSTRAINT ck_private_catgroup_requires_owner
    CHECK (visibility = 'SHARED' OR owner_id IS NOT NULL);

-- ============================================================
-- 4. monthly_budgets: visibility + owner_id
-- ============================================================
ALTER TABLE monthly_budgets
    ADD COLUMN visibility VARCHAR(10) NOT NULL DEFAULT 'SHARED',
    ADD COLUMN owner_id UUID REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE monthly_budgets
    ADD CONSTRAINT ck_budgets_visibility
    CHECK (visibility IN ('SHARED', 'PRIVATE'));

ALTER TABLE monthly_budgets
    ADD CONSTRAINT ck_private_budget_requires_owner
    CHECK (visibility = 'SHARED' OR owner_id IS NOT NULL);

-- ============================================================
-- 5. recurring_transactions: visibility only
--    (author_id already present and serves as the owner)
-- ============================================================
ALTER TABLE recurring_transactions
    ADD COLUMN visibility VARCHAR(10) NOT NULL DEFAULT 'SHARED';

ALTER TABLE recurring_transactions
    ADD CONSTRAINT ck_recurring_visibility
    CHECK (visibility IN ('SHARED', 'PRIVATE'));

-- ============================================================
-- 6. money_pockets: visibility + owner_id
-- ============================================================
ALTER TABLE money_pockets
    ADD COLUMN visibility VARCHAR(10) NOT NULL DEFAULT 'SHARED',
    ADD COLUMN owner_id UUID REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE money_pockets
    ADD CONSTRAINT ck_pockets_visibility
    CHECK (visibility IN ('SHARED', 'PRIVATE'));

ALTER TABLE money_pockets
    ADD CONSTRAINT ck_private_pocket_requires_owner
    CHECK (visibility = 'SHARED' OR owner_id IS NOT NULL);
