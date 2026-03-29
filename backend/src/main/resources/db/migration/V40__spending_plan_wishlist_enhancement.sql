-- 1. target_date nullable (WISHLIST items have no date)
ALTER TABLE spending_plans ALTER COLUMN target_date DROP NOT NULL;

-- 2. Add WISHLIST to status CHECK
ALTER TABLE spending_plans DROP CONSTRAINT ck_spending_plan_status;
ALTER TABLE spending_plans ADD CONSTRAINT ck_spending_plan_status
  CHECK (status IN ('WISHLIST', 'PLANNED', 'COMPLETED', 'SKIPPED', 'OVERDUE'));

-- 3. Priority column
ALTER TABLE spending_plans ADD COLUMN priority VARCHAR(10) NOT NULL DEFAULT 'MEDIUM';
ALTER TABLE spending_plans ADD CONSTRAINT ck_spending_plan_priority
  CHECK (priority IN ('HIGH', 'MEDIUM', 'LOW'));

-- 4. Price range
ALTER TABLE spending_plans ADD COLUMN estimated_min BIGINT;
ALTER TABLE spending_plans ADD COLUMN estimated_max BIGINT;

-- 5. Tags (comma-separated text)
ALTER TABLE spending_plans ADD COLUMN tags TEXT;

-- 6. Week number for assignment
ALTER TABLE spending_plans ADD COLUMN week_number INT;
ALTER TABLE spending_plans ADD CONSTRAINT ck_spending_plan_week
  CHECK (week_number IS NULL OR (week_number >= 1 AND week_number <= 6));

-- 7. Wishlist index
CREATE INDEX idx_spending_plans_wishlist
  ON spending_plans(couple_id, status) WHERE status = 'WISHLIST';
