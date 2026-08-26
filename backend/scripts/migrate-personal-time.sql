-- Personal-time requests (docs/personal-time-plan.md Phase 4).
--
-- Booking personal time always carries a coverage offer to another caretaker,
-- and is only real once they accept. Nothing is scheduled while the request is
-- pending: on acceptance two ordinary activity rows are materialized — the
-- requester's self activity and the accepter's coverage shift — so every
-- existing query over `activities` keeps working untouched.

CREATE TABLE IF NOT EXISTS personal_time_requests (
  id                BIGSERIAL PRIMARY KEY,
  family_id         BIGINT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  requester_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- NULL means "ask anyone": any active caregiver may accept, first one wins.
  requested_of      BIGINT REFERENCES users(id) ON DELETE CASCADE,
  -- Reserved for per-instance renegotiation of a recurring request (Phase 6);
  -- present from the start so adding it later needs no data migration.
  parent_request_id BIGINT REFERENCES personal_time_requests(id) ON DELETE CASCADE,
  title             TEXT NOT NULL,
  type              TEXT NOT NULL CHECK (type IN ('sport', 'social', 'rest', 'appointment', 'other')),
  description       TEXT,
  starts_at         TIMESTAMPTZ NOT NULL,
  ends_at           TIMESTAMPTZ NOT NULL,
  -- False = the dependent needs nobody during this window (gym while the kid is
  -- at daycare). The partner is still told, but there is nothing to accept and
  -- no coins move; such a request is created already 'accepted', with
  -- responded_by NULL to show no one had to answer it.
  coverage_needed   BOOLEAN NOT NULL DEFAULT true,
  baseline_coins    INTEGER NOT NULL DEFAULT 0 CHECK (baseline_coins >= 0),
  sweetener_coins   INTEGER NOT NULL DEFAULT 0 CHECK (sweetener_coins >= 0),
  recurrence        TEXT CHECK (recurrence IN ('daily', 'weekdays', 'weekly')),
  recurrence_until  DATE,
  status            TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'accepted', 'declined', 'expired', 'cancelled')),
  responded_by      BIGINT REFERENCES users(id),
  responded_at      TIMESTAMPTZ,
  expires_at        TIMESTAMPTZ NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_at > starts_at),
  CHECK (ends_at - starts_at <= INTERVAL '24 hours')
);

CREATE INDEX IF NOT EXISTS idx_personal_time_family_status
  ON personal_time_requests (family_id, status, starts_at);
CREATE INDEX IF NOT EXISTS idx_personal_time_requested_of
  ON personal_time_requests (requested_of, status);

-- Which request an activity came from, and the row on the other side of it.
ALTER TABLE activities ADD COLUMN IF NOT EXISTS personal_time_request_id BIGINT
  REFERENCES personal_time_requests(id) ON DELETE SET NULL;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS counterpart_activity_id BIGINT
  REFERENCES activities(id) ON DELETE SET NULL;

ALTER TABLE notification_preferences
  ADD COLUMN IF NOT EXISTS coverage_requests BOOLEAN NOT NULL DEFAULT true;
