-- V19: Add uniqueness constraints and adjust budget amount constraint
-- NOTE: Deduplicates existing data before creating unique indexes

-- 1. Categories: deduplicate then add unique (couple_id, name)
-- For each set of duplicates, keep the one with the earliest created_at (or smallest id)
-- Reassign all FK references to the "keeper" before deleting duplicates

-- 1a. Reassign transactions.category_id from duplicate → keeper
UPDATE transactions t
SET category_id = keeper.id
FROM categories dup
JOIN LATERAL (
    SELECT id FROM categories c2
    WHERE c2.couple_id = dup.couple_id AND c2.name = dup.name
    ORDER BY c2.created_at, c2.id
    LIMIT 1
) keeper ON true
WHERE t.category_id = dup.id
  AND dup.id != keeper.id
  AND dup.id IN (
      SELECT c3.id FROM categories c3
      JOIN (SELECT couple_id, name FROM categories GROUP BY couple_id, name HAVING COUNT(*) > 1) dups
        ON c3.couple_id = dups.couple_id AND c3.name = dups.name
  );

-- 1b. Reassign monthly_budgets.category_id from duplicate → keeper
UPDATE monthly_budgets mb
SET category_id = keeper.id
FROM categories dup
JOIN LATERAL (
    SELECT id FROM categories c2
    WHERE c2.couple_id = dup.couple_id AND c2.name = dup.name
    ORDER BY c2.created_at, c2.id
    LIMIT 1
) keeper ON true
WHERE mb.category_id = dup.id
  AND dup.id != keeper.id
  AND dup.id IN (
      SELECT c3.id FROM categories c3
      JOIN (SELECT couple_id, name FROM categories GROUP BY couple_id, name HAVING COUNT(*) > 1) dups
        ON c3.couple_id = dups.couple_id AND c3.name = dups.name
  );

-- 1c. Reassign recurring_transactions.category_id from duplicate → keeper
UPDATE recurring_transactions rt
SET category_id = keeper.id
FROM categories dup
JOIN LATERAL (
    SELECT id FROM categories c2
    WHERE c2.couple_id = dup.couple_id AND c2.name = dup.name
    ORDER BY c2.created_at, c2.id
    LIMIT 1
) keeper ON true
WHERE rt.category_id = dup.id
  AND dup.id != keeper.id
  AND dup.id IN (
      SELECT c3.id FROM categories c3
      JOIN (SELECT couple_id, name FROM categories GROUP BY couple_id, name HAVING COUNT(*) > 1) dups
        ON c3.couple_id = dups.couple_id AND c3.name = dups.name
  );

-- 1d. Delete duplicate categories (keep only the earliest per couple+name)
DELETE FROM categories
WHERE id IN (
    SELECT c.id
    FROM categories c
    JOIN (
        SELECT couple_id, name, MIN(created_at) AS min_created, MIN(id) AS min_id
        FROM categories
        GROUP BY couple_id, name
        HAVING COUNT(*) > 1
    ) dups ON c.couple_id = dups.couple_id AND c.name = dups.name
    WHERE (c.created_at > dups.min_created)
       OR (c.created_at = dups.min_created AND c.id > dups.min_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_categories_couple_name
    ON categories (couple_id, name);

-- 2. Payment methods: deduplicate then add unique (couple_id, name)

-- 2a. Reassign transactions.payment_method_id from duplicate → keeper
UPDATE transactions t
SET payment_method_id = keeper.id
FROM payment_methods dup
JOIN LATERAL (
    SELECT id FROM payment_methods pm2
    WHERE pm2.couple_id = dup.couple_id AND pm2.name = dup.name
    ORDER BY pm2.created_at, pm2.id
    LIMIT 1
) keeper ON true
WHERE t.payment_method_id = dup.id
  AND dup.id != keeper.id
  AND dup.id IN (
      SELECT pm3.id FROM payment_methods pm3
      JOIN (SELECT couple_id, name FROM payment_methods GROUP BY couple_id, name HAVING COUNT(*) > 1) dups
        ON pm3.couple_id = dups.couple_id AND pm3.name = dups.name
  );

-- 2b. Reassign recurring_transactions.payment_method_id from duplicate → keeper
UPDATE recurring_transactions rt
SET payment_method_id = keeper.id
FROM payment_methods dup
JOIN LATERAL (
    SELECT id FROM payment_methods pm2
    WHERE pm2.couple_id = dup.couple_id AND pm2.name = dup.name
    ORDER BY pm2.created_at, pm2.id
    LIMIT 1
) keeper ON true
WHERE rt.payment_method_id = dup.id
  AND dup.id != keeper.id
  AND dup.id IN (
      SELECT pm3.id FROM payment_methods pm3
      JOIN (SELECT couple_id, name FROM payment_methods GROUP BY couple_id, name HAVING COUNT(*) > 1) dups
        ON pm3.couple_id = dups.couple_id AND pm3.name = dups.name
  );

-- 2c. Delete duplicate payment methods
DELETE FROM payment_methods
WHERE id IN (
    SELECT pm.id
    FROM payment_methods pm
    JOIN (
        SELECT couple_id, name, MIN(created_at) AS min_created, MIN(id) AS min_id
        FROM payment_methods
        GROUP BY couple_id, name
        HAVING COUNT(*) > 1
    ) dups ON pm.couple_id = dups.couple_id AND pm.name = dups.name
    WHERE (pm.created_at > dups.min_created)
       OR (pm.created_at = dups.min_created AND pm.id > dups.min_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_payment_methods_couple_name
    ON payment_methods (couple_id, name);

-- 3. Budgets: allow zero amount (change from amount > 0 to amount >= 0)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name = 'monthly_budgets_amount_check'
    ) THEN
        ALTER TABLE monthly_budgets DROP CONSTRAINT monthly_budgets_amount_check;
    END IF;
END $$;

ALTER TABLE monthly_budgets ADD CONSTRAINT ck_monthly_budgets_amount CHECK (amount >= 0);
