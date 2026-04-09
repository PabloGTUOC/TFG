import pg from 'pg';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
import dotenv from 'dotenv';
dotenv.config({ path: path.join(__dirname, '../../.env') });

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL || 'postgresql://pablogtorres:postgres@localhost:5432/phototools' });
async function test() {
    try {
        const { rows: trendByMonth } = await pool.query(
            `SELECT 
           COALESCE(fm.alias, u.display_name, 'Unknown') as caregiver,
           to_char(starts_at AT TIME ZONE 'UTC', 'YYYY-MM') as month,
           COALESCE(SUM(coin_value), 0)::int as coins,
           COUNT(*)::int as tasks
         FROM activities a
         JOIN family_members fm ON fm.user_id = a.assigned_to AND fm.family_id = a.family_id
         JOIN users u ON u.id = a.assigned_to
         WHERE a.family_id = 1 AND a.status = 'completed'
         GROUP BY caregiver, month
         ORDER BY month ASC
         LIMIT 100`
        );

        const set = new Set();
        trendByMonth.forEach(t => set.add(t.caregiver));
        console.log("Caregivers found:", Array.from(set));
    } catch (e) {
        console.error(e);
    }
    process.exit();
}
test();
