import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth } from '../db/users.js';

export const marketplaceRouter = Router();

// Get active rewards for the family
marketplaceRouter.get('/rewards/:familyId', async (req, res) => {
  const familyId = Number(req.params.familyId);
  if (!familyId) return res.status(400).json({ error: 'Invalid familyId.' });

  try {
    const rewards = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);
      const member = await client.query('SELECT 1 FROM family_members WHERE family_id=$1 AND user_id=$2', [familyId, me.id]);
      if (!member.rowCount) return null;

      const { rows } = await client.query(
        `SELECT id, family_id, creator_id, title, description, cost, status, created_at
         FROM marketplace_rewards
         WHERE family_id = $1 AND status = 'active'
         ORDER BY created_at DESC`,
        [familyId]
      );
      return rows;
    });

    if (rewards === null) return res.status(403).json({ error: 'Not a family member.' });
    return res.json({ rewards });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to load rewards.' });
  }
});

// Create a new reward
marketplaceRouter.post('/rewards', async (req, res) => {
  const { familyId, title, description, cost } = req.body;
  if (!familyId || !title || !cost) return res.status(400).json({ error: 'familyId, title and cost are required.' });

  try {
    const reward = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);
      const { rows: memberRows } = await client.query('SELECT role FROM family_members WHERE family_id=$1 AND user_id=$2', [familyId, me.id]);

      if (!memberRows.length) return null;
      if (memberRows[0].role !== 'main_caregiver') return { forbidden: true };

      const { rows } = await client.query(
        `INSERT INTO marketplace_rewards (family_id, creator_id, title, description, cost)
         VALUES ($1,$2,$3,$4,$5)
         RETURNING id, family_id, creator_id, title, description, cost, status, created_at`,
        [familyId, me.id, title.trim(), description ? description.trim() : null, Number(cost)]
      );
      return rows[0];
    });

    if (reward === null) return res.status(403).json({ error: 'Not a family member.' });
    if (reward.forbidden) return res.status(403).json({ error: 'Only main caregivers can create rewards.' });

    return res.status(201).json({ reward });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to create reward.' });
  }
});

// Redeem a reward
marketplaceRouter.post('/rewards/:rewardId/redeem', async (req, res) => {
  const { rewardId } = req.params;

  try {
    const result = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);

      const { rows: rewardRows } = await client.query(
        `SELECT id, family_id, cost, title, status FROM marketplace_rewards WHERE id=$1 FOR UPDATE`,
        [rewardId]
      );
      if (!rewardRows.length) return { error: { code: 404, message: 'Reward not found.' } };
      const reward = rewardRows[0];
      if (reward.status !== 'active') return { error: { code: 409, message: 'Reward is no longer active.' } };

      const { rows: buyerRows } = await client.query(
        `SELECT coin_balance FROM family_members WHERE family_id=$1 AND user_id=$2 FOR UPDATE`,
        [reward.family_id, me.id]
      );
      if (!buyerRows.length) return { error: { code: 403, message: 'Not a family member.' } };
      if (buyerRows[0].coin_balance < reward.cost) {
        return { error: { code: 409, message: 'Insufficient coins.' } };
      }

      // Deduct coins
      await client.query('UPDATE family_members SET coin_balance = coin_balance - $1 WHERE family_id=$2 AND user_id=$3', [reward.cost, reward.family_id, me.id]);

      // Log redemption
      await client.query('INSERT INTO reward_redemptions (reward_id, user_id, family_id) VALUES ($1,$2,$3)', [reward.id, me.id, reward.family_id]);

      // Burn coins from economy visibly
      await client.query(
        `INSERT INTO coin_ledger (family_id, user_id, amount, reason) VALUES ($1,$2,$3,'reward_redemption')`,
        [reward.family_id, me.id, -reward.cost]
      );

      return { data: { redeemed: true, cost: reward.cost } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.json(result.data);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to redeem reward.' });
  }
});
