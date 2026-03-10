CREATE TABLE monthly_budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    year_month VARCHAR(7) NOT NULL,
    amount BIGINT NOT NULL CHECK (amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Unique constraint: one budget per couple per category per month
-- COALESCE handles nullable category_id (null = total budget)
CREATE UNIQUE INDEX uk_monthly_budgets_couple_category_month
    ON monthly_budgets (couple_id, COALESCE(category_id, '00000000-0000-0000-0000-000000000000'), year_month);

CREATE INDEX idx_monthly_budgets_couple_id ON monthly_budgets (couple_id);
CREATE INDEX idx_monthly_budgets_couple_month ON monthly_budgets (couple_id, year_month);
CREATE INDEX idx_monthly_budgets_category_id ON monthly_budgets (category_id);
