import { pool } from './src/db/pool.js';
async function test() {
  try {
    const { rows } = await pool.query(`SELECT id, title, category, starts_at, ends_at, duration_minutes, coin_value, status, created_by, assigned_to FROM activities WHERE family_id = 1 ORDER BY starts_at ASC`);
    console.log("Success:", rows);
  } catch(e) {
    console.error("SQL Error:", e);
  }
  process.exit(0);
}
test();
