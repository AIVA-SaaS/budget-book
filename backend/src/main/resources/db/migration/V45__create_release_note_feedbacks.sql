CREATE TABLE release_note_feedbacks (
  release_note_id UUID NOT NULL REFERENCES release_notes(id) ON DELETE CASCADE,
  feedback_post_id UUID NOT NULL REFERENCES feedback_posts(id) ON DELETE CASCADE,
  PRIMARY KEY (release_note_id, feedback_post_id)
);
