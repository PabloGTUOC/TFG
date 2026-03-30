import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { upsertUserFromAuth } from '../db/users.js';
import { runAutoCompleteSweep } from '../db/autoComplete.js';
import { validateBody, validateParams, required, string, positiveInt, isoDate } from '../middleware/validate.js';
import { assertMemberRole } from '../middleware/rbac.js';

export const activitiesRouter = Router();

// ─────────────────────────────────────────────
// GET /api/activities?familyId=X
// Returns both templates and scheduled instances
// ─────────────────────────────────────────────
activitiesRouter.get('/', async (req, res) => {
  const familyId = Number(req.query.familyId);
  if (!familyId) return res.status(400).json({ error: 'familyId query param is required.' });

  try {
    const activities = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);
      const membership = await client.query(
        'SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2',
        [familyId, user.id]
      );
      if (!membership.rowCount) return null;

      await runAutoCompleteSweep(client, familyId);

      const { rows } = await client.query(
        `SELECT a.id, a.title, a.category, a.starts_at, a.ends_at, a.duration_minutes,
                a.coin_value, a.status, a.created_by, a.assigned_to, a.is_template, a.approved_by, a.approved_at,
                a.bounty_amount, a.bounty_offered_by, fm.alias AS assigned_alias
         FROM activities a
         LEFT JOIN family_members fm ON fm.user_id = a.assigned_to AND fm.family_id = a.family_id
         WHERE a.family_id = $1
         ORDER BY a.is_template DESC, a.starts_at ASC NULLS FIRST`,
        [familyId]
      );
      return rows;
    });

    if (activities === null) return res.status(403).json({ error: 'Not a family member.' });
    return res.json({ activities });
  } catch (err) {
    console.error('GET /activities error:', err);
    return res.status(500).json({ error: 'Failed to fetch activities.' });
  }
});

// ─────────────────────────────────────────────
// POST /api/activities
// Creates a new TEMPLATE (is_template = true)
// ─────────────────────────────────────────────
activitiesRouter.post('/', validateBody({
  familyId: [required(), positiveInt()],
  title: [required(), string(1, 100)],
  durationMinutes: [required(), positiveInt()],
  coinValue: [positiveInt()],
}), async (req, res) => {
  const { familyId, title, category, durationMinutes, coinValue } = req.body;

  if (!familyId || !title || !category || !durationMinutes) {
    return res.status(400).json({ error: 'Missing required fields.' });
  }
  if (!['care', 'household'].includes(category)) {
    return res.status(400).json({ error: 'Invalid category.' });
  }
  if (Number(durationMinutes) < 15) {
    return res.status(400).json({ error: 'Minimum duration is 15 minutes.' });
  }

  try {
    const result = await withTransaction(async (client) => {
      const creator = await upsertUserFromAuth(client, req.auth);
      const membership = await client.query(
        'SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2',
        [familyId, creator.id]
      );
      if (!membership.rowCount) return { error: { code: 403, message: 'Not a family member.' } };

      const { rows } = await client.query(
        `INSERT INTO activities
           (family_id, created_by, assigned_to, title, category,
            starts_at, ends_at, duration_minutes, coin_value, status, is_template)
         VALUES ($1, $2, NULL, $3, $4, NULL, NULL, $5, $6, 'pending', true)
         RETURNING *`,
        [
          familyId, creator.id,
          title.trim(), category,
          Number(durationMinutes),
          coinValue ? Number(coinValue) : Number(durationMinutes)
        ]
      );
      return { data: rows[0] };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.status(201).json({ activity: result.data });
  } catch (err) {
    console.error('POST /activities error:', err);
    return res.status(500).json({ error: 'Failed to create activity.' });
  }
});

// ─────────────────────────────────────────────
// POST /api/activities/:activityId/approve
// Approves a template (main_caregiver only)
// ─────────────────────────────────────────────
activitiesRouter.post('/:activityId/approve', validateParams('activityId'), async (req, res) => {
  const activityId = Number(req.params.activityId);

  try {
    const result = await withTransaction(async (client) => {
      const approver = await upsertUserFromAuth(client, req.auth);

      const { rows: tmplRows } = await client.query(
        `SELECT * FROM activities WHERE id = $1 AND is_template = true FOR UPDATE`,
        [activityId]
      );
      if (!tmplRows.length) return { error: { code: 404, message: 'Template not found.' } };

      const tmpl = tmplRows[0];
      if (tmpl.status !== 'pending') {
        return { error: { code: 409, message: 'Only pending templates can be approved.' } };
      }

      const rbacErr = await assertMemberRole(client, approver.id, tmpl.family_id, 'main_caregiver');
      if (rbacErr) return rbacErr;

      await client.query(
        `UPDATE activities SET status = 'approved', approved_by = $1, approved_at = NOW() WHERE id = $2`,
        [approver.id, tmpl.id]
      );

      return { data: { approved: true } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.status(200).json(result.data);
  } catch (err) {
    console.error('POST /approve error:', err);
    return res.status(500).json({ error: 'Failed to approve activity.' });
  }
});

// ─────────────────────────────────────────────
// POST /api/activities/:activityId/schedule
// Creates a new INSTANCE row from an approved template.
// The template itself is never modified.
// ─────────────────────────────────────────────
activitiesRouter.post('/:activityId/schedule', validateParams('activityId'), validateBody({
  startsAt: [required(), isoDate()],
}), async (req, res) => {
  const activityId = Number(req.params.activityId);
  const { startsAt } = req.body;

  try {
    const result = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);

      // Load the approved template
      const { rows: tmpl } = await client.query(
        `SELECT * FROM activities
         WHERE id = $1
           AND is_template = true
           AND status = 'approved'
           AND family_id IN (SELECT family_id FROM family_members WHERE user_id = $2)`,
        [activityId, user.id]
      );
      if (!tmpl.length) {
        return { error: { code: 404, message: 'Approved activity template not found.' } };
      }

      const t = tmpl[0];
      const start = new Date(startsAt);
      const endsAtDate = new Date(start.getTime() + t.duration_minutes * 60000);
      const isPast = endsAtDate < new Date();
      const initialStatus = isPast ? 'pending_validation' : 'approved';

      // Insert a new instance row (is_template = false)
      const { rows } = await client.query(
        `INSERT INTO activities
           (family_id, created_by, assigned_to, title, category,
            starts_at, ends_at, duration_minutes, coin_value,
            status, is_template, approved_by, approved_at)
         VALUES ($1, $2, $3, $4, $5,
                 $6::timestamptz,
                 $6::timestamptz + ($7::int || ' minutes')::interval,
                 $7::int, $8::int,
                 $11, false, $9, $10)
         RETURNING *`,
        [
          t.family_id, t.created_by, user.id,
          t.title, t.category,
          start.toISOString(),
          Number(t.duration_minutes), Number(t.coin_value),
          t.approved_by, t.approved_at,
          initialStatus
        ]
      );
      // Check if this exceeds the monthly budget
      const { rows: budgetRows } = await client.query(`
        SELECT 
          f.monthly_coin_budget,
          COALESCE((
            SELECT SUM(coin_value) 
            FROM activities 
            WHERE family_id = $1 
              AND is_template = false 
              AND status IN ('approved', 'completed')
              AND date_trunc('month', starts_at) = date_trunc('month', $2::timestamptz)
          ), 0)::int as used_this_month
        FROM families f
        WHERE f.id = $1
      `, [t.family_id, start.toISOString()]);

      let warning = null;
      if (budgetRows.length) {
        if (budgetRows[0].used_this_month + Number(t.coin_value) > budgetRows[0].monthly_coin_budget) {
          warning = 'budget_exceeded';
        }
      }

      return { data: rows[0], warning };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.status(201).json({ activity: result.data, warning: result.warning });
  } catch (err) {
    console.error('POST /schedule error:', err);
    return res.status(500).json({ error: 'Failed to schedule activity.' });
  }
});

// ─────────────────────────────────────────────
// POST /api/activities/:instanceId/complete
// Completes a scheduled instance and awards coins
// ─────────────────────────────────────────────
activitiesRouter.post('/:activityId/complete', validateParams('activityId'), async (req, res) => {
  const instanceId = Number(req.params.activityId);
  if (!instanceId) return res.status(400).json({ error: 'Invalid activityId.' });

  try {
    const result = await withTransaction(async (client) => {
      const user = await upsertUserFromAuth(client, req.auth);

      const { rows: instRows } = await client.query(
        `SELECT * FROM activities
         WHERE id = $1
           AND is_template = false
           AND assigned_to = $2
           AND status = 'approved'
         FOR UPDATE`,
        [instanceId, user.id]
      );
      if (!instRows.length) {
        return { error: { code: 404, message: 'Instance not found, not yours, or already completed.' } };
      }

      const inst = instRows[0];

      await client.query(`UPDATE activities SET status = 'completed' WHERE id = $1`, [inst.id]);

      await client.query(
        `UPDATE family_members SET coin_balance = coin_balance + $1
         WHERE family_id = $2 AND user_id = $3`,
        [inst.coin_value, inst.family_id, inst.assigned_to]
      );

      await client.query(
        `INSERT INTO coin_ledger (family_id, user_id, activity_id, amount, reason)
         VALUES ($1, $2, $3, $4, 'activity_completed')`,
        [inst.family_id, inst.assigned_to, inst.id, inst.coin_value]
      );

      return { data: { completed: true, coinsAwarded: inst.coin_value } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.status(200).json(result.data);
  } catch (err) {
    console.error('POST /complete error:', err);
    return res.status(500).json({ error: 'Failed to complete activity.' });
  }
});

// ─────────────────────────────────────────────
// POST /api/activities/:id/validate
// Caretakers can validate and approve a past activity
// ─────────────────────────────────────────────
activitiesRouter.post('/:id/validate', validateParams('id'), async (req, res) => {
  const activityId = Number(req.params.id);

  try {
    const result = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);

      const { rows: actRows } = await client.query(
        `SELECT id, family_id, assigned_to, status, coin_value FROM activities WHERE id = $1 FOR UPDATE`,
        [activityId]
      );
      if (!actRows.length) return { error: { code: 404, message: 'Activity not found.' } };

      const act = actRows[0];
      if (act.status !== 'pending_validation') return { error: { code: 409, message: 'Activity is not pending validation.' } };
      if (act.assigned_to === me.id) return { error: { code: 403, message: 'You cannot validate your own retroactive activity.' } };

      // Ensure the validating user is actually in the family
      const { rows: memRows } = await client.query(
        `SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2`,
        [act.family_id, me.id]
      );
      if (!memRows.length) return { error: { code: 403, message: 'Not a family member.' } };

      // Make it completed
      await client.query(`UPDATE activities SET status = 'completed' WHERE id = $1`, [act.id]);

      // Award the coins to the assignee!
      await client.query(
        `UPDATE family_members SET coin_balance = coin_balance + $1 WHERE family_id = $2 AND user_id = $3`,
        [act.coin_value, act.family_id, act.assigned_to]
      );

      // Ledger entry
      await client.query(
        `INSERT INTO coin_ledger (family_id, user_id, activity_id, amount, reason) VALUES ($1,$2,$3,$4,'activity_completed')`,
        [act.family_id, act.assigned_to, act.id, act.coin_value]
      );

      return { data: { success: true, coinsAwarded: act.coin_value } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.json(result.data);
  } catch (err) {
    console.error('POST /validate error:', err);
    return res.status(500).json({ error: 'Failed to validate activity.' });
  }
});

// ─────────────────────────────────────────────
// POST /api/activities/:id/bounty
// Add a bounty to a shift you are assigned to
// ─────────────────────────────────────────────
activitiesRouter.post('/:id/bounty', validateParams('id'), async (req, res) => {
  const activityId = Number(req.params.id);
  const bountyAmount = Number(req.body.bountyAmount);
  if (!activityId || !bountyAmount || bountyAmount <= 0) return res.status(400).json({ error: 'Valid bountyAmount required.' });

  try {
    const result = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);

      const { rows: actRows } = await client.query(
        `SELECT family_id, assigned_to, starts_at FROM activities WHERE id = $1 FOR UPDATE`,
        [activityId]
      );
      if (!actRows.length) return { error: { code: 404, message: 'Activity not found.' } };
      const act = actRows[0];

      if (act.assigned_to !== me.id) return { error: { code: 403, message: 'Only the assigned caregiver can offer a bounty on this shift.' } };

      // Check if they have enough money to offer this bounty realistically
      const { rows: memRows } = await client.query(
        `SELECT coin_balance FROM family_members WHERE family_id = $1 AND user_id = $2`,
        [act.family_id, me.id]
      );
      if (!memRows.length || memRows[0].coin_balance < bountyAmount) {
        return { error: { code: 409, message: 'Insufficient personal coins to offer this bounty.' } };
      }

      await client.query(
        `UPDATE activities SET bounty_amount = $1, bounty_offered_by = $2 WHERE id = $3`,
        [bountyAmount, me.id, activityId]
      );
      return { data: { success: true } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.json(result.data);
  } catch (err) {
    console.error('POST /bounty error:', err);
    return res.status(500).json({ error: 'Failed to post bounty.' });
  }
});

// ─────────────────────────────────────────────
// POST /api/activities/:id/accept-bounty
// Steal the shift and successfully claim the bribe
// ─────────────────────────────────────────────
activitiesRouter.post('/:id/accept-bounty', validateParams('id'), async (req, res) => {
  const activityId = Number(req.params.id);

  try {
    const result = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);

      const { rows: actRows } = await client.query(
        `SELECT family_id, assigned_to, bounty_amount, bounty_offered_by, status FROM activities WHERE id = $1 FOR UPDATE`,
        [activityId]
      );
      if (!actRows.length) return { error: { code: 404, message: 'Activity not found.' } };
      const act = actRows[0];

      if (act.status === 'completed') return { error: { code: 409, message: 'Activity already completed.' } };
      if (act.assigned_to === me.id) return { error: { code: 409, message: 'You already own this shift.' } };
      if (!act.bounty_amount || !act.bounty_offered_by) return { error: { code: 409, message: 'No bounty available.' } };

      const offererId = act.bounty_offered_by;
      const amount = act.bounty_amount;

      // Ensure offerer still has the funds
      const { rows: memRows } = await client.query(
        `SELECT coin_balance FROM family_members WHERE family_id = $1 AND user_id = $2 FOR UPDATE`,
        [act.family_id, offererId]
      );
      if (!memRows.length || memRows[0].coin_balance < amount) {
        // Clear the invalid bounty gracefully
        await client.query(`UPDATE activities SET bounty_amount = 0, bounty_offered_by = NULL WHERE id = $1`, [activityId]);
        return { error: { code: 409, message: 'The person offering the bounty no longer has enough coins. Bounty withdrawn.' } };
      }

      // Execute Trade: Charge Offerer, Pay Accepter
      await client.query('UPDATE family_members SET coin_balance = coin_balance - $1 WHERE family_id = $2 AND user_id = $3', [amount, act.family_id, offererId]);
      await client.query('UPDATE family_members SET coin_balance = coin_balance + $1 WHERE family_id = $2 AND user_id = $3', [amount, act.family_id, me.id]);

      // Transfer ownership of shift and clear bounty metadata
      await client.query(
        `UPDATE activities SET assigned_to = $1, bounty_amount = 0, bounty_offered_by = NULL WHERE id = $2`,
        [me.id, activityId]
      );

      // Log trade on ledger
      await client.query(`INSERT INTO coin_ledger (family_id, user_id, amount, reason) VALUES ($1,$2,$3,'bounty_paid')`, [act.family_id, offererId, -amount]);
      await client.query(`INSERT INTO coin_ledger (family_id, user_id, amount, reason) VALUES ($1,$2,$3,'bounty_earned')`, [act.family_id, me.id, amount]);

      return { data: { success: true } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.json(result.data);
  } catch (err) {
    console.error('POST /accept-bounty error:', err);
    return res.status(500).json({ error: 'Failed to accept bounty.' });
  }
});

// ─────────────────────────────────────────────
// DELETE /api/activities/:id
// Drag-to-delete an upcoming shift from the calendar
// ─────────────────────────────────────────────
activitiesRouter.delete('/:id', validateParams('id'), async (req, res) => {
  const activityId = Number(req.params.id);
  if (!activityId) return res.status(400).json({ error: 'Valid activity ID required.' });

  try {
    const result = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);

      const { rows } = await client.query(
        `SELECT family_id, assigned_to, status, starts_at, bounty_amount, bounty_offered_by 
         FROM activities WHERE id = $1 FOR UPDATE`,
        [activityId]
      );
      if (!rows.length) return { error: { code: 404, message: 'Activity not found.' } };
      const act = rows[0];

      if (act.assigned_to !== me.id) return { error: { code: 403, message: 'Cannot delete an activity that is not yours.' } };
      if (act.status !== 'approved' && act.status !== 'pending_validation') return { error: { code: 409, message: 'Can only un-schedule upcoming or pending validation activities.' } };

      // Revert bounty if the person offered one recently and then panicked and dragged it off the calendar
      // Wait, bounty_amount is in Escrow. If they dragged it off, the bounty wasn't taken.
      // We don't owe them coins, because we only charged the bounty on ACCEPTANCE.

      await client.query(`DELETE FROM activities WHERE id = $1`, [activityId]);
      return { data: { success: true } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.json(result.data);
  } catch (err) {
    console.error('DELETE /activities error:', err);
    return res.status(500).json({ error: 'Failed to delete activity.' });
  }
});

// ─────────────────────────────────────────────
// POST /api/activities/:id/revert
// Honor-system uncheck of an auto-completed activity
// ─────────────────────────────────────────────
activitiesRouter.post('/:id/revert', validateParams('id'), async (req, res) => {
  const activityId = Number(req.params.id);

  try {
    const result = await withTransaction(async (client) => {
      const me = await upsertUserFromAuth(client, req.auth);

      const { rows } = await client.query(
        `SELECT family_id, assigned_to, status, coin_value FROM activities WHERE id = $1 FOR UPDATE`,
        [activityId]
      );
      if (!rows.length) return { error: { code: 404, message: 'Activity not found.' } };
      const act = rows[0];

      if (act.assigned_to !== me.id) return { error: { code: 403, message: "Cannot revert someone else's completion." } };
      if (act.status !== 'completed') return { error: { code: 409, message: 'Activity is not completed.' } };

      // Deduct the coins!
      await client.query(
        `UPDATE family_members SET coin_balance = coin_balance - $1 WHERE family_id = $2 AND user_id = $3`,
        [act.coin_value, act.family_id, me.id]
      );

      // Revert status to rejected
      await client.query(`UPDATE activities SET status = 'rejected' WHERE id = $1`, [activityId]);

      // Log the penalty to ledger
      await client.query(
        `INSERT INTO coin_ledger (family_id, user_id, activity_id, amount, reason) VALUES ($1,$2,$3,$4,'activity_reverted')`,
        [act.family_id, me.id, activityId, -act.coin_value]
      );

      return { data: { success: true, coinsDeducted: act.coin_value } };
    });

    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.json(result.data);
  } catch (err) {
    console.error('POST /revert error:', err);
    return res.status(500).json({ error: 'Failed to revert completion.' });
  }
});
