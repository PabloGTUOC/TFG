import { pool } from './src/db/pool.js';
async function check() {
  const { rows } = await pool.query("SELECT id, title, starts_at, status FROM activities WHERE assigned_to = 1 ORDER BY starts_at DESC LIMIT 10");
  console.log(rows);
  process.exit();
}
check();
