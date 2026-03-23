import { pool } from './src/db/pool.js';
async function test() {
  const { rows } = await pool.query('SELECT * FROM users');
  console.log('Users:', rows);
  process.exit();
}
test();
