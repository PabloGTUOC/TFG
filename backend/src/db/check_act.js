import pg from 'pg';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
import dotenv from 'dotenv';
dotenv.config({ path: path.join(__dirname, '../../.env') });

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL || 'postgresql://pablogtorres:postgres@localhost:5432/phototools' });
async function test() {
    try {
        const { rows } = await pool.query("SELECT id, title, status, starts_at, coin_value FROM activities WHERE family_id = 1 AND status = 'completed'");
        console.log(rows);
        const usedRows = await pool.query("SELECT COALESCE(SUM(coin_value), 0)::int as used_this_month FROM activities WHERE family_id = 1 AND status = 'completed' AND starts_at >= date_trunc('month', NOW())");
        console.log("Used this month API Query:", usedRows.rows[0]);
    } catch (e) {
        console.error(e);
    }
    process.exit();
}
test();
