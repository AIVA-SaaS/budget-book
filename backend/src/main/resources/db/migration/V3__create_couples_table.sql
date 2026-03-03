-- Couple relationship between two users
CREATE TABLE couples (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user1_id    UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    user2_id    UUID REFERENCES users(id) ON DELETE RESTRICT,
    status      VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ck_couples_status CHECK (status IN ('PENDING', 'ACTIVE', 'DISSOLVED')),
    CONSTRAINT ck_couples_different_users CHECK (user1_id <> user2_id)
);

CREATE INDEX idx_couples_user1_id ON couples (user1_id);
CREATE INDEX idx_couples_user2_id ON couples (user2_id);

-- Invitation codes for couple linking
CREATE TABLE couple_invitations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inviter_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitation_code VARCHAR(8) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uk_couple_invitations_code UNIQUE (invitation_code),
    CONSTRAINT ck_couple_invitations_status CHECK (status IN ('PENDING', 'ACCEPTED', 'EXPIRED', 'CANCELLED'))
);

CREATE INDEX idx_couple_invitations_inviter_id ON couple_invitations (inviter_id);
CREATE INDEX idx_couple_invitations_expires_at ON couple_invitations (expires_at);
