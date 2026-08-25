-- Absence duration floor (docs/personal-time-plan.md Phase 1):
-- an absence now means "away for a day or more". NOT VALID so the shorter
-- absences already stored before this rule existed are grandfathered — they
-- still list and delete, they just cannot be created any more.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'absences_min_duration'
  ) THEN
    ALTER TABLE absences ADD CONSTRAINT absences_min_duration
      CHECK (end_time - start_time >= INTERVAL '24 hours') NOT VALID;
  END IF;
END $$;
