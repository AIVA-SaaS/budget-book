CREATE TABLE money_pockets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES couples(id),
    name VARCHAR(50) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('LIVING', 'FIXED', 'CARD_PENDING', 'SAVINGS', 'CUSTOM')),
    allocated_amount BIGINT NOT NULL DEFAULT 0,
    icon VARCHAR(50),
    color VARCHAR(7),
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_money_pockets_couple ON money_pockets(couple_id);
