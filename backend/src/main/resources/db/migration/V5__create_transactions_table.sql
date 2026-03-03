-- Income and expense transactions recorded by couple members
CREATE TABLE transactions (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id        UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    author_id        UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    category_id      UUID REFERENCES categories(id) ON DELETE SET NULL,
    type             VARCHAR(20) NOT NULL,
    amount           BIGINT NOT NULL,
    description      VARCHAR(255) NOT NULL,
    memo             TEXT,
    transaction_date DATE NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ck_transactions_type CHECK (type IN ('INCOME', 'EXPENSE')),
    CONSTRAINT ck_transactions_amount CHECK (amount > 0)
);

CREATE INDEX idx_transactions_couple_id ON transactions (couple_id);
CREATE INDEX idx_transactions_couple_date ON transactions (couple_id, transaction_date DESC);
CREATE INDEX idx_transactions_couple_type ON transactions (couple_id, type);
CREATE INDEX idx_transactions_category_id ON transactions (category_id);
CREATE INDEX idx_transactions_author_id ON transactions (author_id);
