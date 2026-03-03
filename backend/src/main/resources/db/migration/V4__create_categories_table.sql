-- Categories per couple (seeded with system defaults on couple creation)
CREATE TABLE categories (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id     UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    name          VARCHAR(50) NOT NULL,
    type          VARCHAR(20) NOT NULL,
    icon          VARCHAR(50),
    color         VARCHAR(7),
    is_default    BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ck_categories_type CHECK (type IN ('INCOME', 'EXPENSE'))
);

CREATE INDEX idx_categories_couple_id ON categories (couple_id);
CREATE INDEX idx_categories_couple_type ON categories (couple_id, type);
