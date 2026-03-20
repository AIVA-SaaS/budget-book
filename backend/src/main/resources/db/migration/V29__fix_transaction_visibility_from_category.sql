-- V29: Fix transaction visibility to match category visibility
-- Transactions should always inherit visibility from their category.
-- This fixes records where transactions were incorrectly saved as PRIVATE
-- while their category is SHARED.

UPDATE transactions t
SET visibility = 'SHARED',
    owner_id = NULL
FROM categories c
WHERE t.category_id = c.id
  AND c.visibility = 'SHARED'
  AND t.visibility = 'PRIVATE';
