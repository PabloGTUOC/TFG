-- Activity subclasses (docs/personal-time-plan.md Phase 3).
--
-- `category` used to answer two different questions at once: is this a
-- contribution at all, and what kind of contribution is it. `kind` now carries
-- the first — 'care' is work for the family, 'self' is personal time — and
-- `category` becomes a property of the care subclass only.
--
-- DEFAULT 'care' makes every existing row correct with no backfill.

ALTER TABLE activities ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'care';
ALTER TABLE activities ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE activities ALTER COLUMN category DROP NOT NULL;

DO $$
BEGIN
  -- The inline CHECK from the original CREATE TABLE, superseded below.
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'activities_category_check') THEN
    ALTER TABLE activities DROP CONSTRAINT activities_category_check;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'activities_kind_category_check') THEN
    -- `category IS NOT NULL` is load-bearing: without it a care row with a null
    -- category makes the first branch NULL rather than false, and a CHECK only
    -- rejects on false, so the row would slip through.
    ALTER TABLE activities ADD CONSTRAINT activities_kind_category_check CHECK (
      (kind = 'care' AND category IS NOT NULL AND category IN ('care', 'household')) OR
      (kind = 'self' AND category IS NULL AND coin_value = 0)
    );
  END IF;
END $$;

-- Every aggregate that counts work filters on kind, so it is worth an index.
CREATE INDEX IF NOT EXISTS idx_activities_family_kind_status
  ON activities (family_id, kind, status);
