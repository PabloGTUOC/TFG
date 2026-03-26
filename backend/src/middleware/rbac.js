/**
 * Role-based access control.
 *
 * Role hierarchy (highest → lowest): main_caregiver > caregiver > member
 *
 * Two exports:
 *
 *   requireRole(role, getFamilyId)
 *     Express middleware. Use when familyId is available in req (params/body/query).
 *     Example:
 *       router.patch('/:familyId/…', requireRole('main_caregiver', r => r.params.familyId), handler)
 *
 *   assertMemberRole(client, userId, familyId, role)
 *     In-transaction helper. Use when familyId is derived from a prior DB query.
 *     Returns { error: { code, message } } on failure, null on success.
 *     Example (inside withTransaction):
 *       const rbacErr = await assertMemberRole(client, user.id, act.family_id, 'main_caregiver');
 *       if (rbacErr) return rbacErr;
 */

import { pool } from '../db/pool.js';
import { upsertUserFromAuth } from '../db/users.js';

const ROLE_LEVELS = { main_caregiver: 3, caregiver: 2, member: 1 };

function meetsRole(userRole, requiredRole) {
  return (ROLE_LEVELS[userRole] ?? 0) >= (ROLE_LEVELS[requiredRole] ?? 0);
}

// ─── Express middleware ───────────────────────────────────────────────────────

export function requireRole(role, getFamilyId) {
  return async (req, res, next) => {
    const familyId = Number(getFamilyId(req));

    const client = await pool.connect();
    try {
      const user = await upsertUserFromAuth(client, req.auth);
      const { rows } = await client.query(
        `SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2`,
        [familyId, user.id]
      );

      if (!rows.length) {
        return res.status(403).json({ error: 'Not a family member.' });
      }
      if (!meetsRole(rows[0].role, role)) {
        return res.status(403).json({ error: `Requires ${role} role.` });
      }

      next();
    } catch {
      return res.status(500).json({ error: 'Authorization check failed.' });
    } finally {
      client.release();
    }
  };
}

// ─── In-transaction helper ────────────────────────────────────────────────────

export async function assertMemberRole(client, userId, familyId, role) {
  const { rows } = await client.query(
    `SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2`,
    [familyId, userId]
  );

  if (!rows.length) {
    return { error: { code: 403, message: 'Not a family member.' } };
  }
  if (!meetsRole(rows[0].role, role)) {
    return { error: { code: 403, message: `Requires ${role} role.` } };
  }

  return null;
}
