import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth, assertActiveMember } from '../db/users.js';
import { validateBody, validateParams, required, string, positiveInt } from '../middleware/validate.js';
import { requireRole } from '../middleware/rbac.js';
import multer from 'multer';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const dir = path.join(__dirname, '../../uploads/families', req.params.familyId, 'actors', req.params.actorId);
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

      if (!await assertActiveMember(client, familyId, user.id)) return null;

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

      await client.query(
        `INSERT INTO family_members (family_id, user_id, role, status, alias)
         VALUES ($1, $2, 'caregiver', 'active', $3)`,
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


// Accept an email-based invitation — only works if the user's email has a pending invite.
familiesRouter.post('/join-request', validateBody({
  familyId: [required(), positiveInt()],
  alias: [string(1, 50)],
}), async (req, res) => {
  const { familyId, alias } = req.body;

  try {
    const result = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);

      if (!user.email) {
        return { error: { code: 400, message: 'Your account has no email address. Use an invite link instead.' } };
      }

      const { rows: invRows } = await client.query(
        `SELECT id FROM family_invitations WHERE family_id = $1 AND email = $2 AND status = 'pending'`,
        [familyId, user.email.toLowerCase()]
      );
      if (!invRows.length) {
        return { error: { code: 403, message: 'No pending invitation found for your email address.' } };
      }

      await client.query(
        `INSERT INTO family_members (family_id, user_id, role, status, alias)
         VALUES ($1, $2, 'caregiver', 'active', $3)
         ON CONFLICT (family_id, user_id) DO UPDATE
           SET status = 'active', alias = COALESCE(EXCLUDED.alias, family_members.alias)`,
        [familyId, user.id, alias ? alias.trim() : null]
      );

      await client.query(`UPDATE family_invitations SET status = 'accepted' WHERE id = $1`, [invRows[0].id]);

      await client.query(
        `INSERT INTO actors (family_id, user_id, actor_type, name)
         VALUES ($1, $2, 'person', $3)
         ON CONFLICT (family_id, user_id) DO NOTHING`,
        [familyId, user.id, user.display_name || user.email]
      );

      return { data: { success: true, status: 'active' } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.status(200).json(result.data);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to accept invitation.' });
  }
});

// Join a family via a shareable invite link token.
familiesRouter.post('/join-by-token', async (req, res) => {
  const { token, alias } = req.body;
  if (!token || typeof token !== 'string') {
    return res.status(400).json({ error: 'token is required.' });
  }

  try {
    const result = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);

      const { rows: linkRows } = await client.query(
        `SELECT id, family_id, max_uses, uses, expires_at, revoked FROM invite_links WHERE id = $1 FOR UPDATE`,
        [token]
      );
      if (!linkRows.length) return { error: { code: 404, message: 'Invalid invite link.' } };

      const link = linkRows[0];
      if (link.revoked) return { error: { code: 410, message: 'This invite link has been revoked.' } };
      if (link.expires_at && new Date(link.expires_at) < new Date()) {
        return { error: { code: 410, message: 'This invite link has expired.' } };
      }
      if (link.max_uses !== null && link.uses >= link.max_uses) {
        return { error: { code: 410, message: 'This invite link has reached its maximum uses.' } };
      }

      const { rows: existing } = await client.query(
        `SELECT status FROM family_members WHERE family_id = $1 AND user_id = $2`,
        [link.family_id, user.id]
      );
      if (existing.length && existing[0].status === 'active') {
        return { error: { code: 409, message: 'You are already an active member of this family.' } };
      }

      await client.query(
        `INSERT INTO family_members (family_id, user_id, role, status, alias)
         VALUES ($1, $2, 'caregiver', 'active', $3)
         ON CONFLICT (family_id, user_id) DO UPDATE
           SET status = 'active', alias = COALESCE(EXCLUDED.alias, family_members.alias)`,
        [link.family_id, user.id, alias ? alias.trim() : null]
      );

      await client.query(
        `INSERT INTO actors (family_id, user_id, actor_type, name)
         VALUES ($1, $2, 'person', $3)
         ON CONFLICT (family_id, user_id) DO NOTHING`,
        [link.family_id, user.id, user.display_name || user.email]
      );

      await client.query(`UPDATE invite_links SET uses = uses + 1 WHERE id = $1`, [link.id]);

      return { data: { success: true, familyId: link.family_id } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.json(result.data);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to join family.' });
  }
});

familiesRouter.patch('/:familyId/members/:userId/role',
  validateParams('familyId', 'userId'),
  requireRole('caregiver', r => r.params.familyId),
  async (req, res) => {
    const familyId = Number(req.params.familyId);
    const userId = Number(req.params.userId);
    const { role } = req.body;

    if (!['caregiver', 'member'].includes(role)) {
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
  requireRole('caregiver', r => r.params.familyId),
  async (req, res) => {
    const familyId = Number(req.params.familyId);
    const userId = Number(req.params.userId);

    try {
      const result = await withTransaction(async (client) => {
        const { rowCount } = await client.query(
          `UPDATE family_members
           SET status = 'active', role = 'caregiver'
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
  requireRole('caregiver', r => r.params.familyId),
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

familiesRouter.delete('/:familyId/actors/:actorId',
  validateParams('familyId', 'actorId'),
  requireRole('caregiver', r => r.params.familyId),
  async (req, res) => {
    const familyId = Number(req.params.familyId);
    const actorId = Number(req.params.actorId);

    try {
      const result = await withTransaction(async (client) => {
        const { rows } = await client.query(
          `SELECT * FROM actors WHERE id = $1 AND family_id = $2`,
          [actorId, familyId]
        );
        if (!rows.length) return { error: { code: 404, message: 'Actor not found.' } };

        const actor = rows[0];
        if (actor.actor_type !== 'pet') {
          return { error: { code: 403, message: 'Only pets can be removed.' } };
        }

        const budgetDecrease = actor.care_time === 'full_time' ? 720 : 360;
        await client.query(`DELETE FROM actors WHERE id = $1`, [actorId]);
        await client.query(
          `UPDATE families SET monthly_coin_budget = monthly_coin_budget - $1 WHERE id = $2`,
          [budgetDecrease, familyId]
        );
        return { data: actor };
      });

      if (result.error) return res.status(result.error.code).json({ error: result.error.message });
      return res.json({ message: 'Pet removed successfully.' });
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: 'Failed to remove pet.' });
    }
  });

familiesRouter.post('/:familyId/actors/:actorId/avatar',
  upload.single('avatar'),
  validateParams('familyId', 'actorId'),
  requireRole('caregiver', r => r.params.familyId),
  async (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'No avatar image uploaded.' });

    const familyId = Number(req.params.familyId);
    const actorId = Number(req.params.actorId);
    const avatarUrl = `/uploads/families/${req.params.familyId}/actors/${req.params.actorId}/${req.file.filename}`;

    try {
      const result = await withTransaction(async (client) => {
        const { rows } = await client.query(
          `UPDATE actors SET avatar_url = $1 WHERE id = $2 AND family_id = $3 RETURNING *`,
          [avatarUrl, actorId, familyId]
        );
        if (!rows.length) return { error: { code: 404, message: 'Actor not found.' } };
        return { data: rows[0] };
      });
      if (result.error) return res.status(result.error.code).json({ error: result.error.message });
      return res.json({ avatar_url: result.data.avatar_url });
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: 'Failed to upload actor avatar.' });
    }
  });

// ─────────────────────────────────────────────
// GET /api/families/:familyId/invitations
// Returns all pending invitations for the family (any member)
// ─────────────────────────────────────────────
familiesRouter.get('/:familyId/invitations', validateParams('familyId'), async (req, res) => {
  const familyId = Number(req.params.familyId);
  try {
    const rows = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      if (!await assertActiveMember(client, familyId, user.id)) return null;
      const { rows } = await client.query(
        `SELECT id, email, name, status, created_at
         FROM family_invitations
         WHERE family_id = $1 AND status = 'pending'
         ORDER BY created_at DESC`,
        [familyId]
      );
      return rows;
    });
    if (rows === null) return res.status(403).json({ error: 'Not a family member.' });
    return res.json({ invitations: rows });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to fetch invitations.' });
  }
});

// ─────────────────────────────────────────────
// GET /api/families/:familyId/members
// Returns all active human members for the family (with avatars)
// ─────────────────────────────────────────────
familiesRouter.get('/:familyId/members', validateParams('familyId'), async (req, res) => {
  const familyId = Number(req.params.familyId);
  try {
    const rows = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      if (!await assertActiveMember(client, familyId, user.id)) return null;
      const { rows } = await client.query(
        `SELECT fm.user_id as id, COALESCE(fm.alias, u.display_name, u.email) as name, fm.role, fm.status, u.avatar_url
         FROM family_members fm
         JOIN users u ON u.id = fm.user_id
         WHERE fm.family_id = $1 AND fm.status = 'active'
         ORDER BY u.created_at ASC`,
        [familyId]
      );
      return rows;
    });
    if (rows === null) return res.status(403).json({ error: 'Not a family member.' });
    return res.json({ members: rows });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to fetch members.' });
  }
});

// ─────────────────────────────────────────────
// POST /api/families/:familyId/invitations
// Creates an email invitation (caregiver only)
// ─────────────────────────────────────────────
familiesRouter.post('/:familyId/invitations',
  validateParams('familyId'),
  validateBody({ email: [required(), string(1, 255)] }),
  requireRole('caregiver', r => r.params.familyId),
  async (req, res) => {
    const familyId = Number(req.params.familyId);
    const { email, name } = req.body;

    // Basic email format check
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ error: 'Invalid email address.' });
    }

    try {
      const invitation = await withTransaction(async (client) => {
        const user = await upsertUserFromAuth(client, req.auth);
        const { rows } = await client.query(
          `INSERT INTO family_invitations (family_id, email, name, invited_by)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (family_id, email) DO UPDATE
             SET status = 'pending', name = EXCLUDED.name, invited_by = EXCLUDED.invited_by
           RETURNING id, email, name, status, created_at`,
          [familyId, email.toLowerCase().trim(), name?.trim() || null, user.id]
        );
        return rows[0];
      });
      return res.status(201).json({ invitation });
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: 'Failed to create invitation.' });
    }
  });
