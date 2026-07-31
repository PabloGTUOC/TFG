/**
 * Platform admin service (docs/admin-family-management-plan.md).
 *
 * PRIVACY BOUNDARY — read before adding queries here:
 * this module may only return registry-level data about families
 * (id, name, created_at, member counts, heartbeat, plan/billing state).
 * It must never select or join member identities (users.email,
 * users.display_name, family_members.alias, …) or family content
 * (activities, coin_ledger, marketplace_rewards, absences).
 * tests/adminService.test.js enforces this on every response shape.
 */

// Every mutating admin call writes exactly one audit row, inside the same
// transaction as the mutation itself.
export async function logAdminAction(client, adminId, action, { targetType, targetId, payload } = {}) {
  await client.query(
    `INSERT INTO admin_audit_log (admin_id, action, target_type, target_id, payload)
     VALUES ($1, $2, $3, $4, $5)`,
    [
      adminId,
      action,
      targetType ?? 'none',
      targetId == null ? null : String(targetId),
      payload == null ? null : JSON.stringify(payload),
    ]
  );
}
