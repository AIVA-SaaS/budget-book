-- Allow zero amount transactions (e.g., free items, zero-cost events)
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS ck_transactions_amount;
ALTER TABLE transactions ADD CONSTRAINT ck_transactions_amount CHECK (amount >= 0);
