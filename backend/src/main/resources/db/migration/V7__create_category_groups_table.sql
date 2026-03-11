-- Category Groups: hierarchical grouping for categories
-- Groups like "생활비", "고정지출", "기타" contain multiple categories
CREATE TABLE category_groups (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id     UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    name          VARCHAR(50) NOT NULL,
    icon          VARCHAR(50),
    color         VARCHAR(7),
    budget_type   VARCHAR(20) NOT NULL DEFAULT 'MONTHLY',
    display_order INTEGER NOT NULL DEFAULT 0,
    is_default    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ck_category_groups_budget_type CHECK (budget_type IN ('WEEKLY', 'MONTHLY', 'NONE'))
);

CREATE INDEX idx_category_groups_couple_id ON category_groups (couple_id);

-- Add group_id to categories (nullable for backward compatibility)
ALTER TABLE categories ADD COLUMN group_id UUID REFERENCES category_groups(id) ON DELETE SET NULL;
CREATE INDEX idx_categories_group_id ON categories (group_id);
