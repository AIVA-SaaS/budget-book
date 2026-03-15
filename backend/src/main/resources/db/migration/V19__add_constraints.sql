-- V19: Add uniqueness constraints and adjust budget amount constraint

-- 1. Categories: unique (couple_id, name) per couple
-- No soft-delete on categories, so a simple unique index suffices
CREATE UNIQUE INDEX IF NOT EXISTS uk_categories_couple_name
    ON categories (couple_id, name);

-- 2. Payment methods: unique (couple_id, name) per couple
CREATE UNIQUE INDEX IF NOT EXISTS uk_payment_methods_couple_name
    ON payment_methods (couple_id, name);

-- 3. Budgets: allow zero amount (change from amount > 0 to amount >= 0)
-- Drop existing constraint and re-add with >= 0
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name = 'monthly_budgets_amount_check'
    ) THEN
        ALTER TABLE monthly_budgets DROP CONSTRAINT monthly_budgets_amount_check;
    END IF;
END $$;

ALTER TABLE monthly_budgets ADD CONSTRAINT ck_monthly_budgets_amount CHECK (amount >= 0);
