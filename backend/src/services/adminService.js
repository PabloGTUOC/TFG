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

const DAY_MS = 24 * 60 * 60 * 1000;

// Heartbeat buckets (plan §3.2): active ≤ 30 days, dormant 30–90, inactive > 90.
export function heartbeatBucket(lastActiveAt, nowMs = Date.now()) {
  if (!lastActiveAt) return 'inactive';
  const days = (nowMs - new Date(lastActiveAt).getTime()) / DAY_MS;
  if (days <= 30) return 'active';
  if (days <= 90) return 'dormant';
  return 'inactive';
}

const STATUS_CLAUSES = {
  active: `f.last_active_at > NOW() - INTERVAL '30 days'`,
  dormant: `f.last_active_at <= NOW() - INTERVAL '30 days' AND f.last_active_at > NOW() - INTERVAL '90 days'`,
  inactive: `f.last_active_at <= NOW() - INTERVAL '90 days'`,
};

// Explicit mapping is the leak barrier: only these fields ever leave this
// module, no matter what a query happens to return.
function toRegistryEntry(row, nowMs) {
  return {
    id: Number(row.id),
    name: row.name,
    createdAt: row.created_at,
    lastActiveAt: row.last_active_at,
    memberCount: Number(row.member_count ?? 0),
    status: heartbeatBucket(row.last_active_at, nowMs),
  };
}

export async function listFamilies(client, { search = '', status = '', page = 1, pageSize = 20 } = {}, nowMs = Date.now()) {
  const size = Math.min(Math.max(1, Number(pageSize) || 20), 100);
  const p = Math.max(1, Number(page) || 1);

  const where = [];
  const params = [];
  if (search) {
    params.push(`%${search}%`, String(search));
    where.push(`(f.name ILIKE $${params.length - 1} OR f.id::text = $${params.length})`);
  }
  if (STATUS_CLAUSES[status]) where.push(STATUS_CLAUSES[status]);
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

  params.push(size, (p - 1) * size);
  const { rows } = await client.query(
    `SELECT f.id, f.name, f.created_at, f.last_active_at,
            (SELECT COUNT(*) FROM family_members fm
              WHERE fm.family_id = f.id AND fm.status = 'active') AS member_count,
            COUNT(*) OVER() AS total
     FROM families f
     ${whereSql}
     ORDER BY f.last_active_at DESC, f.id
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );

  return {
    data: {
      families: rows.map(r => toRegistryEntry(r, nowMs)),
      page: p,
      pageSize: size,
      total: rows.length ? Number(rows[0].total) : 0,
    },
  };
}

export async function getFamilyRegistry(client, familyId, nowMs = Date.now()) {
  const { rows } = await client.query(
    `SELECT f.id, f.name, f.created_at, f.last_active_at,
            (SELECT COUNT(*) FROM family_members fm
              WHERE fm.family_id = f.id AND fm.status = 'active') AS member_count,
            (SELECT COUNT(*) FROM family_members fm
              WHERE fm.family_id = f.id AND fm.status = 'pending') AS pending_member_count,
            (SELECT COUNT(*) FROM actors a
              WHERE a.family_id = f.id AND a.user_id IS NULL) AS actor_count
     FROM families f
     WHERE f.id = $1`,
    [familyId]
  );
  if (!rows.length) return { error: { code: 404, message: 'Family not found.' } };

  return {
    data: {
      ...toRegistryEntry(rows[0], nowMs),
      pendingMemberCount: Number(rows[0].pending_member_count ?? 0),
      actorCount: Number(rows[0].actor_count ?? 0),
    },
  };
}

// Records the intent to nudge an inactive family. The push itself goes out
// after the transaction via notifyFamilyCaregivers — the system contacts the
// caregivers; the admin never sees who they are.
export async function requestInactivityNotice(client, adminId, familyId) {
  const result = await getFamilyRegistry(client, familyId);
  if (result.error) return result;

  await logAdminAction(client, adminId, 'family.notify_inactive', {
    targetType: 'family',
    targetId: familyId,
    payload: { status: result.data.status },
  });
  return { data: { familyId: result.data.id, status: result.data.status } };
}

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
