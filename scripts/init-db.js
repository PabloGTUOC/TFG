import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool } from '../src/db/pool.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
  const sqlPath = path.join(__dirname, '../src/db/schema.sql');
  const sql = await fs.readFile(sqlPath, 'utf8');
  await pool.query(sql);
  console.log('Database schema initialized.');
  await pool.end();
}

main().catch((error) => {
  console.error('Failed to initialize database schema:', error);
  process.exitCode = 1;
});
