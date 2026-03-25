ALTER TABLE payment_methods
ADD COLUMN linked_bank_id UUID REFERENCES payment_methods(id);
