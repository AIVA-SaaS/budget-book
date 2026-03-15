CREATE TABLE announcements (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title       VARCHAR(200) NOT NULL,
    content     TEXT NOT NULL,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_by  UUID REFERENCES users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_announcements_is_active ON announcements (is_active);
CREATE INDEX idx_announcements_created_at ON announcements (created_at DESC);
