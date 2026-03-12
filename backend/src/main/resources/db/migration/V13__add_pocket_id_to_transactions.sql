ALTER TABLE transactions ADD COLUMN pocket_id UUID REFERENCES money_pockets(id) ON DELETE SET NULL;
CREATE INDEX idx_transactions_pocket ON transactions(pocket_id);
