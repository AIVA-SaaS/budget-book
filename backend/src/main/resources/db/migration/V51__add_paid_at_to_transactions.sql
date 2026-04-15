-- Add paid_at column to transactions to track when a card transaction is settled.
-- NULL = not paid (still in settlement queue)
-- Not NULL = paid on this date via card settlement transfer
ALTER TABLE transactions ADD COLUMN paid_at DATE;

-- Partial index for fast "unpaid" queries on credit card settlements
CREATE INDEX idx_transactions_paid_at_null ON transactions (payment_method_id, settlement_date)
    WHERE paid_at IS NULL;
