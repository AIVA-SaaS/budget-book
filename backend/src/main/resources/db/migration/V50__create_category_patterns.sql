CREATE TABLE category_patterns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    keyword VARCHAR(100) NOT NULL,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    frequency INT NOT NULL DEFAULT 1,
    last_used_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_category_pattern UNIQUE (couple_id, keyword, category_id)
);
CREATE INDEX idx_category_patterns_couple_keyword ON category_patterns(couple_id, keyword);
