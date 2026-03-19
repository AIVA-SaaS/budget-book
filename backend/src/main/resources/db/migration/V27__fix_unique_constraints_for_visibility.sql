-- V27: Fix unique constraints to support PRIVATE visibility
-- PRIVATE categories/payment_methods can have the same name per user within a couple

-- 1. Categories: (couple_id, name) → (couple_id, name, COALESCE(owner_id, sentinel))
-- This allows: couple has SHARED "식비" + user1 PRIVATE "용돈" + user2 PRIVATE "용돈"
DROP INDEX IF EXISTS uk_categories_couple_name;
CREATE UNIQUE INDEX uk_categories_couple_name_owner
    ON categories (
        couple_id,
        name,
        COALESCE(owner_id, '00000000-0000-0000-0000-000000000000')
    );

-- 2. Payment methods: same pattern
DROP INDEX IF EXISTS uk_payment_methods_couple_name;
CREATE UNIQUE INDEX uk_payment_methods_couple_name_owner
    ON payment_methods (
        couple_id,
        name,
        COALESCE(owner_id, '00000000-0000-0000-0000-000000000000')
    );
