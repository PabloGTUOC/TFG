# Platform Admin & Family Management — Gap Analysis and Plan

> Status: proposal. Companion docs: `docs/backend.md`, `docs/database-schema.md`, `docs/PRODUCT.md`.

---

## 1. Current status

### What exists today

All management functionality in CareCoins is **family-scoped and self-service**:

| Area | Current capability | Who can do it |
|---|---|---|
| Roles | `caregiver` > `member`, stored per-family in `family_members.role` | — |
| Membership | Invite by email, invite links, approve join requests, change roles | Caregivers of that family |
| Actors | Add/remove objects of care, upload avatars | Caregivers of that family |
| Family lifecycle | Create; delete only via unanimous caregiver approval flow | Caregivers of that family |
| Budget | `families.monthly_coin_budget` (default 1000, ±720/±360 per full/part-time actor). **Read-only API** (`GET /api/families/:id/budget`) — no endpoint edits it directly | Nobody (derived only) |
| Audit | `login_history` only | — |

### The gap

There is **no platform-level administrator** concept at any layer:

1. **Identity**: the `users` table has no global role column. The only "admin" strings in the codebase are the `firebase-admin` SDK (`src/middleware/auth.js`, `src/utils/notify.js`).
2. **Authorization**: `src/middleware/rbac.js` only knows family-scoped roles. Every route resolves data through the *requester's own membership* (`upsertUserFromAuth` + membership check) — there is no code path that can see across families.
3. **API**: no `/api/admin/*` router; no cross-family listing, search, or intervention endpoints (e.g. fix a family whose only caregiver left, remove abusive content, adjust a budget).
4. **UI**: the Flutter app (`fluterFront/lib/screens/`) has only end-user screens; nothing role-gated beyond caregiver/member.
5. **Monetization**: no plan/subscription/payment concept anywhere — no tables, no provider integration, no feature limits to attach a paid tier to. `monthly_coin_budget` is the only plan-like config and it is not directly editable.

### Assets that make closing the gap cheap

- Clean service layer (`familyService`, `memberService`) an admin API can reuse.
- Established patterns: `requireRole` middleware to mirror, `validateBody/Params`, `scripts/migrate-*.sql` migration convention, vitest service tests, per-user rate limiting already in `app.js`.
- Firebase auth already verifies identity server-side; custom claims are available for defense-in-depth.

---

## 2. Plan

### Phase 1 — Platform admin foundation (backend)

1. **Schema** (new `scripts/migrate-platform-role.sql` + `schema.sql` update):
   ```sql
   ALTER TABLE users ADD COLUMN platform_role TEXT NOT NULL DEFAULT 'user'
     CHECK (platform_role IN ('user', 'admin'));

   CREATE TABLE admin_audit_log (
     id BIGSERIAL PRIMARY KEY,
     admin_id BIGINT NOT NULL REFERENCES users(id),
     action TEXT NOT NULL,
     target_type TEXT NOT NULL,
     target_id TEXT,
     payload JSONB,
     created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
   );
   ```
2. **Promotion path**: small script (`scripts/promote-admin.js <email>`) — admins are never self-service.
3. **Middleware**: `requireAdmin` in `src/middleware/rbac.js`, same shape as `requireRole` but checking `users.platform_role = 'admin'`. Optionally mirror the flag into a Firebase custom claim later; the DB check is authoritative.
4. **Mounting**: `app.use('/api/admin', requireAuth, requireAdmin, adminLimiter, adminRouter)` — stricter rate limit than user routes.
5. **Audit**: every mutating admin call writes one `admin_audit_log` row inside the same transaction.

### Phase 2 — Admin family management API

New `src/routes/admin.js` + `src/services/adminService.js` (reusing family/member services where possible):

| Endpoint | Purpose |
|---|---|
| `GET /api/admin/families?search=&page=` | Paged list: id, name, created_at, member count, budget, coins used this month |
| `GET /api/admin/families/:id` | Detail: members + roles + status, actors, invitations, invite links, budget usage |
| `PATCH /api/admin/families/:id` | Rename; **set `monthly_coin_budget` explicitly** (first real budget override) |
| `DELETE /api/admin/families/:id` | Direct deletion (bypasses the unanimous-approval flow; audited) |
| `PATCH /api/admin/families/:id/members/:userId` | Change role / deactivate — recovery for "orphaned" families with no active caregiver |
| `DELETE /api/admin/families/:id/invite-links/:linkId` | Revoke abusive/leaked links |
| `GET /api/admin/users?search=` | User lookup with memberships and soft-delete state |

Tests: `backend/tests/adminService.test.js` following the existing vitest pattern (including 403 coverage for non-admins on every route).

### Phase 3 — Admin UI (Flutter)

Smallest surface that works, consistent with the existing app:

1. `GET /api/me` additionally returns `platformRole`.
2. Shell/profile shows an **Admin** entry only when `platformRole == 'admin'` (server still enforces; UI gating is convenience only).
3. Screens: `admin_families_screen.dart` (searchable list) → `admin_family_detail_screen.dart` (members, actors, budget edit, delete) → `admin_users_screen.dart`. Strings go through the existing `l10n/*.arb` files.

A separate web admin panel is deliberately out of scope for now — one client, one design system, and the API is the reusable part if a web panel is wanted later.

### Phase 4 — Plan/entitlement model (payment-plan-ready, no payments yet)

Make the system *plan-aware* first; the payment provider becomes a bolt-on later.

1. **Schema**:
   ```sql
   CREATE TABLE plans (
     code TEXT PRIMARY KEY,            -- 'free', 'plus', …
     name TEXT NOT NULL,
     price_cents INTEGER NOT NULL DEFAULT 0,
     currency TEXT NOT NULL DEFAULT 'EUR',
     billing_period TEXT NOT NULL DEFAULT 'monthly',
     limits JSONB NOT NULL DEFAULT '{}',    -- max_members, max_actors, max_active_rewards, …
     features JSONB NOT NULL DEFAULT '{}',
     is_default BOOLEAN NOT NULL DEFAULT false,
     active BOOLEAN NOT NULL DEFAULT true
   );

   CREATE TABLE family_plans (
     family_id BIGINT PRIMARY KEY REFERENCES families(id) ON DELETE CASCADE,
     plan_code TEXT NOT NULL REFERENCES plans(code),
     status TEXT NOT NULL DEFAULT 'active'
       CHECK (status IN ('trialing', 'active', 'past_due', 'canceled')),
     current_period_end TIMESTAMPTZ,
     provider TEXT,                    -- future: 'stripe'
     provider_customer_id TEXT,
     provider_subscription_id TEXT,
     updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
   );
   ```
2. Seed a `free` default plan; assign it in `familyService.createFamily`; backfill existing families in the migration.
3. **Admin API**: CRUD on `plans`; `PUT /api/admin/families/:id/plan` to assign/override (comp accounts, trials).
4. **Entitlement helper**: `getFamilyEntitlements(client, familyId)` returning merged plan limits; called at the natural enforcement points (member join/approve, actor add, reward create). Start with soft warnings (like the existing `budget_exceeded` pattern in `activityService`), tighten to hard limits once plans are real.
5. **Deferred on purpose**: Stripe (or other) integration — checkout, webhooks (`family_plans.status` transitions), customer portal. The provider columns above keep that a contained follow-up.

### Phase 5 — Hardening & docs

- Update `docs/backend.md` (§RBAC, new router), `docs/database-schema.md`, `docs/PRODUCT.md`.
- QA entries in `QA.md`: non-admin gets 403 on every admin route; admin actions appear in `admin_audit_log`; plan limits enforced.
- Consider requiring recent re-auth (Firebase `auth_time`) for destructive admin actions.

---

## 3. Sequencing and effort (rough)

| Phase | Size | Depends on |
|---|---|---|
| 1 Foundation | S (1–2 days) | — |
| 2 Admin family API | M (2–4 days) | 1 |
| 3 Flutter admin UI | M (3–5 days) | 2 |
| 4 Plans/entitlements | M (3–4 days) | 1 (API), 2 (admin UI hooks) |
| 5 Hardening/docs | S (1 day) | rolling |

Phases 1+2 alone already close the operational gap (support/recovery/oversight). Phase 4 can proceed in parallel after Phase 1 if monetization design is the priority.
