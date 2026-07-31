/**
 * Platform admin API (docs/admin-family-management-plan.md).
 *
 * Mounted in app.js as:
 *   app.use('/api/admin', requireAuth, adminLimiter, requireAdmin, adminRouter)
 * so every handler here can assume req.auth and req.adminUser are set.
 *
 * PRIVACY BOUNDARY: handlers expose family registry + billing state only —
 * never family internals. See src/services/adminService.js.
 */
import { Router } from 'express';
import { withTransaction } from '../db/pool.js';
import { validateParams } from '../middleware/validate.js';
import { notifyFamilyCaregivers } from '../utils/notify.js';
import * as adminService from '../services/adminService.js';

export const adminRouter = Router();

// Self-check for admin clients: confirms the caller passed requireAdmin.
// The Flutter shell uses this to gate the admin section (server remains
// authoritative on every real endpoint regardless).
adminRouter.get('/status', (req, res) => {
  res.json({ ok: true, adminId: req.adminUser.id });
});

adminRouter.get('/families', async (req, res) => {
  const { search, status, page, pageSize } = req.query;
  try {
    const result = await withTransaction((client) =>
      adminService.listFamilies(client, { search, status, page, pageSize }));
    return res.json(result.data);
  } catch (err) {
    console.error('Admin family list failed:', err);
    return res.status(500).json({ error: 'Failed to list families.' });
  }
});

adminRouter.get('/families/:familyId', validateParams('familyId'), async (req, res) => {
  const familyId = Number(req.params.familyId);
  try {
    const result = await withTransaction((client) =>
      adminService.getFamilyRegistry(client, familyId));
    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    return res.json(result.data);
  } catch (err) {
    console.error('Admin family detail failed:', err);
    return res.status(500).json({ error: 'Failed to fetch family.' });
  }
});

adminRouter.post('/families/:familyId/notify-inactive', validateParams('familyId'), async (req, res) => {
  const familyId = Number(req.params.familyId);
  try {
    const result = await withTransaction((client) =>
      adminService.requestInactivityNotice(client, req.adminUser.id, familyId));
    if (result.error) return res.status(result.error.code).json({ error: result.error.message });
    notifyFamilyCaregivers(familyId, 0, {
      title: 'Is your family still using CareCoins?',
      body: 'Your family has been quiet for a while. Open the app to keep it active.',
      url: '/dashboard',
      prefKey: 'family_events',
    });
    return res.json(result.data);
  } catch (err) {
    console.error('Admin inactivity notice failed:', err);
    return res.status(500).json({ error: 'Failed to send inactivity notice.' });
  }
});
