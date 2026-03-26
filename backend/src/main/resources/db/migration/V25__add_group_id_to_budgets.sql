-- V25: Add group_id to monthly_budgets for group-level budget support

-- 1. Add group_id column (nullable — existing rows default to NULL, preserving current data)
ALTER TABLE monthly_budgets
    ADD COLUMN group_id UUID REFERENCES category_groups(id) ON DELETE SET NULL;

-- 2. Drop the existing unique constraint that covers only category_id
DROP INDEX IF EXISTS uk_monthly_budgets_couple_category_month;

-- 3. Recreate unique constraint including group_id
--    COALESCE with a sentinel UUID lets the index treat NULL as a fixed value,
--    so (couple, NULL category, NULL group, month) is still unique.
CREATE UNIQUE INDEX uk_monthly_budgets_couple_cat_group_month
    ON monthly_budgets (
        couple_id,
        COALESCE(category_id, '00000000-0000-0000-0000-000000000000'::UUID),
        COALESCE(group_id,    '00000000-0000-0000-0000-000000000000'::UUID),
        year_month
    );

-- 4. Enforce mutual exclusivity: category_id and group_id cannot both be set
ALTER TABLE monthly_budgets
    ADD CONSTRAINT ck_budget_category_or_group
    CHECK (category_id IS NULL OR group_id IS NULL);

-- 5. Index for group-level budget lookups
CREATE INDEX IF NOT EXISTS idx_monthly_budgets_group_id
    ON monthly_budgets (group_id)
    WHERE group_id IS NOT NULL;
