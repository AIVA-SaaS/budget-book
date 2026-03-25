-- System account for auto-settlement transfers
-- role must be 'USER' per chk_users_role constraint (V21)
-- is_active added in V21, defaults to true
INSERT INTO users (id, email, nickname, provider, provider_id, role, created_at, updated_at)
VALUES ('00000000-0000-0000-0000-000000000001', 'system@budgetbook.internal', '자동결제', 'SYSTEM', 'SYSTEM', 'USER', NOW(), NOW())
ON CONFLICT DO NOTHING;

-- Auto-settlement deduplication key on transfers table
ALTER TABLE transfers ADD COLUMN auto_settlement_key VARCHAR(100);
CREATE UNIQUE INDEX idx_transfers_auto_settlement_key ON transfers(auto_settlement_key) WHERE auto_settlement_key IS NOT NULL;
