import { pool } from '../db/pool.js';

export async function logLoginHistory(req, _res, next) {
  if (!req.auth?.uid) return next();

  try {
    await pool.query(
      `INSERT INTO login_history (user_id, ip_address, user_agent)
       SELECT id, $2, $3 FROM users WHERE firebase_uid = $1`,
      [req.auth.uid, req.ip || null, req.headers['user-agent'] || null]
    );
  } catch {
    // non-blocking audit logging
  }

  return next();
}
