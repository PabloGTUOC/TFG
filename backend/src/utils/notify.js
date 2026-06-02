import admin from 'firebase-admin';
import { pool } from '../db/pool.js';

const VALID_PREF_KEYS = new Set([
  'activity_assigned', 'activity_validated', 'activity_completed',
  'bounty_offered', 'family_events',
]);

function getMessaging() {
  if (!admin.apps.length) return null;
  try { return admin.messaging(); } catch { return null; }
}

// Returns a SQL fragment that filters out users who opted out of this notification type.
// Column name is validated against a known set — safe to interpolate.
function prefClause(prefKey) {
  if (!prefKey || !VALID_PREF_KEYS.has(prefKey)) return '';
  return `AND COALESCE(np.${prefKey}, true) = true`;
}

async function sendToTokens(tokens, { title, body, url }) {
  const messaging = getMessaging();
  if (!messaging || !tokens.length) return [];

  const message = {
    tokens,
    notification: { title, body },
    webpush: {
      notification: { icon: '/icon-192.png', badge: '/icon-192.png' },
      ...(url && { fcmOptions: { link: url } }),
    },
    ...(url && { data: { url } }),
  };

  const response = await messaging.sendEachForMulticast(message);

  return tokens.filter((_, i) => {
    const err = response.responses[i].error?.code;
    return err === 'messaging/invalid-registration-token' ||
           err === 'messaging/registration-token-not-registered';
  });
}

async function pruneStale(stale) {
  if (!stale.length) return;
  await pool.query('DELETE FROM fcm_tokens WHERE token = ANY($1)', [stale]);
}

export async function notifyUser(userId, { prefKey, ...payload }) {
  try {
    const { rows } = await pool.query(
      `SELECT ft.token FROM fcm_tokens ft
       LEFT JOIN notification_preferences np ON np.user_id = ft.user_id
       WHERE ft.user_id = $1 ${prefClause(prefKey)}`,
      [userId]
    );
    if (!rows.length) return;
    const stale = await sendToTokens(rows.map(r => r.token), payload);
    await pruneStale(stale);
  } catch (err) {
    console.error('notifyUser error:', err);
  }
}

export async function notifyFamilyCaregivers(familyId, excludeUserId, { prefKey, ...payload }) {
  try {
    const { rows } = await pool.query(
      `SELECT DISTINCT ft.token FROM fcm_tokens ft
       JOIN family_members fm ON fm.user_id = ft.user_id
       LEFT JOIN notification_preferences np ON np.user_id = ft.user_id
       WHERE fm.family_id = $1 AND fm.role = 'caregiver'
         AND fm.status = 'active' AND ft.user_id != $2
         ${prefClause(prefKey)}`,
      [familyId, excludeUserId]
    );
    if (!rows.length) return;
    const stale = await sendToTokens(rows.map(r => r.token), payload);
    await pruneStale(stale);
  } catch (err) {
    console.error('notifyFamilyCaregivers error:', err);
  }
}

export async function notifyFamilyAll(familyId, excludeUserId, { prefKey, ...payload }) {
  try {
    const { rows } = await pool.query(
      `SELECT DISTINCT ft.token FROM fcm_tokens ft
       JOIN family_members fm ON fm.user_id = ft.user_id
       LEFT JOIN notification_preferences np ON np.user_id = ft.user_id
       WHERE fm.family_id = $1 AND fm.status = 'active' AND ft.user_id != $2
       ${prefClause(prefKey)}`,
      [familyId, excludeUserId]
    );
    if (!rows.length) return;
    const stale = await sendToTokens(rows.map(r => r.token), payload);
    await pruneStale(stale);
  } catch (err) {
    console.error('notifyFamilyAll error:', err);
  }
}
