CREATE TABLE insurances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id),
  user_id UUID NOT NULL REFERENCES users(id),
  name VARCHAR(100) NOT NULL,
  insurer VARCHAR(100),
  insurance_type VARCHAR(30) NOT NULL,
  premium_amount BIGINT NOT NULL,
  payment_day INT,
  payment_cycle VARCHAR(20) NOT NULL DEFAULT 'MONTHLY',
  payment_method_id UUID REFERENCES payment_methods(id),
  category_id UUID REFERENCES categories(id),
  start_date DATE,
  end_date DATE,
  memo TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  visibility VARCHAR(10) NOT NULL DEFAULT 'SHARED',
  owner_id UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_insurance_type CHECK (insurance_type IN ('LIFE', 'HEALTH', 'CAR', 'FIRE', 'ACCIDENT', 'OTHER')),
  CONSTRAINT ck_insurance_cycle CHECK (payment_cycle IN ('MONTHLY', 'QUARTERLY', 'SEMI_ANNUAL', 'YEARLY')),
  CONSTRAINT ck_insurance_visibility CHECK (visibility IN ('SHARED', 'PRIVATE')),
  CONSTRAINT ck_insurance_payment_day CHECK (payment_day IS NULL OR (payment_day >= 1 AND payment_day <= 31))
);

CREATE INDEX idx_insurances_couple ON insurances(couple_id);
CREATE INDEX idx_insurances_active ON insurances(couple_id, is_active) WHERE is_active = TRUE;
