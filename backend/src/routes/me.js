import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth } from '../db/users.js';

export const meRouter = Router();

meRouter.get('/', async (req, res) => {
  try {
    const payload = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      const { rows: families } = await client.query(
        `SELECT fm.family_id, f.name, fm.role, fm.coin_balance
         FROM family_members fm
         JOIN families f ON f.id = fm.family_id
         WHERE fm.user_id = $1
         ORDER BY f.created_at DESC`,
        [user.id]
      );

      return { user, families };
    });

    return res.json(payload);
  } catch {
    return res.status(500).json({ error: 'Failed to load current user.' });
  }
});

meRouter.patch('/profile', async (req, res) => {
  const { displayName, email } = req.body;

  try {
    const user = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);
      const { rows } = await client.query(
        `UPDATE users
         SET display_name = COALESCE($1, display_name),
             email = COALESCE($2, email)
         WHERE id = $3
         RETURNING id, firebase_uid, email, display_name`,
        [displayName || null, email || null, me.id]
      );
      return rows[0];
    });

    return res.json({ user });
  } catch {
    return res.status(500).json({ error: 'Failed to update profile.' });
  }
});

meRouter.get('/login-history', async (req, res) => {
  try {
    const rows = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      const { rows } = await client.query(
        `SELECT id, login_at, ip_address, user_agent
         FROM login_history
         WHERE user_id = $1
         ORDER BY login_at DESC
         LIMIT 20`,
        [user.id]
      );
      return rows;
    });

    return res.json({ loginHistory: rows });
  } catch {
    return res.status(500).json({ error: 'Failed to load login history.' });
  }
});
