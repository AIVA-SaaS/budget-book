-- Add is_self flag to distinguish self-couples from real couples
ALTER TABLE couples ADD COLUMN is_self BOOLEAN NOT NULL DEFAULT FALSE;

-- Backfill: create self-couples for existing users without an active couple
INSERT INTO couples (id, user1_id, user2_id, status, is_self, created_at, updated_at)
SELECT gen_random_uuid(), u.id, NULL, 'ACTIVE', TRUE, NOW(), NOW()
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM couples c
    WHERE (c.user1_id = u.id OR c.user2_id = u.id)
    AND c.status = 'ACTIVE'
);

-- Index for efficient self-couple lookup
CREATE INDEX idx_couples_user1_is_self ON couples (user1_id, is_self) WHERE status = 'ACTIVE';
