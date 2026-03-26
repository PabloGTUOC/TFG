import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth } from '../db/users.js';
import { runAutoCompleteSweep } from '../db/autoComplete.js';

export const dashboardRouter = Router();

dashboardRouter.get('/:familyId', async (req, res) => {
  const familyId = Number(req.params.familyId);
  if (!familyId) return res.status(400).json({ error: 'Invalid familyId.' });

  try {
    const data = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      const membership = await client.query(
        'SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2',
        [familyId, user.id]
      );
      if (!membership.rowCount) return null;

      await runAutoCompleteSweep(client, familyId);

      const { rows: members } = await client.query(
        `SELECT fm.user_id, COALESCE(fm.alias, u.display_name, u.email, u.firebase_uid) AS name, fm.role, fm.coin_balance
         FROM family_members fm JOIN users u ON u.id = fm.user_id
         WHERE fm.family_id = $1
         ORDER BY fm.coin_balance DESC`,
        [familyId]
      );

      const { rows: byDay } = await client.query(
        `SELECT DATE(starts_at) AS day,
                COUNT(*)::int AS total_activities,
                SUM(CASE WHEN status='approved' THEN coin_value ELSE 0 END)::int AS approved_coins
         FROM activities
         WHERE family_id = $1
         GROUP BY DATE(starts_at)
         ORDER BY day DESC
         LIMIT 30`,
        [familyId]
      );

      const { rows: objectsOfCare } = await client.query(
        `SELECT id, name, actor_type, care_time 
         FROM actors 
         WHERE family_id = $1 AND actor_type != 'person'
         ORDER BY id ASC`,
        [familyId]
      );

      return { members, calendar: byDay, objectsOfCare };
    });

    if (!data) return res.status(403).json({ error: 'Not a family member.' });
    return res.json(data);
  } catch {
    return res.status(500).json({ error: 'Failed to load dashboard.' });
  }
});
