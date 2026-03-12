CREATE TABLE pocket_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES couples(id),
    from_pocket_id UUID NOT NULL REFERENCES money_pockets(id),
    to_pocket_id UUID NOT NULL REFERENCES money_pockets(id),
    amount BIGINT NOT NULL CHECK (amount > 0),
    description VARCHAR(255),
    transfer_date DATE NOT NULL,
    author_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_pocket_transfers_couple ON pocket_transfers(couple_id);
CREATE INDEX idx_pocket_transfers_date ON pocket_transfers(transfer_date);
