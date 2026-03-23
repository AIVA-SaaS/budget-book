-- V25: Allow same category name in different groups
-- Previously: UNIQUE(couple_id, name) prevented "용돈" in both "개인 항목" and "고정지출"
-- Now: UNIQUE(couple_id, name, group_id) allows same name across different groups
-- Uses COALESCE for NULL group_id (ungrouped categories remain unique by name)

DROP INDEX IF EXISTS uk_categories_couple_name;

CREATE UNIQUE INDEX uk_categories_couple_name_group
    ON categories (couple_id, name, COALESCE(group_id, '00000000-0000-0000-0000-000000000000'));
