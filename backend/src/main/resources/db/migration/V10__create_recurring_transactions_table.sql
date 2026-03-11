CREATE TABLE recurring_transactions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id       UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    author_id       UUID NOT NULL REFERENCES users(id),
    category_id     UUID REFERENCES categories(id) ON DELETE SET NULL,
    payment_method_id UUID REFERENCES payment_methods(id) ON DELETE SET NULL,
    type            VARCHAR(20) NOT NULL,
    amount          BIGINT NOT NULL,
    description     VARCHAR(255) NOT NULL,
    memo            TEXT,
    frequency       VARCHAR(20) NOT NULL,
    day_of_month    INTEGER,
    day_of_week     INTEGER,
    next_run_date   DATE NOT NULL,
    last_run_date   DATE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ck_recurring_type CHECK (type IN ('INCOME', 'EXPENSE')),
    CONSTRAINT ck_recurring_frequency CHECK (frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY')),
    CONSTRAINT ck_recurring_day_of_month CHECK (day_of_month IS NULL OR (day_of_month >= 1 AND day_of_month <= 31)),
    CONSTRAINT ck_recurring_day_of_week CHECK (day_of_week IS NULL OR (day_of_week >= 1 AND day_of_week <= 7)),
    CONSTRAINT ck_recurring_amount CHECK (amount > 0)
);

CREATE INDEX idx_recurring_couple ON recurring_transactions (couple_id);
CREATE INDEX idx_recurring_next_run ON recurring_transactions (next_run_date, is_active);
