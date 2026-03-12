import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth } from '../db/users.js';

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
  } catch (error) {
    return res.status(500).json({ error: 'Failed to load families.' });
  }
});

familiesRouter.post('/', async (req, res) => {
  const { name, monthlyCoinBudget = 1000 } = req.body;

  if (!name || typeof name !== 'string') {
    return res.status(400).json({ error: 'name is required.' });
  }

  try {
    const family = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);

      const createdFamily = await client.query(
        `INSERT INTO families (name, monthly_coin_budget, created_by)
         VALUES ($1, $2, $3)
         RETURNING id, name, monthly_coin_budget`,
        [name.trim(), monthlyCoinBudget, user.id]
      );

      await client.query(
        `INSERT INTO family_members (family_id, user_id, role)
         VALUES ($1, $2, 'main_caregiver')`,
        [createdFamily.rows[0].id, user.id]
      );

      return createdFamily.rows[0];
    });

    return res.status(201).json({ family });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to create family.' });
  }
});

familiesRouter.post('/:familyId/join', async (req, res) => {
  const familyId = Number(req.params.familyId);
  const { role = 'member' } = req.body;

  if (!['main_caregiver', 'caregiver', 'member'].includes(role)) {
    return res.status(400).json({ error: 'Invalid role.' });
  }

  try {
    await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      await client.query(
        `INSERT INTO family_members (family_id, user_id, role)
         VALUES ($1, $2, $3)
         ON CONFLICT (family_id, user_id)
         DO UPDATE SET role = EXCLUDED.role`,
        [familyId, user.id, role]
      );
    });

    return res.status(200).json({ joined: true });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to join family.' });
  }
});
