import { pool } from './src/db/pool.js';

async function check() {
    try {
        // 1. Find user with name or alias 'papa'
        const { rows: userRows } = await pool.query(`
      SELECT u.id, u.email, u.display_name, fm.alias, fm.coin_balance, fm.family_id
      FROM users u
      JOIN family_members fm ON fm.user_id = u.id
      WHERE u.display_name ILIKE '%papa%' OR fm.alias ILIKE '%papa%' OR u.email ILIKE '%papa%' OR u.display_name ILIKE '%pablo%' OR fm.alias ILIKE '%pablo%' OR u.email ILIKE '%pablo%'
    `);

        if (!userRows.length) {
            console.log('No user papa/pablo found.');
            process.exit();
        }

        const u = userRows[0];
        console.log('Found User / Family Member:', u);

        const { rows: activities } = await pool.query(
            `SELECT id, title, status, coin_value, starts_at, assigned_to
       FROM activities 
       WHERE assigned_to = $1 AND status = 'completed'`,
            [u.id]
        );
        console.log('\nCompleted Activities for this user:', activities);

        const { rows: ledger } = await pool.query(
            `SELECT * FROM coin_ledger WHERE user_id = $1 ORDER BY created_at ASC`,
            [u.id]
        );
        console.log('\nCoin Ledger:', ledger);

    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}

check();
