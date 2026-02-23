CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  firebase_uid TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE,
  display_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS families (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  monthly_coin_budget INTEGER NOT NULL DEFAULT 1000 CHECK (monthly_coin_budget > 0),
  created_by BIGINT NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS family_members (
  id BIGSERIAL PRIMARY KEY,
  family_id BIGINT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('main_caregiver', 'caregiver', 'member')),
  coin_balance INTEGER NOT NULL DEFAULT 0,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (family_id, user_id)
);

CREATE TABLE IF NOT EXISTS activities (
  id BIGSERIAL PRIMARY KEY,
  family_id BIGINT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  created_by BIGINT NOT NULL REFERENCES users(id),
  assigned_to BIGINT NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('care', 'household')),
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes >= 15),
  coin_value INTEGER NOT NULL CHECK (coin_value >= 0),
  status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
  approved_by BIGINT REFERENCES users(id),
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_at > starts_at)
);

CREATE TABLE IF NOT EXISTS coin_ledger (
  id BIGSERIAL PRIMARY KEY,
  family_id BIGINT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  activity_id BIGINT REFERENCES activities(id) ON DELETE SET NULL,
  amount INTEGER NOT NULL,
  reason TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activities_assignee_period ON activities (assigned_to, starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_activities_family_status ON activities (family_id, status);
