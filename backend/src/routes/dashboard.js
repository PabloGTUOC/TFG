import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth, assertActiveMember } from '../db/users.js';
import { runAutoCompleteSweep } from '../db/autoComplete.js';

export const dashboardRouter = Router();

dashboardRouter.get('/:familyId', async (req, res) => {
  const familyId = Number(req.params.familyId);
  if (!familyId) return res.status(400).json({ error: 'Invalid familyId.' });

  try {
    const data = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      if (!await assertActiveMember(client, familyId, user.id)) return null;

      const familyRows = await client.query(
        'SELECT last_coin_distribution_month FROM families WHERE id = $1 FOR UPDATE',
        [familyId]
      );
      if (!familyRows.rowCount) return null;

      const family = familyRows.rows[0];
      const currentMonthStr = new Date().toISOString().slice(0, 7);

      if (!family.last_coin_distribution_month) {
        // First time initialization
        await client.query(
          'UPDATE families SET last_coin_distribution_month = $1 WHERE id = $2',
          [currentMonthStr, familyId]
        );
      } else if (family.last_coin_distribution_month < currentMonthStr) {
        // SWEEP PAST MONTHS
        let sweepMonthStr = family.last_coin_distribution_month;

        while (sweepMonthStr < currentMonthStr) {
          const [yearStr, monthStr] = sweepMonthStr.split('-');
          let year = parseInt(yearStr, 10);
          let month = parseInt(monthStr, 10);

          const daysInMonth = new Date(year, month, 0).getDate();
          const hoursInMonth = daysInMonth * 24;

          const { rows: careActors } = await client.query(
            `SELECT care_time FROM actors WHERE family_id = $1 AND actor_type != 'person'`,
            [familyId]
          );

          let totalGdp = 0;
          careActors.forEach(a => {
            totalGdp += (a.care_time === 'full_time' ? hoursInMonth : Math.floor(hoursInMonth / 2));
          });

          if (totalGdp > 0) {
            const { rows: explicit } = await client.query(
              `SELECT COALESCE(SUM(coin_value), 0)::int as total
               FROM activities
               WHERE family_id = $1
                 AND status = 'completed'
                 AND to_char(starts_at AT TIME ZONE 'UTC', 'YYYY-MM') = $2`,
              [familyId, sweepMonthStr]
            );

            const unclaimed = Math.max(0, totalGdp - explicit[0].total);

            // Split and distribute
            const { rows: caretakers } = await client.query(
              `SELECT id FROM family_members WHERE family_id = $1 AND role IN ('main_caregiver', 'caregiver') AND status = 'active'`,
              [familyId]
            );

            if (caretakers.length > 0 && unclaimed > 0) {
              const share = Math.floor(unclaimed / caretakers.length);
              if (share > 0) {
                const cIds = caretakers.map(c => c.id);
                await client.query(
                  `UPDATE family_members SET coin_balance = coin_balance + $1 WHERE id = ANY($2::bigint[])`,
                  [share, cIds]
                );
              }
            }
          }

          // Advance month
          month++;
          if (month > 12) { month = 1; year++; }
          sweepMonthStr = `${year}-${month.toString().padStart(2, '0')}`;
        }

        await client.query(
          'UPDATE families SET last_coin_distribution_month = $1 WHERE id = $2',
          [currentMonthStr, familyId]
        );
      }

      await runAutoCompleteSweep(client, familyId);

      const { rows: members } = await client.query(
        `SELECT fm.user_id, COALESCE(fm.alias, u.display_name, u.email, u.firebase_uid) AS name, fm.role, fm.coin_balance, fm.status, u.avatar_url
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
        `SELECT id, name, actor_type, care_time, avatar_url 
         FROM actors 
         WHERE family_id = $1 AND actor_type != 'person'
         ORDER BY id ASC`,
        [familyId]
      );

      const { rows: usedRows } = await client.query(
        `SELECT COALESCE(SUM(coin_value), 0)::int as used_this_month
         FROM activities
         WHERE family_id = $1
           AND status = 'completed'
           AND starts_at >= date_trunc('month', NOW())`,
        [familyId]
      );
      const used_this_month = usedRows[0].used_this_month;

      return { members, calendar: byDay, objectsOfCare, used_this_month };
    });

    if (!data) return res.status(403).json({ error: 'Not a family member.' });
    return res.json(data);
  } catch {
    return res.status(500).json({ error: 'Failed to load dashboard.' });
  }
});
