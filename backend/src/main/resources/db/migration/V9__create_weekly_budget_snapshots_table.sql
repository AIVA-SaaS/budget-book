-- Weekly budget snapshots for tracking weekly spending vs budget
CREATE TABLE weekly_budget_snapshots (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id       UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    group_id        UUID REFERENCES category_groups(id) ON DELETE SET NULL,
    year_month      VARCHAR(7) NOT NULL,
    week_number     INTEGER NOT NULL,
    week_start      DATE NOT NULL,
    week_end        DATE NOT NULL,
    budget_amount   BIGINT NOT NULL DEFAULT 0,
    spent_amount    BIGINT NOT NULL DEFAULT 0,
    status          VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ck_weekly_snapshots_week CHECK (week_number >= 1 AND week_number <= 6),
    CONSTRAINT ck_weekly_snapshots_status CHECK (status IN ('UNDER', 'OVER', 'IN_PROGRESS')),
    CONSTRAINT uk_weekly_snapshots UNIQUE (couple_id, group_id, year_month, week_number)
);

CREATE INDEX idx_weekly_snapshots_couple_month ON weekly_budget_snapshots (couple_id, year_month);

-- Add budget_period and weekly_amount to monthly_budgets
ALTER TABLE monthly_budgets ADD COLUMN budget_period VARCHAR(10) NOT NULL DEFAULT 'MONTHLY';
ALTER TABLE monthly_budgets ADD COLUMN weekly_amount BIGINT;

ALTER TABLE monthly_budgets ADD CONSTRAINT ck_monthly_budgets_period
    CHECK (budget_period IN ('WEEKLY', 'MONTHLY'));
