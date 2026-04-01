CREATE TABLE spending_plan_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spending_plan_id UUID NOT NULL REFERENCES spending_plans(id) ON DELETE CASCADE,
    from_status VARCHAR(20),
    to_status VARCHAR(20) NOT NULL,
    changed_by UUID NOT NULL REFERENCES users(id),
    actual_amount BIGINT,
    linked_transaction_id UUID REFERENCES transactions(id),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT ck_status_history_to CHECK (to_status IN ('WISHLIST','PLANNED','COMPLETED','SKIPPED','OVERDUE')),
    CONSTRAINT ck_status_history_from CHECK (from_status IS NULL OR from_status IN ('WISHLIST','PLANNED','COMPLETED','SKIPPED','OVERDUE'))
);

CREATE INDEX idx_status_history_plan_id ON spending_plan_status_history(spending_plan_id);
CREATE INDEX idx_status_history_created_at ON spending_plan_status_history(created_at);
