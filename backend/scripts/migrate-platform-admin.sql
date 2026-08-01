-- Platform admin foundation (docs/admin-family-management-plan.md Phase 1):
-- global role on users + audit trail for every mutating admin action.

ALTER TABLE users ADD COLUMN IF NOT EXISTS platform_role TEXT NOT NULL DEFAULT 'user';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_platform_role_check'
  ) THEN
    ALTER TABLE users ADD CONSTRAINT users_platform_role_check
      CHECK (platform_role IN ('user', 'admin'));
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS admin_audit_log (
  id BIGSERIAL PRIMARY KEY,
  admin_id BIGINT NOT NULL REFERENCES users(id),
  action TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT,
  payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin_time
  ON admin_audit_log (admin_id, created_at);
