-- V30: Add BANK to payment_methods type CHECK constraint
ALTER TABLE payment_methods
    DROP CONSTRAINT ck_payment_methods_type;

ALTER TABLE payment_methods
    ADD CONSTRAINT ck_payment_methods_type
    CHECK (type IN ('CASH', 'DEBIT', 'CREDIT', 'BANK'));
