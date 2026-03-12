import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth } from '../db/users.js';
import { computeDurationMinutes } from '../utils.js';

export const activitiesRouter = Router();

activitiesRouter.get('/', async (req, res) => {
  const familyId = Number(req.query.familyId);

  if (!familyId) {
    return res.status(400).json({ error: 'familyId query param is required.' });
  }

  try {
    const activities = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);

      const membership = await client.query(
        'SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2',
        [familyId, user.id]
      );

      if (!membership.rowCount) {
        return null;
      }

      const { rows } = await client.query(
        `SELECT id, title, category, starts_at, ends_at, duration_minutes, coin_value, status, created_by, assigned_to
         FROM activities
         WHERE family_id = $1
         ORDER BY starts_at ASC`,
        [familyId]
      );

      return rows;
    });

    if (activities === null) {
      return res.status(403).json({ error: 'Not a family member.' });
    }

    return res.json({ activities });
  } catch {
    return res.status(500).json({ error: 'Failed to fetch activities.' });
  }
});

activitiesRouter.post('/', async (req, res) => {
  const { familyId, assignedToUserId, title, category, startsAt, endsAt, coinValue } = req.body;

  if (!familyId || !assignedToUserId || !title || !category || !startsAt || !endsAt) {
    return res.status(400).json({ error: 'Missing required fields.' });
  }

  if (!['care', 'household'].includes(category)) {
    return res.status(400).json({ error: 'Invalid category.' });
  }

  const starts = new Date(startsAt);
  const ends = new Date(endsAt);
  const durationMinutes = computeDurationMinutes(startsAt, endsAt);

  if (durationMinutes === null || durationMinutes < 15) {
    return res.status(400).json({ error: 'Invalid schedule. Minimum duration is 15 minutes.' });
  }

  try {
    const activity = await withTransaction(async (client) => {
      const creator = await upsertUserFromAuth(client, req.auth);

      const membership = await client.query(
        'SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2',
        [familyId, creator.id]
      );

      if (!membership.rowCount) {
        return { error: { code: 403, message: 'Not a family member.' } };
      }

      const overlap = await client.query(
        `SELECT 1
         FROM activities
         WHERE family_id = $1
           AND assigned_to = $2
           AND status IN ('pending', 'approved')
           AND tstzrange(starts_at, ends_at, '[)') && tstzrange($3::timestamptz, $4::timestamptz, '[)')`,
        [familyId, assignedToUserId, starts.toISOString(), ends.toISOString()]
      );

      if (overlap.rowCount > 0) {
        return { error: { code: 409, message: 'Time-slot overlaps with an existing activity.' } };
      }

      const { rows } = await client.query(
        `INSERT INTO activities (
          family_id, created_by, assigned_to, title, category,
          starts_at, ends_at, duration_minutes, coin_value, status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending')
        RETURNING id, family_id, created_by, assigned_to, title, category, starts_at, ends_at, duration_minutes, coin_value, status`,
        [
          familyId,
          creator.id,
          assignedToUserId,
          title.trim(),
          category,
          starts.toISOString(),
          ends.toISOString(),
          durationMinutes,
          coinValue || durationMinutes
        ]
      );

      return { data: rows[0] };
    });

    if (activity.error) {
      return res.status(activity.error.code).json({ error: activity.error.message });
    }

    return res.status(201).json({ activity: activity.data });
  } catch {
    return res.status(500).json({ error: 'Failed to create activity.' });
  }
});

activitiesRouter.post('/:activityId/approve', async (req, res) => {
  const activityId = Number(req.params.activityId);

  if (!activityId) {
    return res.status(400).json({ error: 'Invalid activityId.' });
  }

  try {
    const result = await withTransaction(async (client) => {
      const approver = await upsertUserFromAuth(client, req.auth);

      const { rows: activityRows } = await client.query(
        `SELECT a.id, a.family_id, a.assigned_to, a.coin_value, a.status
         FROM activities a
         WHERE a.id = $1
         FOR UPDATE`,
        [activityId]
      );

      if (!activityRows.length) {
        return { error: { code: 404, message: 'Activity not found.' } };
      }

      const activity = activityRows[0];

      if (activity.status !== 'pending') {
        return { error: { code: 409, message: 'Only pending activities can be approved.' } };
      }

      const { rows: roleRows } = await client.query(
        `SELECT role FROM family_members
         WHERE family_id = $1 AND user_id = $2`,
        [activity.family_id, approver.id]
      );

      if (!roleRows.length || roleRows[0].role !== 'main_caregiver') {
        return { error: { code: 403, message: 'Only main caregivers can approve activities.' } };
      }

      await client.query(
        `UPDATE activities
         SET status = 'approved', approved_by = $1, approved_at = NOW()
         WHERE id = $2`,
        [approver.id, activity.id]
      );

      await client.query(
        `UPDATE family_members
         SET coin_balance = coin_balance + $1
         WHERE family_id = $2 AND user_id = $3`,
        [activity.coin_value, activity.family_id, activity.assigned_to]
      );

      await client.query(
        `INSERT INTO coin_ledger (family_id, user_id, activity_id, amount, reason)
         VALUES ($1, $2, $3, $4, 'activity_approved')`,
        [activity.family_id, activity.assigned_to, activity.id, activity.coin_value]
      );

      return { data: { approved: true } };
    });

    if (result.error) {
      return res.status(result.error.code).json({ error: result.error.message });
    }

    return res.status(200).json(result.data);
  } catch {
    return res.status(500).json({ error: 'Failed to approve activity.' });
  }
});
