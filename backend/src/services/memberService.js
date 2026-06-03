import { assertActiveMember } from '../db/users.js';

export async function listMembers(client, userId, familyId) {
  if (!await assertActiveMember(client, familyId, userId)) {
    return { error: { code: 403, message: 'Not a family member.' } };
  }
  const { rows } = await client.query(
    `SELECT fm.user_id as id, COALESCE(fm.alias, u.display_name, u.email) as name,
            fm.role, fm.status, u.avatar_url
     FROM family_members fm JOIN users u ON u.id = fm.user_id
     WHERE fm.family_id = $1 AND fm.status = 'active'
     ORDER BY u.created_at ASC`,
    [familyId]
  );
  return { data: { members: rows } };
}

export async function listInvitations(client, userId, familyId) {
  if (!await assertActiveMember(client, familyId, userId)) {
    return { error: { code: 403, message: 'Not a family member.' } };
  }
  const { rows } = await client.query(
    `SELECT id, email, name, status, created_at FROM family_invitations
     WHERE family_id = $1 AND status = 'pending' ORDER BY created_at DESC`,
    [familyId]
  );
  return { data: { invitations: rows } };
}

export async function createInvitation(client, user, familyId, { email, name }) {
  const { rows: familyRows } = await client.query(`SELECT name FROM families WHERE id = $1`, [familyId]);
  const fName = familyRows[0]?.name || 'your family';
  const iName = user.display_name || user.email || 'A caregiver';

  const { rows } = await client.query(
    `INSERT INTO family_invitations (family_id, email, name, invited_by)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (family_id, email) DO UPDATE
       SET status = 'pending', name = EXCLUDED.name, invited_by = EXCLUDED.invited_by
     RETURNING id, email, name, status, created_at`,
    [familyId, email.toLowerCase().trim(), name?.trim() || null, user.id]
  );
  return { data: { invitation: rows[0], inviterName: iName, familyName: fName } };
}

export async function approveMember(client, familyId, userId) {
  const { rowCount } = await client.query(
    `UPDATE family_members SET status = 'active', role = 'caregiver'
     WHERE family_id = $1 AND user_id = $2 AND status = 'pending'`,
    [familyId, userId]
  );
  if (rowCount === 0) return { error: { code: 404, message: 'Pending member not found.' } };
  return { data: { success: true } };
}

export async function updateMemberRole(client, familyId, userId, role) {
  const { rows, rowCount } = await client.query(
    `UPDATE family_members SET role = $1 WHERE family_id = $2 AND user_id = $3
     RETURNING family_id, user_id, role`,
    [role, familyId, userId]
  );
  if (!rowCount) return { error: { code: 404, message: 'Family member not found.' } };
  return { data: { member: rows[0] } };
}

export async function joinByInvitation(client, user, { familyId, alias }) {
  if (!user.email) {
    return { error: { code: 400, message: 'Your account has no email address. Use an invite link instead.' } };
  }
  const { rows: invRows } = await client.query(
    `SELECT id FROM family_invitations WHERE family_id = $1 AND email = $2 AND status = 'pending'`,
    [familyId, user.email.toLowerCase()]
  );
  if (!invRows.length) {
    return { error: { code: 403, message: 'No pending invitation found for your email address.' } };
  }
  await client.query(
    `INSERT INTO family_members (family_id, user_id, role, status, alias)
     VALUES ($1, $2, 'caregiver', 'active', $3)
     ON CONFLICT (family_id, user_id) DO UPDATE
       SET status = 'active', alias = COALESCE(EXCLUDED.alias, family_members.alias)`,
    [familyId, user.id, alias ? alias.trim() : null]
  );
  await client.query(`UPDATE family_invitations SET status = 'accepted' WHERE id = $1`, [invRows[0].id]);
  await client.query(
    `INSERT INTO actors (family_id, user_id, actor_type, name)
     VALUES ($1, $2, 'person', $3) ON CONFLICT (family_id, user_id) DO NOTHING`,
    [familyId, user.id, user.display_name || user.email]
  );
  return { data: { success: true, status: 'active' }, userId: user.id, familyId, displayName: user.display_name || user.email };
}

export async function joinByToken(client, user, { token, alias }) {
  const { rows: linkRows } = await client.query(
    `SELECT id, family_id, max_uses, uses, expires_at, revoked FROM invite_links WHERE id = $1 FOR UPDATE`,
    [token]
  );
  if (!linkRows.length) return { error: { code: 404, message: 'Invalid invite link.' } };
  const link = linkRows[0];
  if (link.revoked) return { error: { code: 410, message: 'This invite link has been revoked.' } };
  if (link.expires_at && new Date(link.expires_at) < new Date()) {
    return { error: { code: 410, message: 'This invite link has expired.' } };
  }
  if (link.max_uses !== null && link.uses >= link.max_uses) {
    return { error: { code: 410, message: 'This invite link has reached its maximum uses.' } };
  }
  const { rows: existing } = await client.query(
    `SELECT status FROM family_members WHERE family_id = $1 AND user_id = $2`,
    [link.family_id, user.id]
  );
  if (existing.length && existing[0].status === 'active') {
    return { error: { code: 409, message: 'You are already an active member of this family.' } };
  }
  await client.query(
    `INSERT INTO family_members (family_id, user_id, role, status, alias)
     VALUES ($1, $2, 'caregiver', 'active', $3)
     ON CONFLICT (family_id, user_id) DO UPDATE
       SET status = 'active', alias = COALESCE(EXCLUDED.alias, family_members.alias)`,
    [link.family_id, user.id, alias ? alias.trim() : null]
  );
  await client.query(
    `INSERT INTO actors (family_id, user_id, actor_type, name)
     VALUES ($1, $2, 'person', $3) ON CONFLICT (family_id, user_id) DO NOTHING`,
    [link.family_id, user.id, user.display_name || user.email]
  );
  await client.query(`UPDATE invite_links SET uses = uses + 1 WHERE id = $1`, [link.id]);
  return {
    data: { success: true, familyId: link.family_id },
    userId: user.id, familyId: link.family_id,
    displayName: user.display_name || user.email,
  };
}

export async function addActor(client, familyId, { name, actorType, careTime }) {
  const type = ['child', 'pet', 'elderly', 'person'].includes(actorType) ? actorType : 'child';
  const time = ['full_time', 'part_time'].includes(careTime) ? careTime : 'full_time';
  const budgetIncrease = time === 'full_time' ? 720 : 360;

  const { rows } = await client.query(
    `INSERT INTO actors (family_id, actor_type, name, care_time) VALUES ($1,$2,$3,$4) RETURNING *`,
    [familyId, type, name, time]
  );
  await client.query(
    `UPDATE families SET monthly_coin_budget = monthly_coin_budget + $1 WHERE id = $2`,
    [budgetIncrease, familyId]
  );
  return { data: rows[0] };
}

export async function removeActor(client, familyId, actorId) {
  const { rows } = await client.query(
    `SELECT * FROM actors WHERE id = $1 AND family_id = $2`,
    [actorId, familyId]
  );
  if (!rows.length) return { error: { code: 404, message: 'Actor not found.' } };
  const actor = rows[0];
  if (actor.actor_type !== 'pet') return { error: { code: 403, message: 'Only pets can be removed.' } };

  const budgetDecrease = actor.care_time === 'full_time' ? 720 : 360;
  await client.query(`DELETE FROM actors WHERE id = $1`, [actorId]);
  await client.query(
    `UPDATE families SET monthly_coin_budget = monthly_coin_budget - $1 WHERE id = $2`,
    [budgetDecrease, familyId]
  );
  return { data: { success: true } };
}

export async function updateActorAvatar(client, familyId, actorId, avatarUrl) {
  const { rows } = await client.query(
    `UPDATE actors SET avatar_url = $1 WHERE id = $2 AND family_id = $3 RETURNING *`,
    [avatarUrl, actorId, familyId]
  );
  if (!rows.length) return { error: { code: 404, message: 'Actor not found.' } };
  return { data: { avatar_url: rows[0].avatar_url } };
}
