import pg from 'pg';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
import dotenv from 'dotenv';
dotenv.config({ path: path.join(__dirname, '../../.env') });

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL || 'postgresql://pablogtorres:postgres@localhost:5432/phototools' });
async function migrate() {
    try {
        await pool.query(`ALTER TABLE families ADD COLUMN last_coin_distribution_month VARCHAR(7)`);
        console.log("Migration successful.");
    } catch (e) {
        if (e.code === '42701') console.log("Column already exists.");
        else console.error(e);
    }
    process.exit();
}
migrate();
