import { pool } from './src/db/pool.js';
async function test() {
    try {
        const { rows: families } = await pool.query('SELECT * FROM families');
        console.log('Families:', families.length);
        const { rows: members } = await pool.query('SELECT * FROM family_members');
        console.log('Members:', members.length);
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
test();
