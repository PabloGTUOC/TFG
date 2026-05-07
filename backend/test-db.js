import { Pool } from 'pg';
const pool = new Pool({ connectionString: 'postgres://carecoins:carecoins@localhost:5433/carecoins' });
async function run() {
  const { rows } = await pool.query("SELECT id, title, starts_at, status, assigned_to FROM activities WHERE starts_at >= '2026-05-06' AND starts_at < '2026-05-07';");
  console.log(rows);
  process.exit(0);
}
run();
