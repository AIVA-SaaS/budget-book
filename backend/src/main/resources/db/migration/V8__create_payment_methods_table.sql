-- Payment methods: cash, debit card, credit card tracking
CREATE TABLE payment_methods (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id       UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    name            VARCHAR(100) NOT NULL,
    type            VARCHAR(20) NOT NULL,
    settlement_day  INTEGER,
    closing_day     INTEGER,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    is_default      BOOLEAN NOT NULL DEFAULT FALSE,
    display_order   INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ck_payment_methods_type CHECK (type IN ('CASH', 'DEBIT', 'CREDIT')),
    CONSTRAINT ck_payment_methods_settlement_day CHECK (settlement_day IS NULL OR (settlement_day >= 1 AND settlement_day <= 31)),
    CONSTRAINT ck_payment_methods_closing_day CHECK (closing_day IS NULL OR (closing_day >= 1 AND closing_day <= 31))
);

CREATE INDEX idx_payment_methods_couple_id ON payment_methods (couple_id);

-- Add payment_method_id and settlement_date to transactions
ALTER TABLE transactions ADD COLUMN payment_method_id UUID REFERENCES payment_methods(id) ON DELETE SET NULL;
ALTER TABLE transactions ADD COLUMN settlement_date DATE;

CREATE INDEX idx_transactions_payment_method ON transactions (payment_method_id);
CREATE INDEX idx_transactions_settlement_date ON transactions (settlement_date);
