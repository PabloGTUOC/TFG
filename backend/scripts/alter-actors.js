import pg from 'pg';

const { Pool } = pg;

const pool = new Pool({
    connectionString: process.env.DATABASE_URL || 'postgresql://pablogtorres@localhost:5432/carecoins'
});

async function run() {
    try {
        await pool.query(`ALTER TABLE actors ADD COLUMN IF NOT EXISTS avatar_url TEXT;`);
        console.log('Successfully added avatar_url back to actors table.');
    } catch (e) {
        console.error(e);
    } finally {
        pool.end();
    }
}

run();
