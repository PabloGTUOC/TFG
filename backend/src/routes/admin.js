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

export const adminRouter = Router();

// Self-check for admin clients: confirms the caller passed requireAdmin.
// The Flutter shell uses this to gate the admin section (server remains
// authoritative on every real endpoint regardless).
adminRouter.get('/status', (req, res) => {
  res.json({ ok: true, adminId: req.adminUser.id });
});
