-- Activity subclasses (docs/personal-time-plan.md Phase 3).
--
-- `category` used to answer two questions at once: is this a contribution at
-- all, and what kind of contribution is it. Those are now two columns:
--
--   category = 'care'  → work for the family;  type ∈ ('care', 'household')
--   category = 'self'  → personal time;        type ∈ ('sport', 'social',
--                                                      'rest', 'appointment',
--                                                      'other'), worth 0 coins
--
-- Existing rows are all care work, so the transformation is a rename plus a
-- defaulted column — no backfill, no data migration.
--
-- Idempotent, and safe from any of three starting shapes: a database created
-- from the current schema.sql (nothing to do), one predating the subclasses
-- (`category` still holds care/household), and one that ran the interim
-- revision of this file, which called the subclass `kind`.

-- 1. What `category` holds today is what is now called `type`.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name = 'activities' AND column_name = 'category')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name = 'activities' AND column_name = 'type') THEN
    ALTER TABLE activities DROP CONSTRAINT IF EXISTS activities_category_check;
    ALTER TABLE activities RENAME COLUMN category TO type;
  END IF;
END $$;

-- 2. The interim revision called the subclass `kind`.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name = 'activities' AND column_name = 'kind')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name = 'activities' AND column_name = 'category') THEN
    ALTER TABLE activities RENAME COLUMN kind TO category;
  END IF;
END $$;

-- 3. The subclass itself, and the note a self activity carries.
--    DEFAULT 'care' makes every existing row correct with no backfill.
ALTER TABLE activities ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'care';
ALTER TABLE activities ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE activities ALTER COLUMN type SET NOT NULL;

-- 4. One vocabulary per category. Both columns are NOT NULL, which is what
--    keeps this from evaluating to NULL: a CHECK rejects only on false, so a
--    nullable column would let an unmatched row through instead of failing.
DO $$
BEGIN
  ALTER TABLE activities DROP CONSTRAINT IF EXISTS activities_category_check;
  ALTER TABLE activities DROP CONSTRAINT IF EXISTS activities_kind_category_check;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                 WHERE conname = 'activities_category_type_check') THEN
    ALTER TABLE activities ADD CONSTRAINT activities_category_type_check CHECK (
      (category = 'care' AND type IN ('care', 'household')) OR
      (category = 'self' AND coin_value = 0
                         AND type IN ('sport', 'social', 'rest', 'appointment', 'other'))
    );
  END IF;
END $$;

-- 5. Every aggregate that counts work filters on category, so it is worth an index.
DROP INDEX IF EXISTS idx_activities_family_kind_status;
CREATE INDEX IF NOT EXISTS idx_activities_family_category_status
  ON activities (family_id, category, status);
