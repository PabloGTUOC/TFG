import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth, assertActiveMember } from '../db/users.js';
import { validateBody, string, email } from '../middleware/validate.js';
import multer from 'multer';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const dir = path.join(__dirname, '../../uploads/users', req.auth.uid);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    cb(null, 'avatar' + path.extname(file.originalname).toLowerCase());
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 2 * 1024 * 1024 },
  fileFilter: function (_req, file, cb) {
    if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG, PNG, and WebP images are allowed.'));
    }
  }
});

export const meRouter = Router();

meRouter.get('/', async (req, res) => {
  try {
    const payload = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      const { rows: families } = await client.query(
        `SELECT fm.family_id, f.name, fm.role, fm.alias, fm.coin_balance
         FROM family_members fm
         JOIN families f ON f.id = fm.family_id
         WHERE fm.user_id = $1 AND fm.status = 'active'
         ORDER BY f.created_at DESC`,
        [user.id]
      );

      const { rows: pendingRequests } = await client.query(
        `SELECT fm.family_id, f.name
         FROM family_members fm
         JOIN families f ON f.id = fm.family_id
         WHERE fm.user_id = $1 AND fm.status = 'pending'`,
        [user.id]
      );

      const { rows: actors } = await client.query(
        `SELECT a.id, a.family_id, a.name, a.actor_type, a.avatar_url, a.care_time
         FROM actors a
         JOIN family_members fm ON fm.family_id = a.family_id
         WHERE fm.user_id = $1 AND fm.status = 'active' AND a.actor_type != 'person'`,
        [user.id]
      );

      return { user, families, pendingRequests, actors };
    });

    return res.json(payload);
  } catch (err) {
    console.error('ME ROUTE ERROR:', err);
    return res.status(500).json({ error: 'Failed to load current user.' });
  }
});

meRouter.post('/avatar', (req, res, next) => {
  upload.single('avatar')(req, res, (err) => {
    if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large. Maximum size is 2 MB.' });
    }
    if (err) {
      return res.status(400).json({ error: err.message });
    }
    next();
  });
}, async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No avatar image uploaded.' });
  }

  const avatarUrl = `/uploads/users/${req.auth.uid}/${req.file.filename}`;

  try {
    const user = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);
      await client.query(
        `UPDATE users SET avatar_url = $1 WHERE id = $2`,
        [avatarUrl, me.id]
      );
      me.avatar_url = avatarUrl;
      return me;
    });

    return res.json({ avatar_url: user.avatar_url });
  } catch (err) {
    console.error('Avatar upload error:', err);
    return res.status(500).json({ error: 'Failed to upload avatar.' });
  }
});
meRouter.post('/login-event', async (req, res) => {
  try {
    const eventId = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      const { rows } = await client.query(
        `INSERT INTO login_history (user_id, ip_address, user_agent)
         VALUES ($1, $2, $3)
         RETURNING id`,
        [user.id, req.ip || null, req.headers['user-agent'] || null]
      );
      return rows[0].id;
    });
    return res.json({ eventId });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to record login event.' });
  }
});

meRouter.post('/logout-event', async (req, res) => {
  const { eventId } = req.body;
  try {
    await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      if (eventId) {
        await client.query(
          `UPDATE login_history SET logout_at = NOW() WHERE id = $1 AND user_id = $2`,
          [eventId, user.id]
        );
      } else {
        // Fallback: update the most recent open session
        await client.query(
          `UPDATE login_history SET logout_at = NOW() 
           WHERE id = (
             SELECT id FROM login_history 
             WHERE user_id = $1 AND logout_at IS NULL 
             ORDER BY login_at DESC LIMIT 1
           )`,
          [user.id]
        );
      }
    });
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to record logout event.' });
  }
});

meRouter.patch('/profile', validateBody({
  displayName: [string(1, 100)],
  email: [string(1, 255), email()],
  alias: [string(1, 50)],
}), async (req, res) => {
  const { displayName, email, familyId, alias } = req.body;

  try {
    const user = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);
      const { rows } = await client.query(
        `UPDATE users
         SET display_name = COALESCE($1, display_name),
             email = COALESCE($2, email)
         WHERE id = $3
         RETURNING id, firebase_uid, email, display_name, avatar_url`,
        [displayName || null, email || null, me.id]
      );

      if (familyId && alias !== undefined) {
        if (await assertActiveMember(client, familyId, me.id)) {
          await client.query('UPDATE family_members SET alias = $1 WHERE family_id = $2 AND user_id = $3', [alias.trim() || null, familyId, me.id]);
        }
      }
      return rows[0];
    });

    return res.json({ user });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to update profile.' });
  }
});

meRouter.get('/invites', async (req, res) => {
  try {
    const invites = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      if (!user.email) return [];
      const { rows } = await client.query(
        `SELECT fi.id, fi.family_id, f.name AS family_name, fi.name AS inviter_name, fi.created_at
         FROM family_invitations fi
         JOIN families f ON f.id = fi.family_id
         WHERE fi.email = $1 AND fi.status = 'pending'
         ORDER BY fi.created_at DESC`,
        [user.email.toLowerCase()]
      );
      return rows;
    });
    return res.json({ invites });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to fetch invitations.' });
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

meRouter.get('/ledger', async (req, res) => {
  const familyId = Number(req.query.familyId);
  const monthStr = req.query.month; // Expected YYYY-MM
  if (!familyId || !monthStr) return res.status(400).json({ error: 'familyId and month (YYYY-MM) required.' });

  try {
    const data = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);

      if (!await assertActiveMember(client, familyId, user.id)) return null;

      const startOfMonth = new Date(`${monthStr}-01T00:00:00Z`);
      if (isNaN(startOfMonth.getTime())) throw new Error("Invalid month format");

      const { rows: ledger } = await client.query(`
        SELECT cl.id, cl.amount, cl.reason, cl.created_at, a.title as activity_title, a.duration_minutes
        FROM coin_ledger cl
        LEFT JOIN activities a ON a.id = cl.activity_id
        WHERE cl.family_id = $1 AND cl.user_id = $2
          AND cl.created_at >= date_trunc('month', $3::timestamptz)
          AND cl.created_at < date_trunc('month', $3::timestamptz) + interval '1 month'
        ORDER BY cl.created_at DESC
      `, [familyId, user.id, startOfMonth.toISOString()]);

      return { ledger };
    });

    if (!data) return res.status(403).json({ error: 'Not a family member.' });
    return res.json(data);
  } catch (err) {
    console.error('Ledger Error:', err);
    return res.status(500).json({ error: 'Failed to fetch ledger.' });
  }
});
