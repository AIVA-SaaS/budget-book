-- Add FK indexes on pocket_transfers for join performance
CREATE INDEX IF NOT EXISTS idx_pocket_transfers_from_pocket ON pocket_transfers(from_pocket_id);
CREATE INDEX IF NOT EXISTS idx_pocket_transfers_to_pocket ON pocket_transfers(to_pocket_id);
CREATE INDEX IF NOT EXISTS idx_pocket_transfers_author ON pocket_transfers(author_id);
