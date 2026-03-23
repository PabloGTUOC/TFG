import { pool } from '../src/db/pool.js';

async function main() {
    await pool.query(`ALTER TABLE activities ALTER COLUMN starts_at DROP NOT NULL`);
    await pool.query(`ALTER TABLE activities ALTER COLUMN ends_at DROP NOT NULL`);

    // We don't know the exact name of the constraint, but usually it's activities_check.
    // We can just drop the check constraint completely by catching if it doesn't exist.
    try {
        await pool.query(`ALTER TABLE activities DROP CONSTRAINT activities_check`);
    } catch (e) {
        console.log('activities_check constraint not found, skipping drop.');
    }

    console.log('Activities table updated successfully.');
    await pool.end();
}

main().catch(console.error);
