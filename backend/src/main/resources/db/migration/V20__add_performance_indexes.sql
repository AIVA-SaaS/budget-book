-- V20: Performance indexes for frequently queried patterns

-- 1. Couples: findByUserIdAndStatus is called on every authenticated API request.
--    Existing idx_couples_user1_id and idx_couples_user2_id only index user IDs alone.
--    Adding composite indexes with status eliminates filter-after-scan overhead.
CREATE INDEX IF NOT EXISTS idx_couples_user1_status ON couples (user1_id, status);
CREATE INDEX IF NOT EXISTS idx_couples_user2_status ON couples (user2_id, status);

-- 2. Transactions: SUM queries filter by (couple_id, type, transaction_date) range.
--    Existing idx_transactions_couple_date covers (couple_id, transaction_date DESC)
--    but doesn't include type, forcing a filter step on each aggregate query.
CREATE INDEX IF NOT EXISTS idx_transactions_couple_type_date
    ON transactions (couple_id, type, transaction_date);

-- 3. Categories: findByCoupleIdAndGroupId is used in weekly budget summary.
--    Existing idx_categories_couple_id and idx_categories_group_id are single-column.
CREATE INDEX IF NOT EXISTS idx_categories_couple_group
    ON categories (couple_id, group_id);

-- 4. Recurring transactions: findByCoupleIdAndIsActiveTrue filters on both columns.
--    Existing idx_recurring_couple only indexes couple_id.
CREATE INDEX IF NOT EXISTS idx_recurring_couple_active
    ON recurring_transactions (couple_id, is_active);

-- 5. Money pockets: findByCoupleIdAndIsActiveTrue with ORDER BY display_order.
--    No composite index exists for this common query.
CREATE INDEX IF NOT EXISTS idx_pockets_couple_active_order
    ON money_pockets (couple_id, is_active, display_order);
