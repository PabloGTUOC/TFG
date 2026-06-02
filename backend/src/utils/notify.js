import admin from 'firebase-admin';
import { pool } from '../db/pool.js';

function getMessaging() {
  if (!admin.apps.length) return null;
  try { return admin.messaging(); } catch { return null; }
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

export async function notifyUser(userId, payload) {
  try {
    const { rows } = await pool.query(
      'SELECT token FROM fcm_tokens WHERE user_id = $1', [userId]
    );
    if (!rows.length) return;
    const stale = await sendToTokens(rows.map(r => r.token), payload);
    await pruneStale(stale);
  } catch (err) {
    console.error('notifyUser error:', err);
  }
}

export async function notifyFamilyCaregivers(familyId, excludeUserId, payload) {
  try {
    const { rows } = await pool.query(
      `SELECT DISTINCT ft.user_id, ft.token FROM fcm_tokens ft
       JOIN family_members fm ON fm.user_id = ft.user_id
       WHERE fm.family_id = $1 AND fm.role = 'caregiver'
         AND fm.status = 'active' AND ft.user_id != $2`,
      [familyId, excludeUserId]
    );
    if (!rows.length) return;
    const stale = await sendToTokens(rows.map(r => r.token), payload);
    await pruneStale(stale);
  } catch (err) {
    console.error('notifyFamilyCaregivers error:', err);
  }
}

export async function notifyFamilyAll(familyId, excludeUserId, payload) {
  try {
    const { rows } = await pool.query(
      `SELECT DISTINCT ft.user_id, ft.token FROM fcm_tokens ft
       JOIN family_members fm ON fm.user_id = ft.user_id
       WHERE fm.family_id = $1 AND fm.status = 'active' AND ft.user_id != $2`,
      [familyId, excludeUserId]
    );
    if (!rows.length) return;
    const stale = await sendToTokens(rows.map(r => r.token), payload);
    await pruneStale(stale);
  } catch (err) {
    console.error('notifyFamilyAll error:', err);
  }
}
