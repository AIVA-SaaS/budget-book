-- V31: Fix FK ON DELETE behaviors and add missing constraints
--
-- 1. owner_id ON DELETE SET NULL -> RESTRICT (5 tables)
--    Prevents user deletion when they own PRIVATE records,
--    resolving the conflict with CHECK (visibility='SHARED' OR owner_id IS NOT NULL).
--
-- 2. money_pockets, pocket_transfers couple_id -> ON DELETE CASCADE
-- 3. pocket_transfers from/to pocket_id -> ON DELETE SET NULL (+ drop NOT NULL)
-- 4. distribution_ratios couple_id, pocket_id -> ON DELETE CASCADE
-- 5. users.provider CHECK constraint
-- 6. money_pockets.color VARCHAR(7) -> VARCHAR(20)

-- ============================================================
-- 1. owner_id: ON DELETE SET NULL -> ON DELETE RESTRICT
-- ============================================================

-- transactions
ALTER TABLE transactions DROP CONSTRAINT transactions_owner_id_fkey;
ALTER TABLE transactions ADD CONSTRAINT transactions_owner_id_fkey
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE RESTRICT;

-- categories
ALTER TABLE categories DROP CONSTRAINT categories_owner_id_fkey;
ALTER TABLE categories ADD CONSTRAINT categories_owner_id_fkey
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE RESTRICT;

-- category_groups
ALTER TABLE category_groups DROP CONSTRAINT category_groups_owner_id_fkey;
ALTER TABLE category_groups ADD CONSTRAINT category_groups_owner_id_fkey
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE RESTRICT;

-- monthly_budgets
ALTER TABLE monthly_budgets DROP CONSTRAINT monthly_budgets_owner_id_fkey;
ALTER TABLE monthly_budgets ADD CONSTRAINT monthly_budgets_owner_id_fkey
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE RESTRICT;

-- money_pockets
ALTER TABLE money_pockets DROP CONSTRAINT money_pockets_owner_id_fkey;
ALTER TABLE money_pockets ADD CONSTRAINT money_pockets_owner_id_fkey
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE RESTRICT;

-- ============================================================
-- 2. money_pockets.couple_id -> ON DELETE CASCADE
-- ============================================================
ALTER TABLE money_pockets DROP CONSTRAINT money_pockets_couple_id_fkey;
ALTER TABLE money_pockets ADD CONSTRAINT money_pockets_couple_id_fkey
    FOREIGN KEY (couple_id) REFERENCES couples(id) ON DELETE CASCADE;

-- ============================================================
-- 3. pocket_transfers FK fixes
-- ============================================================

-- couple_id -> ON DELETE CASCADE
ALTER TABLE pocket_transfers DROP CONSTRAINT pocket_transfers_couple_id_fkey;
ALTER TABLE pocket_transfers ADD CONSTRAINT pocket_transfers_couple_id_fkey
    FOREIGN KEY (couple_id) REFERENCES couples(id) ON DELETE CASCADE;

-- from_pocket_id -> nullable + ON DELETE SET NULL
ALTER TABLE pocket_transfers ALTER COLUMN from_pocket_id DROP NOT NULL;
ALTER TABLE pocket_transfers DROP CONSTRAINT pocket_transfers_from_pocket_id_fkey;
ALTER TABLE pocket_transfers ADD CONSTRAINT pocket_transfers_from_pocket_id_fkey
    FOREIGN KEY (from_pocket_id) REFERENCES money_pockets(id) ON DELETE SET NULL;

-- to_pocket_id -> nullable + ON DELETE SET NULL
ALTER TABLE pocket_transfers ALTER COLUMN to_pocket_id DROP NOT NULL;
ALTER TABLE pocket_transfers DROP CONSTRAINT pocket_transfers_to_pocket_id_fkey;
ALTER TABLE pocket_transfers ADD CONSTRAINT pocket_transfers_to_pocket_id_fkey
    FOREIGN KEY (to_pocket_id) REFERENCES money_pockets(id) ON DELETE SET NULL;

-- ============================================================
-- 4. distribution_ratios FK -> ON DELETE CASCADE
-- ============================================================
ALTER TABLE distribution_ratios DROP CONSTRAINT distribution_ratios_couple_id_fkey;
ALTER TABLE distribution_ratios ADD CONSTRAINT distribution_ratios_couple_id_fkey
    FOREIGN KEY (couple_id) REFERENCES couples(id) ON DELETE CASCADE;

ALTER TABLE distribution_ratios DROP CONSTRAINT distribution_ratios_pocket_id_fkey;
ALTER TABLE distribution_ratios ADD CONSTRAINT distribution_ratios_pocket_id_fkey
    FOREIGN KEY (pocket_id) REFERENCES money_pockets(id) ON DELETE CASCADE;

-- ============================================================
-- 5. users.provider CHECK constraint
-- ============================================================
ALTER TABLE users ADD CONSTRAINT ck_users_provider
    CHECK (provider IN ('GOOGLE', 'KAKAO'));

-- ============================================================
-- 6. money_pockets.color VARCHAR(7) -> VARCHAR(20)
-- ============================================================
ALTER TABLE money_pockets ALTER COLUMN color TYPE VARCHAR(20);
