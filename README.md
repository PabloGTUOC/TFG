# CareCoins — Architecture & System Description

CareCoins is a family caregiving coordination app built as a Progressive Web App (PWA). It uses a coin reward system to make household and caregiving contributions visible and valued across a family unit.

**Stack:** Vue 3 + Vite (frontend) · Node.js / Express (backend) · PostgreSQL · Firebase Auth + FCM · Docker

---

## Part 1: Vue Frontend

### Design System

CareCoins uses a single design token system defined in `DESIGN.md` and `frontend/src/style.css`.

- **Typeface:** Plus Jakarta Sans (500 / 700 / 800) loaded via Google Fonts. Hierarchy is achieved through weight and size only — no second typeface.
- **Colour palette:** Semantic-only. Blue (`#2563EB`) = action, green (`#16A34A`) = done, amber (`#D97706`) = household, red (`#DC2626`) = danger. Each colour has one job.
- **Radius tokens:** `--r-sm` 8px · `--r-md` 16px · `--r-lg` 24px · `--r-pill` 9999px
- **Activity card colours:** Driven by status, not by assignee. `pending` → surface/border/ink. `completed-care` → success. `completed-household` → warning. `rejected` → danger-soft.

### Core UI Components (`src/components/`)

- **`KpiCard.vue`** — Key Performance Indicator card. Supports label, value, unit, subtext, and optional progress bar. Colour accents: primary, success, warning, danger, ink.
- **`VButton.vue`** — Button with variants: `primary`, `secondary`, `outline`, `danger`. Full pill radius. Supports disabled state and `block` (full-width) prop.
- **`VCard.vue`** — Structural container with consistent padding, rounded corners (`--r-lg`), and ambient shadow. Accepts optional `title` prop.
- **`VInput.vue`** — Text input wrapper with integrated label, placeholder, and v-model support. Pill radius matching buttons.
- **`VSelect.vue`** — Styled native `<select>` with `{ value, label }` options array and v-model.

### Daily View Sub-components (`src/components/daily/`)

Extracted from `DailyView.vue` to keep it as a thin coordinator:

- **`TaskLibrary.vue`** — Desktop task sidebar. Self-contained search, category filters, and draggable template rows.
- **`DailyModals.vue`** — All 7 modals in one declarative component: schedule time, recurrence, delete recurring, offer bounty, accept bounty, log absence, absence detail. Communicates via props + emits.

### Profile Sub-components (`src/components/profile/`)

Extracted from `ProfileView.vue`:

- **`AccountSettings.vue`** — Profile form (name, email, alias), user avatar upload, notification preference toggles.
- **`FamilyCircle.vue`** — Care dependents grid, add/remove actors, email invite form, shareable link + QR code generator, family deletion flow.
- **`WalletPanel.vue`** — Coin balance widget, recent ledger preview, full monthly ledger with month picker, activity insights card.

### Application Views (`src/views/`)

- **`App.vue`** — Root layout. Floating pill navigation bar (desktop), bottom tab bar (mobile), global success/error banners, FCM token sync on login, badge clear on visibility change.
- **`LandingView.vue`** — Brand/acquisition surface for unauthenticated visitors. Fluid typography, scroll reveals, phone mockup, and family SVG.
- **`DashboardView.vue`** — Family hub. Member grid, care-dependent GDP, open bounties, KPIs, weekly calendar, absence management.
- **`DailyView.vue`** — Interactive daily timeline. Drag-and-drop scheduling (desktop), day-swipe gesture, swipe-to-delete cards, mobile task sheet, NOW divider, free-time gap indicators. Uses `TaskLibrary`, `DailyModals`, and the three composables below.
- **`ActivitiesView.vue`** — Activity template library and budget management. Mobile tab bar (Catalogue / New Activity / Budget). Budget health SVG gauge.
- **`MarketplaceView.vue`** — Reward store. Members redeem CareCoins for custom rewards. Mobile tab bar (Store / History / Create).
- **`ProfileView.vue`** — Personal area shell. Tab container (`My Profile` / `Family` / `Wallet`) delegating to `AccountSettings`, `FamilyCircle`, `WalletPanel`. Owns data loading and the confirm dialog.
- **`StatsView.vue`** — ECharts analytics dashboard. Lifetime wealth, coin flow trends, category splits, completion rates, leaderboard. Mobile tab bar (Overview / Members / Economy).
- **`OnboardingView.vue`** — Setup wizard. Create family or join via email invite / token link.
- **`JoinView.vue`** — Invite link handler. Parses token from URL, prompts for alias, joins family.
- **`LoginView.vue`** — Email/password and Google OAuth authentication.

### Composables (`src/composables/`)

- **`useTimeline.js`** — Core timeline logic extracted from `DailyView`. Exports `scheduledToday` (overlap-aware positioning algorithm), `completedToday`, `todayCoins`, `nowLineTop`, `nowIndex`, `scrollToNow`, `formatGap`, and `getCardStyle` (status → CSS token mapping).
- **`useCardSwipe.js`** — Swipe-to-delete state and touch handlers for the mobile timeline cards. Calls an `onDismiss` callback after the dismiss animation.
- **`useDaySwipe.js`** — Horizontal swipe gesture for day navigation. Fires `onNavigate(±1)` on a qualifying swipe.
- **`useNotifications.js`** — FCM token management. `init()` refreshes token silently on startup, `enable()` requests permission and registers token, `disable()` removes token. Foreground message handler shows `Notification` with deep-link `onclick`.
- **`useCurrentFamily.js`** — Derives current family, role, and familyId from the family store.

### Stores (`src/stores/`)

- **`auth.js`** — Firebase Auth listener, token management, request helper with auth headers. Toasts auto-dismiss (success 3.5s, errors 5s).
- **`family.js`** — Family data, member profiles, actor list. Fetched once on auth and refreshed after mutations.

### PWA Features

CareCoins is a fully installable PWA:
- **Service worker** (`firebase-messaging-sw.js`) — generated at build time from env vars via a Vite plugin. Handles background FCM messages, shows system notifications, sets app badge, and navigates to the relevant screen on tap.
- **App badge** — `navigator.setAppBadge()` called on notification arrival. Cleared on `visibilitychange` when app is focused.
- **Deep links** — every notification carries a `data.url` field; tapping navigates directly to the relevant view.
- **Manifest** — standalone display, custom icons (192 × 512), theme colour `#2563EB` (brand blue).

---

## Part 2: Backend

Express.js REST API protected by Firebase Auth middleware and rate limiters. PostgreSQL via `pg` pool. All DB mutations use `withTransaction` for atomicity.

### Service Layer (`src/services/`)

Business logic is separated from HTTP routing into pure service modules. Each service function receives a DB `client` (already inside a transaction) and returns `{ data, ... }` or `{ error: { code, message } }`. This makes them independently testable without spinning up HTTP.

- **`activityService.js`** — `listActivities`, `createActivity`, `approveActivity`, `scheduleActivity`, `createRecurrence`, `completeActivity`, `validateActivity`, `offerBounty`, `acceptBounty`, `deleteActivity`, `revertActivity`.
- **`familyService.js`** — `listFamilies`, `getFamilyBudget`, `createFamily`, `deleteFamily`, `getDeletionRequests`, `approveDeletion`, `rejectDeletion`.
- **`memberService.js`** — `listMembers`, `listInvitations`, `createInvitation`, `approveMember`, `updateMemberRole`, `joinByInvitation`, `joinByToken`, `addActor`, `removeActor`, `updateActorAvatar`.

### Middleware (`src/middleware/`)

- **`auth.js` (`requireAuth`)** — Verifies Firebase ID token from `Authorization` header. Supports the Firebase Auth Emulator via `FIREBASE_AUTH_EMULATOR_HOST` env var (used in E2E tests).
- **`rbac.js` (`requireRole`, `assertMemberRole`)** — Role-based access control. Checks user role within a specific family.
- **`validate.js`** — Request body/params validation with composable rule functions (`required`, `string`, `positiveInt`, `isoDate`, `oneOf`, `email`).
- **`audit.js`** — Request logging middleware.

### Utilities (`src/utils/`)

- **`notify.js`** — Firebase Cloud Messaging send helpers. `notifyUser`, `notifyFamilyCaregivers`, `notifyFamilyAll`. Each accepts a `prefKey` that filters recipients via `notification_preferences`. Stale/invalid tokens pruned after failed sends.
- **`mailer.js`** — Email sending via Resend. Used for caregiver invitations. Gracefully no-ops (console log) when `RESEND_API_KEY` is not set.

### DB Helpers (`src/db/`)

- **`pool.js`** — PostgreSQL pool + `withTransaction` helper (BEGIN / COMMIT / ROLLBACK).
- **`users.js`** — `upsertUserFromAuth` and `assertActiveMember` query helpers.
- **`autoComplete.js`** — Sweeps approved scheduled activities past their end time to `completed` and distributes coin payouts atomically.
- **`defaultActivities.js`** — Seeds a new family with a starter set of activity templates.

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
| GET | `/` | List activity templates and instances for a family |
| POST | `/` | Create template |
| DELETE | `/:id` | Delete template or un-schedule instance |
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

#### `/api/absences`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | List absences |
| POST | `/` | Log absence |
| DELETE | `/:id` | Remove absence |

#### `/api/dashboard`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/:familyId` | Aggregate dashboard data (members, GDP, KPIs, activity log) |

#### `/api/stats`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/:familyId` | Full analytics payload for ECharts |

---

## Part 3: Database Schema

Defined in `backend/src/db/schema.sql`. Migrations in `backend/scripts/` — applied automatically by the `db-init` Docker service on startup.

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
| `fcm_tokens` | FCM push registration tokens. One user can have multiple tokens (multi-device). Stale tokens auto-pruned after failed sends. |
| `notification_preferences` | Per-user opt-in/out for 5 notification categories. Defaults to all true if no row exists. |
| `family_deletion_requests` | Deletion request raised by a caregiver. `status` (pending/approved/rejected). |
| `family_deletion_approvals` | Per-caregiver approval vote on a deletion request. |

---

## Part 4: Push Notifications

CareCoins uses Firebase Cloud Messaging (FCM) for mobile push notifications.

**Token lifecycle:**
1. User enables notifications in Profile → browser permission requested → FCM token saved via `POST /api/me/fcm-token`.
2. On app startup (if already granted), `init()` in `useNotifications.js` silently re-fetches and upserts the token — handles rotation.
3. Stale/invalid tokens are automatically deleted after a failed send.

**Send path (backend):**
- `notifyUser(userId, payload)` — sends to all tokens for one user.
- `notifyFamilyCaregivers(familyId, excludeUserId, payload)` — sends to all active caregivers.
- `notifyFamilyAll(familyId, excludeUserId, payload)` — sends to all active members.
- All three accept `prefKey` to filter out users who opted out of that category.

**Notification events:**

| Event | Recipients | prefKey |
|-------|-----------|---------|
| New activity / pending approval | Caregivers | `activity_assigned` |
| Activity validated (coins earned) | Assigned user | `activity_validated` |
| Activity completed | All family | `activity_completed` |
| Bounty offered | All family | `bounty_offered` |
| Family deletion / member joined | Caregivers | `family_events` |

**Deep links:** Every notification carries `data.url`. Tapping a background notification navigates the app to the relevant view. Foreground notifications use `Notification.onclick` + `router.push`.

---

## Part 5: Activity Lifecycle

1. **Template creation** — caregiver defines title, category, duration, coin value.
2. **Approval** — a caregiver approves the template before it can be scheduled.
3. **Scheduling** — approved template dragged onto the daily timeline (desktop) or selected from the task sheet (mobile). Supports recurring instances.
4. **Bounty (optional)** — assignee can't do the task, offers coins from their balance. Any family member can accept and take over.
5. **Completion** — assignee marks task done → status becomes `pending_validation`.
6. **Validation** — a different caregiver validates → coins minted in `coin_ledger`, user balance updated.
7. **Auto-complete** — `autoComplete.js` sweep transitions approved past-due tasks automatically.

---

## Part 6: Automated Tests

141 tests across three layers. See `automatic-testing-E2E.md` for full test descriptions.

### Layer 1 — Backend Unit Tests (44 tests)

**Runner:** Node.js built-in `--test`. **Location:** `backend/tests/`.  
No database required — all tests use mock DB clients.

```bash
cd backend && npm test
```

Covers: activity lifecycle (complete, validate, bounty, revert), family budget calculation, family deletion consensus flow, invite token validation, member management.

### Layer 2 — Frontend Unit Tests (25 tests)

**Runner:** Vitest with `vmThreads` pool. **Location:** `frontend/src/composables/__tests__/`, `frontend/src/stores/__tests__/`.

```bash
cd frontend && npm test
```

Covers: `getCardStyle` status/category mapping (6 cases), `formatGap` time formatting (4 cases), `useTimeline` positioning algorithm (8 cases), auth and family stores (7 cases).

### Layer 3 — E2E Integration Tests (72 tests)

**Runner:** Playwright 1.60. **Browsers:** Chromium + WebKit (Safari). **Location:** `frontend/e2e/`.  
Uses the Firebase Auth Emulator — no real Google account needed, fully offline.

```bash
cd frontend && npm run test:e2e
```

Requires three services (started automatically by Playwright if not already running):
- Firebase Auth Emulator on port 9099 (`firebase emulators:start --only auth`)
- Backend in test mode: `npm run dev:test` (sets `FIREBASE_AUTH_EMULATOR_HOST`)
- Frontend in test mode: `npm run dev:test` (sets `VITE_USE_EMULATOR=true`)

**Test files:**
- `landing.spec.js` — public pages, PWA meta, font loading
- `dashboard.spec.js` — auth guard redirects, mobile viewport
- `happy-paths.spec.js` — dashboard, daily view, schedule task, profile, navigation (Chromium + WebKit)
- `two-users.spec.js` — validate activity and bounty flow with two simultaneous browser contexts
- `onboarding.spec.js` — first-time user creates a family
- `marketplace.spec.js` — reward listing, redeem, and create
- `notifications.spec.js` — notification permission detection and preference toggles

---

## Part 7: Local Development

### Prerequisites
- Node.js 20+, npm
- PostgreSQL 12+ (local instance on port 5433, or use Docker)
- Firebase project with Auth + FCM enabled

### Environment variables

Copy `.env.example` to `backend/.env` and set:
- `DATABASE_URL` — Postgres connection string
- `FIREBASE_PROJECT_ID` — Firebase project ID
- `GOOGLE_APPLICATION_CREDENTIALS` — path to Firebase service account JSON
- `RESEND_API_KEY` — (optional) email sending; omit to use console mock
- `EMAIL_FROM` — sender address for invitation emails

Frontend env vars (in `frontend/.env` for local dev):
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

### Running with Docker (recommended)

```bash
docker compose up --build -d
```

Runs Postgres 16, `db-init` (schema + all migrations), Node API, and NGINX-served frontend on port 80. Firebase credentials must be placed at `./firebase-credentials.json`.

### Testing push notifications locally

1. Enable notifications in Profile (requires `VITE_FIREBASE_VAPID_KEY` set).
2. In Chrome DevTools → Application → Service Workers → find `firebase-messaging-sw.js` → use the **Push** button with payload:
   ```json
   {"notification":{"title":"Test","body":"Hello"},"data":{"url":"/activities"}}
   ```
3. For mobile badge and home-screen notification appearance, deploy to a server with HTTPS or expose localhost via ngrok.

> macOS note: Chrome notifications also require system-level permission. Check **System Settings → Notifications → Google Chrome → Allow Notifications**.
