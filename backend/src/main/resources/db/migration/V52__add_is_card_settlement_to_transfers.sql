-- Add is_card_settlement flag to transfers.
-- true = this transfer is a card payment (bank → card) and should be EXCLUDED
--        from spending statistics to prevent double-counting with the original
--        card transactions it settles.
-- false = regular transfer (internal money movement between accounts)
ALTER TABLE transfers ADD COLUMN is_card_settlement BOOLEAN NOT NULL DEFAULT FALSE;

-- Index for fast filtering of non-settlement transfers in statistics queries
CREATE INDEX idx_transfers_is_card_settlement ON transfers (is_card_settlement, transfer_date);
