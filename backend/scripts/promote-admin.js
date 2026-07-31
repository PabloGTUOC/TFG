// Promote (or demote) a platform admin. Admins are never self-service —
// this script is the only path (docs/admin-family-management-plan.md Phase 1).
//
// Usage:
//   node scripts/promote-admin.js <email>            # promote to admin
//   node scripts/promote-admin.js <email> --demote   # back to regular user
import { pool } from '../src/db/pool.js';

async function main() {
  const [email, flag] = process.argv.slice(2);
  if (!email || (flag && flag !== '--demote')) {
    console.error('Usage: node scripts/promote-admin.js <email> [--demote]');
    process.exitCode = 1;
    return;
  }

  const role = flag === '--demote' ? 'user' : 'admin';
  const { rows } = await pool.query(
    `UPDATE users SET platform_role = $2
     WHERE email = $1 AND is_deleted = false
     RETURNING id, email, display_name, platform_role`,
    [email, role]
  );

  if (!rows.length) {
    console.error(`No active user found with email ${email}.`);
    process.exitCode = 1;
  } else {
    const u = rows[0];
    console.log(`${u.email} (user #${u.id}) is now platform_role='${u.platform_role}'.`);
  }

  await pool.end();
}

main().catch((error) => {
  console.error('Failed to update platform role:', error);
  process.exitCode = 1;
});
