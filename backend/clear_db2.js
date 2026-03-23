import { pool } from './src/db/pool.js';
async function run() {
    await pool.query('TRUNCATE activities CASCADE');
    await pool.query('TRUNCATE coin_ledger CASCADE');
    console.log('Database activities cleared.');
    process.exit(0);
}
run().catch(console.error);
