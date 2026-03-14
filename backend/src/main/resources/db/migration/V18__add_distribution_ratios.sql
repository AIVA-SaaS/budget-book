CREATE TABLE distribution_ratios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES couples(id),
    pocket_id UUID NOT NULL REFERENCES money_pockets(id),
    ratio DECIMAL(5,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(couple_id, pocket_id)
);
