import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth, assertActiveMember } from '../db/users.js';

export const statsRouter = Router();

statsRouter.get('/:familyId', async (req, res) => {
    const familyId = Number(req.params.familyId);
    if (!familyId) return res.status(400).json({ error: 'Invalid familyId.' });

    try {
        const data = await withTransaction(async (client) => {
            const user = await upsertUserFromAuth(client, req.auth);

            if (!await assertActiveMember(client, familyId, user.id)) return null;

            // 1. Overall Lifetime Coins
            const { rows: kpis } = await client.query(
                `SELECT 
           COALESCE(SUM(coin_value), 0)::int as total_lifetime_coins,
           COUNT(*)::int as total_lifetime_tasks
         FROM activities
         WHERE family_id = $1 AND status = 'completed'`,
                [familyId]
            );

            // 1.5 Get ALL valid caregivers (to ensure the Compare Toggle always shows up even if one user has 0 tasks)
            const { rows: caregiversList } = await client.query(
                `SELECT COALESCE(fm.alias, u.display_name, 'Unknown') as name
                 FROM family_members fm
                 JOIN users u ON u.id = fm.user_id
                 WHERE fm.family_id = $1 AND fm.role IN ('main_caregiver', 'caregiver') AND fm.status = 'active'`,
                [familyId]
            );
            const activeCaregivers = caregiversList.map(c => c.name);

            // 2. Trend by Month (Grouped by Caregiver)
            const { rows: trendByMonth } = await client.query(
                `SELECT 
           COALESCE(fm.alias, u.display_name, 'Unknown') as caregiver,
           to_char(starts_at AT TIME ZONE 'UTC', 'YYYY-MM') as month,
           COALESCE(SUM(coin_value), 0)::int as coins,
           COUNT(*)::int as tasks
         FROM activities a
         JOIN family_members fm ON fm.user_id = a.assigned_to AND fm.family_id = a.family_id
         JOIN users u ON u.id = a.assigned_to
         WHERE a.family_id = $1 AND a.status = 'completed'
         GROUP BY caregiver, month
         ORDER BY month ASC
         LIMIT 100`,
                [familyId]
            );

            // 3. Category Split (Grouped by Caregiver)
            const { rows: categorySplit } = await client.query(
                `SELECT 
           COALESCE(fm.alias, u.display_name, 'Unknown') as caregiver,
           category, 
           COUNT(*)::int as value
         FROM activities a
         JOIN family_members fm ON fm.user_id = a.assigned_to AND fm.family_id = a.family_id
         JOIN users u ON u.id = a.assigned_to
         WHERE a.family_id = $1 AND a.status = 'completed'
         GROUP BY caregiver, category`,
                [familyId]
            );

            // 4. Activity Frequency (Grouped by Caregiver)
            const { rows: activityFrequency } = await client.query(
                `SELECT 
           COALESCE(fm.alias, u.display_name, 'Unknown') as caregiver,
           title, 
           COUNT(*)::int as value
         FROM activities a
         JOIN family_members fm ON fm.user_id = a.assigned_to AND fm.family_id = a.family_id
         JOIN users u ON u.id = a.assigned_to
         WHERE a.family_id = $1 AND a.status = 'completed'
         GROUP BY caregiver, title
         ORDER BY value DESC
         LIMIT 100`,
                [familyId]
            );

            return {
                kpis: kpis[0],
                activeCaregivers,
                trendByMonth,
                categorySplit,
                activityFrequency
            };
        });

        if (!data) return res.status(403).json({ error: 'Not a family member or forbidden.' });
        return res.json(data);
    } catch (err) {
        console.error('Failed to load stats:', err);
        res.status(500).json({ error: 'Failed to load statistics.' });
    }
});
