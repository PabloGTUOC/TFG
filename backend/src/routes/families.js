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
  } catch {
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

      await client.query(
        `INSERT INTO actors (family_id, user_id, actor_type)
         VALUES ($1, $2, 'person')
         ON CONFLICT (family_id, user_id) DO NOTHING`,
        [createdFamily.rows[0].id, user.id]
      );

      return createdFamily.rows[0];
    });

    return res.status(201).json({ family });
  } catch {
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
      await client.query(
        `INSERT INTO actors (family_id, user_id, actor_type)
         VALUES ($1, $2, 'person')
         ON CONFLICT (family_id, user_id) DO NOTHING`,
        [familyId, user.id]
      );
    });

    return res.status(200).json({ joined: true });
  } catch {
    return res.status(500).json({ error: 'Failed to join family.' });
  }
});

familiesRouter.patch('/:familyId/members/:userId/role', async (req, res) => {
  const familyId = Number(req.params.familyId);
  const userId = Number(req.params.userId);
  const { role } = req.body;

  if (!['main_caregiver', 'caregiver', 'member'].includes(role)) {
    return res.status(400).json({ error: 'Invalid role.' });
  }

  try {
    const result = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);
      const { rows: roleRows } = await client.query(
        `SELECT role FROM family_members WHERE family_id=$1 AND user_id=$2`,
        [familyId, me.id]
      );
      if (!roleRows.length || roleRows[0].role !== 'main_caregiver') {
        return { error: { code: 403, message: 'Only main caregivers can manage roles.' } };
      }

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

familiesRouter.post('/:familyId/recalculate-monthly', async (req, res) => {
  const familyId = Number(req.params.familyId);
  if (!familyId) return res.status(400).json({ error: 'Invalid familyId.' });

  try {
    const result = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);
      const { rows: roleRows } = await client.query(
        `SELECT role FROM family_members WHERE family_id=$1 AND user_id=$2`,
        [familyId, me.id]
      );
      if (!roleRows.length || roleRows[0].role !== 'main_caregiver') {
        return { error: { code: 403, message: 'Only main caregivers can recalculate monthly balances.' } };
      }

      const { rows: familyRows } = await client.query('SELECT monthly_coin_budget FROM families WHERE id=$1', [familyId]);
      if (!familyRows.length) return { error: { code: 404, message: 'Family not found.' } };

      const { rows: memberRows } = await client.query('SELECT user_id FROM family_members WHERE family_id=$1', [familyId]);
      if (!memberRows.length) return { error: { code: 404, message: 'No family members found.' } };

      const eachCoins = Math.floor(familyRows[0].monthly_coin_budget / memberRows.length);

      await client.query('UPDATE family_members SET coin_balance = $1 WHERE family_id=$2', [eachCoins, familyId]);
      await client.query(
        `INSERT INTO coin_ledger (family_id, user_id, amount, reason)
         SELECT $1, user_id, $2, 'monthly_recalculation' FROM family_members WHERE family_id = $1`,
        [familyId, eachCoins]
      );

      return { data: { recalculated: true, eachCoins } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.json(result.data);
  } catch {
    return res.status(500).json({ error: 'Failed to recalculate monthly balances.' });
  }
});
