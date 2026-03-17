-- Add optional pocket_id to monthly_budgets
ALTER TABLE monthly_budgets ADD COLUMN pocket_id UUID REFERENCES money_pockets(id) ON DELETE SET NULL;

-- Index for pocket-based queries
CREATE INDEX idx_monthly_budgets_pocket_id ON monthly_budgets(pocket_id);
