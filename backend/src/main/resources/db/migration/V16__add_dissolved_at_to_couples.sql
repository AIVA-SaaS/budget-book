-- Add dissolved_at timestamp for soft-delete dissolution tracking
ALTER TABLE couples ADD COLUMN dissolved_at TIMESTAMPTZ;

-- Backfill dissolved_at for already dissolved couples using updated_at as approximation
UPDATE couples SET dissolved_at = updated_at WHERE status = 'DISSOLVED' AND dissolved_at IS NULL;

CREATE INDEX idx_couples_dissolved_at ON couples (dissolved_at) WHERE dissolved_at IS NOT NULL;
