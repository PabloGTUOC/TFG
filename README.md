# CareCoins — Architecture & System Description

CareCoins is a family caregiving coordination app built as a Progressive Web App (PWA). It uses a coin reward system to make household and caregiving contributions visible and valued across a family unit.

**Stack:** Vue 3 + Vite (frontend) · Node.js / Express (backend) · PostgreSQL · Firebase Auth + FCM · Docker

---

## Part 1: Vue Frontend

### Core UI Components (`src/components/`)

- **`KpiCard.vue`** — Key Performance Indicator card. Supports label, value, unit, subtext, delta, and optional progress bar. Colour accents: primary, success, warning, danger. Compact mode for mobile.
- **`VButton.vue`** — Button with variants: `primary`, `secondary`, `outline`, `danger`. Supports disabled state and `block` (full-width) prop.
- **`VCard.vue`** — Structural container with consistent padding, rounded corners, and subtle shadow. Accepts optional `title` prop.
- **`VInput.vue`** — Text input wrapper with integrated label, placeholder, and v-model support.
- **`VSelect.vue`** — Styled native `<select>` with `{ value, label }` options array and v-model.

### Application Views (`src/views/`)

- **`App.vue`** — Root layout. Floating pill navigation bar (desktop), bottom tab bar (mobile), global success/error banners, FCM token sync on login, badge clear on visibility change.
- **`LandingView.vue`** — Brand/acquisition surface for unauthenticated visitors. Redesigned with fluid typography, scroll reveals, phone mockup, and family SVG. No glassmorphism, no false social proof.
- **`DashboardView.vue`** — Family hub. Member grid, care-dependent GDP, open bounties, KPIs, weekly calendar, absence management. iOS-compatible date/time inputs throughout.
- **`DailyView.vue`** — Interactive daily timeline. Drag-and-drop scheduling, day-swipe gesture, swipe-to-delete cards, bottom-sheet modals, task library bottom sheet, NOW divider, free-time gap indicators.
- **`ActivitiesView.vue`** — Activity template library and budget management. Mobile tab bar (Catalogue / New Activity / Budget). Budget health SVG gauge.
- **`MarketplaceView.vue`** — Reward store. Members redeem CareCoins for custom rewards. Mobile tab bar (Store / History / Create).
- **`ProfileView.vue`** — Personal area. Profile editing, avatar upload, family circle, invite caregiver (email + shareable link + QR code), monthly ledger, push notification toggle with per-category preference controls.
- **`StatsView.vue`** — ECharts analytics dashboard. Lifetime wealth, coin flow trends, category splits, completion rates, leaderboard. Mobile tab bar (Overview / Members / Economy).
- **`OnboardingView.vue`** — Setup wizard. Create family or join via email invite / token link.
- **`JoinView.vue`** — Invite link handler. Parses token from URL, prompts for alias, joins family.
- **`LoginView.vue`** — Email/password and Google OAuth authentication.

### Composables & Stores

- **`useNotifications.js`** — FCM token management. `init()` refreshes token silently on startup, `enable()` requests permission and registers token, `disable()` removes token. Foreground message handler shows `Notification` with deep-link `onclick`. Guards against duplicate listener registration.
- **`useCurrentFamily.js`** — Derives current family, role, and familyId from the family store.
- **`stores/auth.js`** — Firebase Auth listener, token management, request helper with auth headers. Toasts auto-dismiss (success 3.5s, errors 5s).
- **`stores/family.js`** — Family data, member profiles, actor list. Fetched once on auth and refreshed after mutations.

### PWA Features

CareCoins is a fully installable PWA:
- **Service worker** (`firebase-messaging-sw.js`) — generated at build time from env vars via a Vite plugin. Handles background FCM messages, shows system notifications, sets app badge, and navigates to the relevant screen on tap (`notificationclick`).
- **App badge** — `navigator.setAppBadge()` called on notification arrival (foreground and background). Cleared on `visibilitychange` when app is focused.
- **Deep links** — every notification carries a `data.url` field; tapping navigates directly to the relevant view (`/activities`, `/dashboard`, etc.).
- **Manifest** — standalone display, custom icons (192×512), theme colour `#8b5cf6`.

---

## Part 2: Backend

Express.js REST API protected by Firebase Auth middleware and rate limiters. PostgreSQL via `pg` pool. All DB mutations use `withTransaction` for atomicity.

### Middleware

- **`auth.js` (`requireAuth`)** — Verifies Firebase ID token from `Authorization` header. Lazy-initialises Firebase Admin SDK.
- **`rbac.js` (`requireRole`)** — Role-based access control. Checks user role within a specific family.
- **`validate.js`** — Request body/params validation with composable rule functions (`required`, `string`, `positiveInt`, `isoDate`, `oneOf`, `email`).
- **`audit.js`** — Request logging middleware.

### Utilities

- **`utils/notify.js`** — Firebase Cloud Messaging send helpers. Three exported functions: `notifyUser`, `notifyFamilyCaregivers`, `notifyFamilyAll`. Each accepts an optional `prefKey` that filters recipients via a SQL `LEFT JOIN notification_preferences` — users who have opted out of that notification type are excluded. Automatically prunes stale/invalid FCM tokens after send. Attaches `data.url` and `webpush.fcmOptions.link` for deep-link navigation on tap.
- **`utils/mailer.js`** — Email sending via Resend. Used for caregiver invitations. Gracefully no-ops (console log) when `RESEND_API_KEY` is not set.
- **`db/pool.js`** — PostgreSQL pool + `withTransaction` helper (BEGIN / COMMIT / ROLLBACK).
- **`db/users.js`** — `upsertUserFromAuth` and `assertActiveMember` query helpers.
- **`db/autoComplete.js`** — Sweeps approved scheduled activities past their end time to `completed` and distributes coin payouts atomically.
- **`db/defaultActivities.js`** — Seeds a new family with a starter set of activity templates.

### API Routes

#### `/api/me` — Personal & Account
| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Current user profile, families, pending requests, actors |
| PATCH | `/profile` | Update display name, email, family alias |
| POST | `/avatar` | Upload profile avatar (JPEG/PNG/WebP, max 2 MB) |
| GET | `/invites` | Pending email invitations for this user |
| GET | `/login-history` | Last 20 login events |
| GET | `/ledger` | Monthly coin transaction ledger |
| POST | `/login-event` | Record login event |
| POST | `/logout-event` | Close login session |
| POST | `/fcm-token` | Register FCM push token |
| DELETE | `/fcm-token` | Remove FCM push token |
| GET | `/notification-preferences` | Per-category notification opt-in/out settings |
| PUT | `/notification-preferences` | Save notification preferences (5 boolean fields) |
| DELETE | `/` | Delete account (anonymise user, cancel activities, Firebase Auth delete) |

#### `/api/families` — Family Management
| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | List families user belongs to |
| POST | `/` | Create family (sets budget from care-object hours) |
| DELETE | `/:familyId` | Request family deletion (multi-caregiver approval flow) |
| GET | `/:familyId/budget` | Budget health: monthly budget, used, remaining, base rate |
| GET | `/:familyId/members` | List active members |
| PATCH | `/:familyId/members/:userId/role` | Change member role |
| POST | `/:familyId/actors` | Add care dependent |
| DELETE | `/:familyId/actors/:actorId` | Remove dependent |
| POST | `/:familyId/actors/:actorId/avatar` | Upload dependent avatar |
| GET | `/:familyId/invitations` | List pending email invitations |
| POST | `/:familyId/invitations` | Send email invitation via Resend |
| POST | `/join-request` | Accept email-based invitation |
| POST | `/join-by-token` | Join via shareable link token |
| POST | `/:familyId/invite-links` | Generate shareable invite link (optional expiry / max-uses) |
| GET | `/:familyId/invite-links` | List active invite links |
| DELETE | `/:familyId/invite-links/:linkId` | Revoke invite link |
| GET | `/:familyId/deletion-requests` | List pending deletion requests |
| POST | `/:familyId/deletion-requests/:id/approve` | Approve deletion |
| POST | `/:familyId/deletion-requests/:id/reject` | Reject deletion |

#### `/api/activities` — Task Engine
| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | List activity templates for a family |
| POST | `/` | Create template (pending caregiver approval if not caregiver) |
| DELETE | `/:id` | Delete template |
| POST | `/:id/approve` | Approve pending template |
| POST | `/:id/schedule` | Schedule a task instance on the calendar |
| POST | `/:id/recurrence` | Create recurring future instances |
| POST | `/:id/complete` | Mark task as completed |
| POST | `/:id/validate` | Validate completed task → mint coins |
| POST | `/:id/revert` | Un-check a completed task |
| POST | `/:id/bounty` | Attach a coin bounty to a task |
| POST | `/:id/accept-bounty` | Accept bounty, reassign task to self |

#### `/api/marketplace`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/rewards/:familyId` | List active rewards |
| POST | `/rewards` | Create reward (caregivers only) |
| POST | `/rewards/:rewardId/redeem` | Redeem reward, deduct coins |
| PATCH | `/rewards/:rewardId` | Update reward |
| DELETE | `/rewards/:rewardId` | Archive reward |

#### `/api/absences`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | List absences |
| POST | `/` | Log absence |
| DELETE | `/:id` | Remove absence |

#### `/api/dashboard`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/:familyId` | Aggregate dashboard data (members, GDP, KPIs, activity log, coin distribution) |

#### `/api/stats`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/:familyId` | Full analytics payload for ECharts (wealth, flow, categories, leaderboard, marketplace) |

---

## Part 3: Database Schema

Defined in `backend/src/db/schema.sql`. Migrations in `backend/scripts/` — all applied automatically by the `db-init` Docker service on startup.

| Table | Purpose |
|-------|---------|
| `users` | Firebase-linked accounts. `firebase_uid`, `email`, `display_name`, `avatar_url`, soft-delete flag. |
| `families` | Core tenant. `name`, `monthly_coin_budget`, `created_by`. |
| `family_members` | User↔Family join. `role` (caregiver/member), `alias`, `coin_balance`, `status` (active/pending/inactive). |
| `family_invitations` | Email invite records. `status` (pending/accepted/declined). Unique on `(family_id, email)`. |
| `invite_links` | Shareable UUID tokens. Optional `max_uses`, `expires_at`, `revoked` flag. Usage counter incremented on join. |
| `actors` | Care dependents (child, pet, elderly) and person placeholders. Linked to family, optionally to a user. |
| `activities` | Both templates (`is_template=true`) and scheduled instances. Tracks `status`, `coin_value`, `bounty_amount`, `assigned_to`, `approved_by`. |
| `coin_ledger` | Immutable transaction log. Every coin movement recorded with `reason` and optional `activity_id`. |
| `marketplace_rewards` | Custom rewards created by caregivers. `cost`, `max_uses`, `valid_from/until`, `status` (active/archived). |
| `reward_redemptions` | Log of each redemption: `reward_id`, `user_id`, `family_id`, `redeemed_at`. |
| `absences` | Time-off periods. `start_time`, `end_time`, `title`. Used to block scheduling conflicts. |
| `login_history` | Per-session login/logout timestamps with IP and user-agent. |
| `fcm_tokens` | FCM push registration tokens. One user can have multiple tokens (multi-device). Stale tokens auto-pruned after failed sends. Index on `user_id`. |
| `notification_preferences` | Per-user opt-in/out for 5 notification categories: `activity_assigned`, `activity_validated`, `activity_completed`, `bounty_offered`, `family_events`. Defaults to all true if no row exists. |
| `family_deletion_requests` | Deletion request raised by a caregiver. `status` (pending/approved/rejected). |
| `family_deletion_approvals` | Per-caregiver approval vote on a deletion request. |

---

## Part 4: Push Notifications

CareCoins uses Firebase Cloud Messaging (FCM) for mobile push notifications.

**Token lifecycle:**
1. User enables notifications in Profile → browser permission requested → FCM token saved to `fcm_tokens` via `POST /api/me/fcm-token`.
2. On app startup (if already granted), `init()` in `useNotifications.js` silently re-fetches and upserts the token — handles rotation.
3. Stale/invalid tokens are automatically deleted after a failed send.

**Send path (backend):**
- `notifyUser(userId, payload)` — sends to all tokens for one user.
- `notifyFamilyCaregivers(familyId, excludeUserId, payload)` — sends to all active caregivers in a family.
- `notifyFamilyAll(familyId, excludeUserId, payload)` — sends to all active members.
- All three accept `prefKey` to filter out users who opted out of that notification type.

**Notification events and their `prefKey`:**

| Event | Recipients | prefKey |
|-------|-----------|---------|
| New activity / pending approval | Caregivers | `activity_assigned` |
| Activity validated (coins earned) | Assigned user | `activity_validated` |
| Activity completed | All family | `activity_completed` |
| Bounty offered | All family | `bounty_offered` |
| Family deletion / member joined | Caregivers | `family_events` |

**Deep links:** Every notification carries `data.url`. Tapping a background notification navigates the app to the relevant view. Foreground notifications use `Notification.onclick` + `router.push`.

**Badge:** `navigator.setAppBadge()` on notification arrival. `navigator.clearAppBadge()` on notification tap and on app focus (`visibilitychange`).

---

## Part 5: Activity Lifecycle

1. **Template creation** — caregiver defines title, category, duration, coin value. Non-caregivers submit for approval.
2. **Scheduling** — approved template dragged onto the daily timeline. Supports one-off and recurring instances.
3. **Bounty (optional)** — assignee can't do the task, offers coins from their balance. Any family member can accept, taking over the task.
4. **Completion** — assignee marks task done → status becomes `pending_validation`.
5. **Validation** — a different caregiver validates → coins minted in `coin_ledger`, user balance updated.
6. **Auto-complete** — `autoComplete.js` sweep transitions approved past-due tasks automatically.

---

## Part 6: Local Development

### Prerequisites
- Node.js 20+, npm
- PostgreSQL 12+ (local instance on port 5433, or use Docker)
- Firebase project with Auth + FCM enabled

### Environment variables
Copy `.env.example` to `backend/.env` and set:
- `DATABASE_URL` — Postgres connection string
- `GOOGLE_APPLICATION_CREDENTIALS` — path to Firebase service account JSON
- `RESEND_API_KEY` — (optional) email sending; omit to use console mock
- `EMAIL_FROM` — sender address for invitation emails

Frontend env vars (set as Docker build args or in a `.env` file for local dev):
- `VITE_FIREBASE_*` — Firebase client config (6 fields)
- `VITE_FIREBASE_VAPID_KEY` — FCM web push VAPID key

### Running locally

```bash
# Backend
cd backend && npm install && npm run dev   # hot-reload on :3000

# Frontend
cd frontend && npm install && npm run dev  # Vite dev server on :5173
```

**Important:** The Docker `db-init` service runs all migrations automatically on `docker compose up`. For local dev against a bare Postgres instance, run migrations manually once:

```bash
cd backend
node -e "
import('./src/db/pool.js').then(async ({ pool }) => {
  const fs = await import('fs/promises');
  const files = [
    'src/db/schema.sql',
    'scripts/migrate-deletion.sql',
    'scripts/migrate-fcm.sql',
    'scripts/migrate-fcm-index.sql',
    'scripts/migrate-notif-prefs.sql',
  ];
  for (const f of files) { await pool.query(await fs.readFile(f, 'utf8')); console.log('✓', f); }
  await pool.end();
});
"
```

Any new migration added to `scripts/init-db.js` must also be run manually against your local database.

### Running with Docker (recommended)

```bash
docker compose up --build -d
```

Runs Postgres 16, `db-init` (schema + all migrations), Node API, and NGINX-served frontend on port 80. Firebase credentials must be placed at `./firebase-credentials.json`.

### Frontend tests

```bash
cd frontend && npm run test
```

Runs Vitest unit/integration tests for Pinia stores (`auth`, `family`).

### Testing push notifications locally

1. Enable notifications in Profile (requires `VITE_FIREBASE_VAPID_KEY` set).
2. In Chrome DevTools → Application → Service Workers → find `firebase-messaging-sw.js` → use the **Push** button with payload:
   ```json
   {"notification":{"title":"Test","body":"Hello"},"data":{"url":"/activities"}}
   ```
3. For mobile badge and home-screen notification appearance, deploy to a server with HTTPS or expose localhost via ngrok.

> macOS note: Chrome notifications also require system-level permission. Check **System Settings → Notifications → Google Chrome → Allow Notifications**.
