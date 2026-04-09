import pg from 'pg';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
import dotenv from 'dotenv';
dotenv.config({ path: path.join(__dirname, '../../.env') });

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL || 'postgresql://pablogtorres:postgres@localhost:5432/phototools' });
async function test() {
    try {
        const { rows: caregiversList } = await pool.query(
            `SELECT COALESCE(fm.alias, u.display_name, 'Unknown') as name, fm.role, fm.status
         FROM family_members fm
         JOIN users u ON u.id = fm.user_id
         WHERE fm.family_id = 1`
        );
        console.log("Family Members Table (ID 1):", caregiversList);
    } catch (e) {
        console.error(e);
    }
    process.exit();
}
test();
