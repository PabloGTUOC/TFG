# Code Structure vs README Requirements

This document compares the repository structure and implementation to `README.md` and `backend/README.md`.

## Implemented coverage now present

- Monorepo split and tech stack (`backend/` + `frontend/`) remain aligned.
- Backend routes for families and activities are implemented.
- Frontend implements workflow views for all existing activity/family operations.
- Additional previously-missing flows are now implemented:
  - User profile + login history views (`/api/me`, `/api/me/profile`, `/api/me/login-history`)
  - Family role management (`PATCH /api/families/:familyId/members/:userId/role`)
  - Monthly recalculation (`POST /api/families/:familyId/recalculate-monthly`)
  - Dashboard/calendar summary (`GET /api/dashboard/:familyId`)
  - Marketplace flow (`/api/marketplace/offers`, list/create/redeem)
- Database now includes additional entities that were missing before:
  - `actors`
  - `login_history`
  - `marketplace_offers`
- Frontend now uses Pinia and includes PWA support via `vite-plugin-pwa`.
- Docker + Cloudflare deployment starter files were added (`docker-compose.yml`, Dockerfiles, cloudflared config).

## Current status

The previously identified roadmap gaps in this file have been implemented as baseline flows in backend APIs and frontend views.
