-- Ensure unique constraint on budgets: one budget per couple per category per month
-- Note: V6 already created this index, but this migration ensures it exists
-- COALESCE handles NULL category_id (overall budget) by replacing with sentinel UUID
CREATE UNIQUE INDEX IF NOT EXISTS uk_monthly_budgets_couple_category_month
    ON monthly_budgets (couple_id, COALESCE(category_id, '00000000-0000-0000-0000-000000000000'), year_month);
