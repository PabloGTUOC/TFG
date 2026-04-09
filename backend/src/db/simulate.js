import pg from 'pg';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
import dotenv from 'dotenv';
dotenv.config({ path: path.join(__dirname, '../../.env') });

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL || 'postgresql://pablogtorres:postgres@localhost:5432/phototools' });
async function test() {
    try {
        const { rows: usedRows } = await pool.query(`SELECT COALESCE(SUM(coin_value), 0)::int as used_this_month FROM activities WHERE family_id = 1 AND status = 'completed' AND starts_at >= date_trunc('month', NOW())`);
        const used_this_month = usedRows[0].used_this_month;

        const objectsOfCare = [
            { id: 1, care_time: 'full_time', name: 'Matteo' },
            { id: 2, care_time: 'part_time', name: 'Fluffy' }
        ];

        const getActorMaxGdp = (actor) => {
            const now = new Date();
            const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
            const hrs = daysInMonth * 24;
            return actor.care_time === 'full_time' ? hrs : Math.floor(hrs / 2);
        };

        const getActorRemainingGdp = (actor) => {
            const max = getActorMaxGdp(actor);
            const total = objectsOfCare.reduce((sum, o) => sum + getActorMaxGdp(o), 0);
            const usedShare = used_this_month * (max / total);
            return Math.max(0, Math.floor(max - usedShare));
        };

        console.log("DB value:", used_this_month);
        console.log("Matteo Max:", getActorMaxGdp(objectsOfCare[0]));
        console.log("Matteo Remaining:", getActorRemainingGdp(objectsOfCare[0]));
        console.log("Fluffy Max:", getActorMaxGdp(objectsOfCare[1]));
        console.log("Fluffy Remaining:", getActorRemainingGdp(objectsOfCare[1]));

    } catch (e) {
        console.error(e);
    }
    process.exit();
}
test();
