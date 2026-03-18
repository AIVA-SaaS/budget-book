-- V24: Budget flexible period support
-- Add period_type to replace budget_period
ALTER TABLE monthly_budgets ADD COLUMN period_type VARCHAR(10) NOT NULL DEFAULT 'MONTHLY';

-- Add start_date and end_date for date range periods
ALTER TABLE monthly_budgets ADD COLUMN start_date DATE;
ALTER TABLE monthly_budgets ADD COLUMN end_date DATE;

-- Migrate existing data: set period_type from budget_period
UPDATE monthly_budgets SET period_type = budget_period;

-- Set start_date/end_date for existing MONTHLY budgets
UPDATE monthly_budgets
SET start_date = (year_month || '-01')::DATE,
    end_date = ((year_month || '-01')::DATE + INTERVAL '1 month' - INTERVAL '1 day')::DATE
WHERE period_type = 'MONTHLY' AND start_date IS NULL;

-- Set start_date/end_date for existing WEEKLY budgets (same as monthly range, weekly is auto-split)
UPDATE monthly_budgets
SET start_date = (year_month || '-01')::DATE,
    end_date = ((year_month || '-01')::DATE + INTERVAL '1 month' - INTERVAL '1 day')::DATE
WHERE period_type = 'WEEKLY' AND start_date IS NULL;

-- Period type constraint
ALTER TABLE monthly_budgets ADD CONSTRAINT ck_monthly_budgets_period_type
    CHECK (period_type IN ('NONE', 'DAILY', 'WEEKLY', 'MONTHLY'));

-- Index for date range queries
CREATE INDEX IF NOT EXISTS idx_monthly_budgets_date_range
    ON monthly_budgets (couple_id, start_date, end_date);
