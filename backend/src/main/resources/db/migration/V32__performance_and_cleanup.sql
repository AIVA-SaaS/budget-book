-- V32: Performance indexes
--
-- P4-4: pg_trgm GIN index on transactions.description for autocomplete
-- P4-5: Missing composite indexes on couple_invitations and monthly_budgets

-- ============================================================
-- P4-4: pg_trgm index for description autocomplete
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_transactions_description_trgm
    ON transactions USING GIN (description gin_trgm_ops);

-- ============================================================
-- P4-5: Missing composite indexes
-- ============================================================

-- Speeds up invitation lookups by inviter filtered by status
CREATE INDEX IF NOT EXISTS idx_couple_invitations_inviter_status
    ON couple_invitations (inviter_id, status);

-- Speeds up budget queries filtered by visibility + owner
CREATE INDEX IF NOT EXISTS idx_monthly_budgets_visibility_owner
    ON monthly_budgets (visibility, owner_id);
