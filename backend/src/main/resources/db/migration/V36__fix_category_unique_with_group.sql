-- Allow same category name in different groups
-- Before: (couple_id, name, owner_id) → blocks "부모님" in both 생활비 and 기타
-- After: (couple_id, name, group_id, owner_id) → allows same name across groups

DROP INDEX IF EXISTS uk_categories_couple_name_owner;
CREATE UNIQUE INDEX uk_categories_couple_name_group_owner
    ON categories (
        couple_id,
        name,
        COALESCE(group_id, '00000000-0000-0000-0000-000000000000'),
        COALESCE(owner_id, '00000000-0000-0000-0000-000000000000')
    );
