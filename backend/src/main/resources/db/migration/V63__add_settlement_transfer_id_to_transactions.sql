-- V63: Link card-settlement transfers to the transactions they settle.
--
-- Why: A card settlement is one Transfer(kind=CARD_SETTLEMENT) plus the selected
-- transactions getting paid_at marked. Until now the transfer<->transaction link was
-- never persisted, so editing or deleting a settlement could not re-adjust paid_at,
-- freezing the unpaid total (SUM of Transaction.paid_at IS NULL).
--
-- This column stores which settlement transfer marked each transaction as paid, enabling
-- bidirectional re-adjustment on create/update/delete.
--
-- Existing data: legacy settlements have no link information, so the column stays NULL for
-- them (retroactive re-adjustment is not possible; the fix applies to settlements created
-- or edited from this point on). ON DELETE SET NULL keeps the FK consistent if a transfer
-- row is removed by any path other than the service (which unmarks paid_at explicitly).

ALTER TABLE transactions
    ADD COLUMN settlement_transfer_id UUID NULL REFERENCES transfers(id) ON DELETE SET NULL;

CREATE INDEX idx_transactions_settlement_transfer_id
    ON transactions(settlement_transfer_id);
