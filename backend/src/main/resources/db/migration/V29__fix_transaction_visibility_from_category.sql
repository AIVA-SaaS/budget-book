-- V29: Fix transaction visibility to always match category visibility.
-- Transactions should inherit visibility from their category, not be set independently.

-- Case 1: SHARED category but PRIVATE transaction → fix to SHARED
UPDATE transactions t
SET visibility = 'SHARED',
    owner_id = NULL
FROM categories c
WHERE t.category_id = c.id
  AND c.visibility = 'SHARED'
  AND t.visibility = 'PRIVATE';

-- Case 2: PRIVATE category but SHARED transaction → fix to PRIVATE (set owner = author)
UPDATE transactions t
SET visibility = 'PRIVATE',
    owner_id = t.author_id
FROM categories c
WHERE t.category_id = c.id
  AND c.visibility = 'PRIVATE'
  AND t.visibility = 'SHARED';

-- Case 3: No category (NULL) but PRIVATE → fix to SHARED (no category = shared by default)
UPDATE transactions
SET visibility = 'SHARED',
    owner_id = NULL
WHERE category_id IS NULL
  AND visibility = 'PRIVATE';
