-- Phase 4 of docs/onboarding-help-plan.md: onboarding instrumentation.
CREATE TABLE IF NOT EXISTS onboarding_events (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event TEXT NOT NULL,
  detail JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_onboarding_events_user_event
  ON onboarding_events (user_id, event);
