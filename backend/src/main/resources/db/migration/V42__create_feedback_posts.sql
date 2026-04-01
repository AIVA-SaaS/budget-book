CREATE TABLE feedback_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  category VARCHAR(20) NOT NULL,
  title VARCHAR(200) NOT NULL,
  content TEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'SUBMITTED',
  admin_note TEXT,
  resolved_release_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_feedback_category CHECK (category IN ('BUG', 'IMPROVEMENT', 'FEATURE', 'OTHER')),
  CONSTRAINT ck_feedback_status CHECK (status IN ('SUBMITTED', 'REVIEWING', 'IN_PROGRESS', 'RESOLVED', 'REJECTED'))
);

CREATE INDEX idx_feedback_user ON feedback_posts(user_id, created_at DESC);
CREATE INDEX idx_feedback_status ON feedback_posts(status);
