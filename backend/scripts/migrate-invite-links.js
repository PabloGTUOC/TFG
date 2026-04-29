import '../src/env.js';
import pg from 'pg';

const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const sql = `
  CREATE TABLE IF NOT EXISTS invite_links (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    family_id  BIGINT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    created_by BIGINT NOT NULL REFERENCES users(id),
    max_uses   INTEGER,
    uses       INTEGER NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ,
    revoked    BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );

  CREATE INDEX IF NOT EXISTS idx_invite_links_family ON invite_links (family_id);
`;

const client = await pool.connect();
try {
  await client.query(sql);
  console.log('invite_links table ready.');
} finally {
  client.release();
  await pool.end();
}