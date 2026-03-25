CREATE TABLE transfers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id       UUID NOT NULL REFERENCES couples(id),
    author_id       UUID NOT NULL REFERENCES users(id),
    source_payment_method_id      UUID NOT NULL REFERENCES payment_methods(id),
    destination_payment_method_id UUID NOT NULL REFERENCES payment_methods(id),
    amount          BIGINT NOT NULL CHECK (amount > 0),
    description     VARCHAR(255),
    memo            TEXT,
    transfer_date   DATE NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_different_methods CHECK (source_payment_method_id != destination_payment_method_id)
);

CREATE INDEX idx_transfers_couple_date ON transfers(couple_id, transfer_date);
CREATE INDEX idx_transfers_source ON transfers(source_payment_method_id);
CREATE INDEX idx_transfers_dest ON transfers(destination_payment_method_id);
