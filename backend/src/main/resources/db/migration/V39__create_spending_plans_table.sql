CREATE TABLE spending_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id),
  author_id UUID NOT NULL REFERENCES users(id),
  name VARCHAR(100) NOT NULL,
  amount BIGINT NOT NULL,
  target_date DATE NOT NULL,
  memo TEXT,
  category_id UUID REFERENCES categories(id),
  payment_method_id UUID REFERENCES payment_methods(id),
  budget_id UUID REFERENCES monthly_budgets(id),
  linked_transaction_id UUID REFERENCES transactions(id),
  status VARCHAR(20) NOT NULL DEFAULT 'PLANNED',
  actual_amount BIGINT,
  completed_date DATE,
  is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
  frequency VARCHAR(20),
  recurring_source_id UUID REFERENCES spending_plans(id),
  visibility VARCHAR(10) NOT NULL DEFAULT 'SHARED',
  owner_id UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_spending_plan_status CHECK (status IN ('PLANNED', 'COMPLETED', 'SKIPPED', 'OVERDUE')),
  CONSTRAINT ck_spending_plan_visibility CHECK (visibility IN ('SHARED', 'PRIVATE')),
  CONSTRAINT ck_spending_plan_frequency CHECK (frequency IS NULL OR frequency IN ('WEEKLY', 'MONTHLY'))
);

CREATE INDEX idx_spending_plans_couple_date ON spending_plans(couple_id, target_date);
CREATE INDEX idx_spending_plans_budget ON spending_plans(budget_id) WHERE budget_id IS NOT NULL;
CREATE INDEX idx_spending_plans_status ON spending_plans(couple_id, status) WHERE status = 'PLANNED';
