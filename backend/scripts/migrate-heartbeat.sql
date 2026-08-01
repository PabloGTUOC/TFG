-- Family heartbeat (docs/admin-family-management-plan.md Phase 2):
-- explicit liveness timestamp so the admin registry never has to derive
-- activity by querying family content tables.

ALTER TABLE families ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;

-- One-time backfill from existing timestamps; after this, the column is only
-- ever touched by the heartbeat middleware.
UPDATE families f SET last_active_at = GREATEST(
  f.created_at,
  COALESCE((SELECT MAX(a.created_at)  FROM activities a      WHERE a.family_id  = f.id), f.created_at),
  COALESCE((SELECT MAX(cl.created_at) FROM coin_ledger cl    WHERE cl.family_id = f.id), f.created_at),
  COALESCE((SELECT MAX(fm.joined_at)  FROM family_members fm WHERE fm.family_id = f.id), f.created_at)
) WHERE f.last_active_at IS NULL;

ALTER TABLE families ALTER COLUMN last_active_at SET DEFAULT NOW();
ALTER TABLE families ALTER COLUMN last_active_at SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_families_last_active ON families (last_active_at);
