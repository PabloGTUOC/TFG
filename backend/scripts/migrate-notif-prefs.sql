CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id           BIGINT  PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  activity_assigned BOOLEAN NOT NULL DEFAULT true,
  activity_validated BOOLEAN NOT NULL DEFAULT true,
  activity_completed BOOLEAN NOT NULL DEFAULT true,
  bounty_offered    BOOLEAN NOT NULL DEFAULT true,
  family_events     BOOLEAN NOT NULL DEFAULT true
);
