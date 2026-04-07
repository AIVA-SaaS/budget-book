-- V46: Weekly budget settlement tracking per category per week
CREATE TABLE weekly_budget_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES couples(id),
    budget_id UUID NOT NULL REFERENCES monthly_budgets(id),
    year_month VARCHAR(7) NOT NULL,
    week_number INT NOT NULL,
    week_start DATE NOT NULL,
    week_end DATE NOT NULL,
    category_id UUID REFERENCES categories(id),
    settled_amount BIGINT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    settled_at TIMESTAMP WITH TIME ZONE,
    settled_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_settlement_budget_week_category UNIQUE (budget_id, year_month, week_number, category_id),
    CONSTRAINT ck_settlement_status CHECK (status IN ('PENDING', 'SETTLED')),
    CONSTRAINT ck_settlement_week_number CHECK (week_number >= 1 AND week_number <= 6)
);

CREATE INDEX idx_settlement_couple_month ON weekly_budget_settlements(couple_id, year_month);
