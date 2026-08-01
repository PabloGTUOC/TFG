/**
 * Family heartbeat (docs/admin-family-management-plan.md Phase 2).
 *
 * Keeps families.last_active_at fresh so the admin registry can tell
 * active families from abandoned ones without ever querying family content.
 *
 * Design constraints:
 *  - Touches only on successful responses (the middleware listens on
 *    response 'finish'), so unauthorized probes can't keep a family alive.
 *  - Throttled in-memory to one write per family per hour.
 *  - Fire-and-forget: a failed touch never affects the request.
 *  - Not mounted on /api/admin — admin oversight is not family activity.
 *
 * Requests where the family is only implicit (e.g. POST
 * /api/activities/:activityId/complete) are deliberately not covered; any
 * active family also produces requests that carry familyId directly.
 */
import { pool } from '../db/pool.js';

const THROTTLE_MS = 60 * 60 * 1000;
const lastTouch = new Map();

export function clearHeartbeatThrottle() {
  lastTouch.clear();
}

export function touchFamilyHeartbeat(familyId, { now = Date.now, query } = {}) {
  const id = Number(familyId);
  if (!Number.isInteger(id) || id <= 0) return false;

  const ts = now();
  const prev = lastTouch.get(id);
  if (prev !== undefined && ts - prev < THROTTLE_MS) return false;
  lastTouch.set(id, ts);

  const run = query ?? ((sql, params) => pool.query(sql, params));
  Promise.resolve(run(`UPDATE families SET last_active_at = NOW() WHERE id = $1`, [id]))
    .catch(() => {});
  return true;
}

export function familyHeartbeat(req, res, next) {
  res.on('finish', () => {
    if (res.statusCode >= 400) return;
    // By 'finish', req.params holds the matched route's params.
    const familyId = req.params?.familyId ?? req.query?.familyId ?? req.body?.familyId;
    if (familyId != null) touchFamilyHeartbeat(familyId);
  });
  next();
}
