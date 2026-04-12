CREATE TABLE feedback_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES feedback_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_feedback_votes_post_user UNIQUE (post_id, user_id)
);
CREATE INDEX idx_feedback_votes_post ON feedback_votes(post_id);

ALTER TABLE feedback_posts ADD COLUMN vote_count INT NOT NULL DEFAULT 0;
