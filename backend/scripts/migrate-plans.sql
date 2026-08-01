-- Plan / entitlement model (docs/admin-family-management-plan.md Phase 3).
-- Provider-agnostic: store billing (Phase 4) and admin grants both resolve
-- into these tables; clients only ever read entitlements from our API.

CREATE TABLE IF NOT EXISTS plans (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  price_cents INTEGER NOT NULL DEFAULT 0 CHECK (price_cents >= 0),
  currency TEXT NOT NULL DEFAULT 'EUR',
  billing_period TEXT NOT NULL DEFAULT 'monthly' CHECK (billing_period IN ('monthly', 'yearly')),
  limits JSONB NOT NULL DEFAULT '{}',   -- max_members, max_actors, max_active_rewards…; absent key = unlimited
  features JSONB NOT NULL DEFAULT '{}',
  is_default BOOLEAN NOT NULL DEFAULT false,
  active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS family_plans (
  family_id BIGINT PRIMARY KEY REFERENCES families(id) ON DELETE CASCADE,
  plan_code TEXT NOT NULL REFERENCES plans(code),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN
    ('trialing', 'active', 'in_grace', 'past_due', 'paused', 'canceled', 'expired')),
  current_period_end TIMESTAMPTZ,
  platform TEXT,                        -- 'app_store' | 'play' | future 'stripe'
  provider TEXT,                        -- 'system' | 'revenuecat' | …
  provider_subscription_id TEXT,
  billing_owner_user_id BIGINT REFERENCES users(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Raw provider webhook log: idempotency (event_id UNIQUE) + debugging.
CREATE TABLE IF NOT EXISTS billing_events (
  id BIGSERIAL PRIMARY KEY,
  provider TEXT NOT NULL,
  event_id TEXT UNIQUE,
  event_type TEXT NOT NULL,
  family_id BIGINT REFERENCES families(id) ON DELETE SET NULL,
  payload JSONB NOT NULL,
  processed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_billing_events_family ON billing_events (family_id, created_at);

-- Comps/trials issued by platform admins. Deliberately separate from
-- family_plans so store truth and admin truth never overwrite each other;
-- revocation is a timestamp, not a delete, to keep the trail.
CREATE TABLE IF NOT EXISTS admin_grants (
  id BIGSERIAL PRIMARY KEY,
  family_id BIGINT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  plan_code TEXT NOT NULL REFERENCES plans(code),
  granted_by BIGINT NOT NULL REFERENCES users(id),
  reason TEXT,
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_grants_family ON admin_grants (family_id);

-- Seed the default plan. Free ships with no limits (absent key = unlimited)
-- so rollout changes nothing for existing families; tighten via the admin
-- plan API once paid tiers exist.
INSERT INTO plans (code, name, price_cents, is_default)
VALUES ('free', 'Free', 0, true)
ON CONFLICT (code) DO NOTHING;

-- Backfill: every existing family is on the default plan.
INSERT INTO family_plans (family_id, plan_code, provider)
SELECT f.id, 'free', 'system' FROM families f
ON CONFLICT (family_id) DO NOTHING;
