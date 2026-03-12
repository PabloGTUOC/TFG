import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth } from '../db/users.js';

export const marketplaceRouter = Router();

marketplaceRouter.get('/offers/:familyId', async (req, res) => {
  const familyId = Number(req.params.familyId);
  if (!familyId) return res.status(400).json({ error: 'Invalid familyId.' });

  try {
    const offers = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);
      const member = await client.query('SELECT 1 FROM family_members WHERE family_id=$1 AND user_id=$2', [familyId, me.id]);
      if (!member.rowCount) return null;
      const { rows } = await client.query(
        `SELECT mo.id, mo.family_id, mo.created_by, mo.title, mo.coin_cost, mo.status, mo.created_at
         FROM marketplace_offers mo
         WHERE mo.family_id = $1
         ORDER BY mo.created_at DESC`,
        [familyId]
      );
      return rows;
    });

    if (offers === null) return res.status(403).json({ error: 'Not a family member.' });
    return res.json({ offers });
  } catch {
    return res.status(500).json({ error: 'Failed to load offers.' });
  }
});

marketplaceRouter.post('/offers', async (req, res) => {
  const { familyId, title, coinCost } = req.body;
  if (!familyId || !title || !coinCost) return res.status(400).json({ error: 'familyId, title and coinCost are required.' });

  try {
    const offer = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);
      const member = await client.query('SELECT 1 FROM family_members WHERE family_id=$1 AND user_id=$2', [familyId, me.id]);
      if (!member.rowCount) return null;
      const { rows } = await client.query(
        `INSERT INTO marketplace_offers (family_id, created_by, title, coin_cost)
         VALUES ($1,$2,$3,$4)
         RETURNING id, family_id, created_by, title, coin_cost, status, created_at`,
        [familyId, me.id, title.trim(), Number(coinCost)]
      );
      return rows[0];
    });

    if (!offer) return res.status(403).json({ error: 'Not a family member.' });
    return res.status(201).json({ offer });
  } catch {
    return res.status(500).json({ error: 'Failed to create offer.' });
  }
});

marketplaceRouter.post('/offers/:offerId/redeem', async (req, res) => {
  const offerId = Number(req.params.offerId);
  if (!offerId) return res.status(400).json({ error: 'Invalid offerId.' });

  try {
    const result = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);
      const { rows: offerRows } = await client.query(
        `SELECT id, family_id, created_by, coin_cost, status
         FROM marketplace_offers WHERE id=$1 FOR UPDATE`,
        [offerId]
      );
      if (!offerRows.length) return { error: { code: 404, message: 'Offer not found.' } };
      const offer = offerRows[0];
      if (offer.status !== 'open') return { error: { code: 409, message: 'Offer is not open.' } };

      const { rows: buyerRows } = await client.query(
        `SELECT coin_balance FROM family_members WHERE family_id=$1 AND user_id=$2 FOR UPDATE`,
        [offer.family_id, me.id]
      );
      if (!buyerRows.length) return { error: { code: 403, message: 'Not a family member.' } };
      if (buyerRows[0].coin_balance < offer.coin_cost) {
        return { error: { code: 409, message: 'Insufficient coins.' } };
      }

      await client.query('UPDATE family_members SET coin_balance = coin_balance - $1 WHERE family_id=$2 AND user_id=$3', [offer.coin_cost, offer.family_id, me.id]);
      await client.query('UPDATE family_members SET coin_balance = coin_balance + $1 WHERE family_id=$2 AND user_id=$3', [offer.coin_cost, offer.family_id, offer.created_by]);
      await client.query("UPDATE marketplace_offers SET status='redeemed', redeemed_by=$1, redeemed_at=NOW() WHERE id=$2", [me.id, offer.id]);
      await client.query(
        `INSERT INTO coin_ledger (family_id, user_id, amount, reason)
         VALUES ($1,$2,$3,'marketplace_redeem_spend'), ($1,$4,$3,'marketplace_redeem_earn')`,
        [offer.family_id, me.id, offer.coin_cost, offer.created_by]
      );

      return { data: { redeemed: true } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.json(result.data);
  } catch {
    return res.status(500).json({ error: 'Failed to redeem offer.' });
  }
});
