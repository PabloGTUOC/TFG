import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth } from '../db/users.js';
import { validateBody, validateParams, required, string } from '../middleware/validate.js';
import { requireRole } from '../middleware/rbac.js';

export const familiesRouter = Router();

familiesRouter.get('/', async (req, res) => {
  try {
    const families = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      const { rows } = await client.query(
        `SELECT f.id, f.name, f.monthly_coin_budget, fm.role, fm.coin_balance
         FROM family_members fm
         JOIN families f ON f.id = fm.family_id
         WHERE fm.user_id = $1
         ORDER BY f.created_at DESC`,
        [user.id]
      );
      return rows;
    });

    return res.json({ families });
  } catch {
    return res.status(500).json({ error: 'Failed to load families.' });
  }
});

familiesRouter.get('/:familyId/budget', async (req, res) => {
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

      const { rows } = await client.query(`
        SELECT 
          f.monthly_coin_budget,
          COALESCE((
            SELECT SUM(coin_value) 
            FROM activities 
            WHERE family_id = $1 
              AND is_template = false 
              AND status = 'completed'
              AND date_trunc('month', starts_at) = date_trunc('month', NOW())
          ), 0)::int as used_this_month
        FROM families f
        WHERE f.id = $1
      `, [familyId]);

      if (!rows.length) return null;

      const d = rows[0];
      const baseRatePerHour = d.monthly_coin_budget / 720;

      return {
        monthlyBudget: d.monthly_coin_budget,
        usedThisMonth: d.used_this_month,
        remainingBudget: Math.max(0, d.monthly_coin_budget - d.used_this_month),
        baseRatePerHour: parseFloat(baseRatePerHour.toFixed(2))
      };
    });

    if (!data) return res.status(403).json({ error: 'Not a family member or family not found.' });
    return res.json(data);
  } catch (err) {
    console.error('Failed to get family budget:', err);
    return res.status(500).json({ error: 'Failed to fetch family budget.' });
  }
});

familiesRouter.post('/', validateBody({
  name: [required(), string(1, 100)],
  mainCaretakerName: [string(1, 100)],
  alias: [string(1, 50)],
}), async (req, res) => {
  const { name, mainCaretakerName, caretakers = [], objectsOfCare = [], alias } = req.body;

  if (!name || typeof name !== 'string') {
    return res.status(400).json({ error: 'name is required.' });
  }

  // Calculate monthly budget based on objects of care.
  let monthlyCoinBudget = 0;
  for (const obj of objectsOfCare) {
    if (obj.careTime === 'full_time') {
      monthlyCoinBudget += 24 * 30; // 720
    } else if (obj.careTime === 'part_time') {
      monthlyCoinBudget += 12 * 30; // 360
    }
  }
  if (monthlyCoinBudget === 0) monthlyCoinBudget = 1000;

  try {
    const family = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);

      if (mainCaretakerName && mainCaretakerName.trim()) {
        await client.query(
          `UPDATE users SET display_name = $1 WHERE id = $2`,
          [mainCaretakerName.trim(), user.id]
        );
        user.display_name = mainCaretakerName.trim();
      }

      const createdFamily = await client.query(
        `INSERT INTO families (name, monthly_coin_budget, created_by)
         VALUES ($1, $2, $3)
         RETURNING id, name, monthly_coin_budget`,
        [name.trim(), monthlyCoinBudget, user.id]
      );
      const famId = createdFamily.rows[0].id;

      // Add creator as main_caregiver, active
      await client.query(
        `INSERT INTO family_members (family_id, user_id, role, status, alias)
         VALUES ($1, $2, 'main_caregiver', 'active', $3)`,
        [famId, user.id, alias ? alias.trim() : null]
      );

      // Add creator to actors as person
      await client.query(
        `INSERT INTO actors (family_id, user_id, actor_type, name)
         VALUES ($1, $2, 'person', $3)`,
        [famId, user.id, user.display_name]
      );

      // Add invitations
      for (const ct of caretakers) {
        if (ct.email && ct.email.trim()) {
          await client.query(
            `INSERT INTO family_invitations (family_id, email, name, invited_by)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (family_id, email) DO NOTHING`,
            [famId, ct.email.trim(), ct.name?.trim() || null, user.id]
          );
        }
      }

      // Add objects of care -> actors
      for (const obj of objectsOfCare) {
        if (obj.name && obj.name.trim()) {
          await client.query(
            `INSERT INTO actors (family_id, actor_type, name, care_time)
             VALUES ($1, $2, $3, $4)`,
            [famId, obj.type || 'child', obj.name.trim(), obj.careTime || 'full_time']
          );
        }
      }

      return createdFamily.rows[0];
    });

    return res.status(201).json({ family });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to create family.' });
  }
});

familiesRouter.post('/join-request', validateBody({
  identifier: [required(), string(1, 100)],
  alias: [string(1, 50)],
}), async (req, res) => {
  const { identifier, alias } = req.body;
  if (!identifier) return res.status(400).json({ error: 'Family ID or name is required.' });

  try {
    const joined = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);

      let familyId;
      if (!isNaN(identifier)) {
        familyId = Number(identifier);
      } else {
        const { rows: fRows } = await client.query(`SELECT id FROM families WHERE name ILIKE $1 LIMIT 1`, [identifier.trim()]);
        if (fRows.length === 0) throw new Error('Family not found');
        familyId = fRows[0].id;
      }

      const { rows: checkF } = await client.query('SELECT id FROM families WHERE id = $1', [familyId]);
      if (checkF.length === 0) throw new Error('Family not found');

      // Check if they have an invitation pending, if so, they can be 'active' immediately. Otherwise 'pending'.
      const { rows: invRows } = await client.query(
        `SELECT id FROM family_invitations WHERE family_id = $1 AND email = $2 AND status = 'pending'`,
        [familyId, user.email]
      );

      const newStatus = invRows.length > 0 ? 'active' : 'pending';

      await client.query(
        `INSERT INTO family_members (family_id, user_id, role, status, alias)
         VALUES ($1, $2, 'member', $3, $4)
         ON CONFLICT (family_id, user_id) DO UPDATE SET alias = EXCLUDED.alias, status = EXCLUDED.status`,
        [familyId, user.id, newStatus, alias ? alias.trim() : null]
      );

      if (newStatus === 'active') {
        await client.query(`UPDATE family_invitations SET status = 'accepted' WHERE id = $1`, [invRows[0].id]);
        await client.query(
          `INSERT INTO actors (family_id, user_id, actor_type, name)
           VALUES ($1, $2, 'person', $3)
           ON CONFLICT (family_id, user_id) DO NOTHING`,
          [familyId, user.id, user.display_name]
        );
      }
      return { success: true, status: newStatus };
    });

    return res.status(200).json(joined);
  } catch (err) {
    return res.status(400).json({ error: err.message || 'Failed to request join.' });
  }
});

familiesRouter.patch('/:familyId/members/:userId/role',
  validateParams('familyId', 'userId'),
  requireRole('main_caregiver', r => r.params.familyId),
  async (req, res) => {
    const familyId = Number(req.params.familyId);
    const userId = Number(req.params.userId);
    const { role } = req.body;

    if (!['main_caregiver', 'caregiver', 'member'].includes(role)) {
      return res.status(400).json({ error: 'Invalid role.' });
    }

    try {
      const result = await withTransaction(async (client) => {
        const me = await upsertUserFromAuth(client, req.auth);
        const updated = await client.query(
          `UPDATE family_members
         SET role = $1
         WHERE family_id = $2 AND user_id = $3
         RETURNING family_id, user_id, role`,
          [role, familyId, userId]
        );
        if (!updated.rowCount) return { error: { code: 404, message: 'Family member not found.' } };

        return { data: { member: updated.rows[0] } };
      });

      if (result.error) return res.status(result.error.code).json({ error: result.error.message });
      return res.json(result.data);
    } catch {
      return res.status(500).json({ error: 'Failed to update role.' });
    }
  });

familiesRouter.post('/:familyId/members/:userId/approve',
  validateParams('familyId', 'userId'),
  requireRole('main_caregiver', r => r.params.familyId),
  async (req, res) => {
    const familyId = Number(req.params.familyId);
    const userId = Number(req.params.userId);

    try {
      const result = await withTransaction(async (client) => {
        const { rowCount } = await client.query(
          `UPDATE family_members
           SET status = 'active', role = 'main_caregiver'
           WHERE family_id = $1 AND user_id = $2 AND status = 'pending'`,
          [familyId, userId]
        );

        if (rowCount === 0) {
          return { error: 'Pending member not found.' };
        }

        return { success: true };
      });

      if (result.error) return res.status(404).json({ error: result.error });
      return res.json(result);
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: 'Failed to approve member.' });
    }
  });

familiesRouter.post('/:familyId/actors',
  validateParams('familyId'),
  validateBody({ name: [required(), string(1, 100)] }),
  requireRole('main_caregiver', r => r.params.familyId),
  async (req, res) => {
    const familyId = Number(req.params.familyId);
    const { name, actorType, careTime } = req.body;

    const type = ['child', 'pet', 'elderly', 'person'].includes(actorType) ? actorType : 'child';
    const time = ['full_time', 'part_time'].includes(careTime) ? careTime : 'full_time';
    const budgetIncrease = time === 'full_time' ? 720 : 360;

    try {
      const result = await withTransaction(async (client) => {
        const { rows } = await client.query(
          `INSERT INTO actors (family_id, actor_type, name, care_time)
           VALUES ($1, $2, $3, $4) RETURNING *`,
          [familyId, type, name, time]
        );

        await client.query(
          `UPDATE families SET monthly_coin_budget = monthly_coin_budget + $1 WHERE id = $2`,
          [budgetIncrease, familyId]
        );

        return rows[0];
      });

      return res.status(201).json(result);
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: 'Failed to add object of care.' });
    }
  });
