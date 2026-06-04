# Frontend — Technical Reference

CareCoins frontend is a **Vue 3 Single-Page Application** built with Vite, deployed as a Progressive Web App behind an nginx reverse proxy.

---

## Table of Contents

1. [Tech Stack](#1-tech-stack)
2. [Project Structure](#2-project-structure)
3. [Authentication Flow](#3-authentication-flow)
4. [State Management (Pinia)](#4-state-management-pinia)
5. [Routing & Navigation Guards](#5-routing--navigation-guards)
6. [Views](#6-views)
7. [Components](#7-components)
8. [Composables](#8-composables)
9. [Push Notifications (FCM)](#9-push-notifications-fcm)
10. [Progressive Web App (PWA)](#10-progressive-web-app-pwa)
11. [API Communication](#11-api-communication)
12. [Build & Deployment](#12-build--deployment)
13. [Testing](#13-testing)

---

## 1. Tech Stack

| Dependency | Version | Role |
|---|---|---|
| Vue 3 | `^3.5` | UI framework (Composition API + `<script setup>`) |
| Vite | `^5.4` | Build tool and dev server |
| Pinia | `^2.3` | Global state management |
| Vue Router | `^4.6` | Client-side routing |
| Firebase JS SDK | `^10.14` | Authentication (client side) + FCM token management |
| ECharts + vue-echarts | `^6` / `^8` | Charts in StatsView |
| Lucide Vue Next | `^1.0` | Icon library |
| qrcode | `^1.5` | QR code generation for invite links |
| vite-plugin-pwa | `^0.20` | Service worker + Web App Manifest generation |
| Vitest | `^2.0` | Unit testing (jsdom environment) |
| Playwright | `^1.60` | End-to-end testing |

**Node.js requirement:** ≥ 20 (matches backend)

---

## 2. Project Structure

```
frontend/
├── src/
│   ├── App.vue                    # Root component — nav chrome, toast overlay
│   ├── main.js                    # App entry: createApp, Pinia, Router, auth listener
│   ├── firebase.js                # Firebase app init, auth export, FCM helper
│   ├── style.css                  # Global CSS variables (design tokens) + resets
│   │
│   ├── stores/
│   │   ├── auth.js                # Auth store — user, token, login/logout, request()
│   │   └── family.js              # Family store — profile, families, actors
│   │
│   ├── router/
│   │   └── index.js               # Route definitions + navigation guard
│   │
│   ├── views/
│   │   ├── LandingView.vue        # Marketing / brand surface
│   │   ├── LoginView.vue          # Email/password + Google sign-in
│   │   ├── OnboardingView.vue     # New user wizard (create family)
│   │   ├── JoinView.vue           # Accept invite link or email invitation
│   │   ├── DashboardView.vue      # Family overview — balances, KPIs
│   │   ├── DailyView.vue          # Day timeline (signature view)
│   │   ├── ActivitiesView.vue     # Kanban task library
│   │   ├── MarketplaceView.vue    # Reward shop + redemption history
│   │   ├── StatsView.vue          # Charts and monthly statistics
│   │   └── ProfileView.vue        # Account + family management + wallet
│   │
│   ├── components/
│   │   ├── VButton.vue            # Design system button (primary / secondary / danger)
│   │   ├── VCard.vue              # Design system card container
│   │   ├── VInput.vue             # Design system text input
│   │   ├── VSelect.vue            # Design system select
│   │   ├── KpiCard.vue            # Metric tile used on Dashboard and Stats
│   │   ├── daily/
│   │   │   ├── DailyModals.vue    # All inline modals for DailyView actions
│   │   │   └── TaskLibrary.vue    # Activity template picker (schedule from template)
│   │   └── profile/
│   │       ├── AccountSettings.vue  # Avatar, display name, alias, email
│   │       ├── FamilyCircle.vue     # Members, invitations, actors, invite links
│   │       └── WalletPanel.vue      # Coin balance, ledger, login history
│   │
│   ├── composables/
│   │   ├── useTimeline.js         # Derives timeline rows + gap items from activities
│   │   ├── useCardSwipe.js        # Touch swipe-to-action on activity cards
│   │   ├── useDaySwipe.js         # Horizontal swipe to navigate days
│   │   ├── useNotifications.js    # FCM permission request + token registration
│   │   └── useCurrentFamily.js    # Reactive shortcut to the selected family
│   │
│   ├── constants/
│   │   └── status.js              # Activity status labels, colors, allowed transitions
│   │
│   └── utils/
│       └── avatarStyle.js         # Generates deterministic per-member color from MEMBER_THEMES
│
├── public/
│   ├── firebase-messaging-sw.js   # FCM background message SW (generated into public/ at build start by vite.config.js)
│   ├── favicon.svg                # App favicon
│   ├── apple-touch-icon.png       # iOS home screen icon
│   ├── icon-mark.svg              # Brand mark (used in UI)
│   ├── icon-192.png               # PWA icon (standard)
│   └── icon-512.png               # PWA icon (maskable)
│
├── e2e/                           # Playwright test suites
├── vite.config.js                 # Vite + PWA + Firebase SW plugin config
├── playwright.config.js           # Playwright configuration
├── Dockerfile                     # Multi-stage build → nginx container
└── nginx.conf                     # Serves SPA + proxies /api and /uploads to backend
```

---

## 3. Authentication Flow

Authentication is handled entirely by **Firebase Authentication** on the client side. The backend never stores passwords — it only validates Firebase ID tokens.

### Sign-in methods
1. **Email / Password** — `signInWithEmailAndPassword` (Firebase SDK)
2. **Google Sign-In** — `signInWithPopup` with `GoogleAuthProvider`
3. **Register** — `createUserWithEmailAndPassword`

### Token lifecycle

```
Firebase → ID Token (JWT, ~1 hour TTL)
         → stored in Pinia auth store (in-memory)
         → sent on every API call as: Authorization: Bearer <token>
         → Firebase SDK refreshes automatically via onIdTokenChanged
```

**`onIdTokenChanged`** is the single listener driving all auth state. It fires on:
- First load (restores persisted session)
- Login / logout
- Token refresh (every ~1 hour)

When the token changes:
1. The new token is stored in `authStore.token`.
2. On first auth-ready: `familyStore.fetchUserData()` is called to sync the backend user record and fetch family memberships.
3. On sign-out: the Pinia family store is reset (`$reset()`).

### Backend sync

After every login, the frontend calls `POST /api/me/login-event`. The backend:
1. Upserts the user record (creates if first login, no-ops if exists).
2. Inserts a `login_history` row with the IP and user agent.
3. Returns an `eventId` stored in `authStore.loginEventId`.

On logout, `POST /api/me/logout-event` is called with the `eventId` to close the session record.

### Token persistence

| Mode | Persistence |
|---|---|
| Production | `indexedDBLocalPersistence` — survives browser close |
| Emulator / E2E tests | `browserLocalPersistence` (localStorage) — Playwright `storageState()` can capture it |

---

## 4. State Management (Pinia)

Two stores manage all global state. They are kept deliberately thin — views and composables own local state for UI concerns.

### `auth.js` — Auth Store

```js
state: {
  apiBase,       // Backend URL (from VITE_API_BASE env var or auto-detected)
  user,          // Firebase User object or null
  token,         // Current Firebase ID token string
  authReady,     // Boolean — true once the first onIdTokenChanged fires
  loginEventId,  // ID of the open login_history row
  success,       // Toast success message (auto-dismissed after 3.5 s)
  error,         // Toast error message (auto-dismissed after 5 s)
}
```

**Key actions:**
- `initAuthListener()` — call once on app mount; sets up `onIdTokenChanged`.
- `waitForAuth()` — returns a Promise that resolves when `authReady` is true. Used by the router guard to block navigation until the auth state is known.
- `login(email, password)` / `register(email, password)` / `loginWithGoogle()`
- `logout()` — calls backend logout-event, then `signOut(auth)`.
- `request(path, options)` — thin `fetch` wrapper with a 10 s timeout. All API calls go through this.
- `authHeaders()` — returns `{ 'Content-Type': 'application/json', Authorization: 'Bearer ...' }`.
- `setSuccess(msg)` / `setError(msg)` — sets toast state with auto-dismiss timers.

### `family.js` — Family Store

```js
state: {
  profile,         // Internal user object from the backend (id, display_name, email, avatar_url)
  families,        // Array of { family_id, name, role, alias, coin_balance }
  pendingRequests, // Families where this user's membership is pending
  actors,          // Non-person actors visible to this user across all families
}
```

**Key action:**
- `fetchUserData()` — calls `GET /api/me`, populates all state fields, then calls `POST /api/me/login-event` if no `loginEventId` is set yet.

---

## 5. Routing & Navigation Guards

Routes are defined in `router/index.js` using `createWebHistory`.

### Route table

| Path | View | Auth required | Notes |
|---|---|---|---|
| `/` | `LandingView` | No (guest) | Redirects logged-in users |
| `/login` | `LoginView` | No (guest) | Redirects logged-in users |
| `/join` | `JoinView` | Yes | Handles invite links and email invitations |
| `/onboarding` | `OnboardingView` | Yes | Family creation wizard |
| `/profile` | `ProfileView` | Yes | |
| `/activities` | `ActivitiesView` | Yes | |
| `/dashboard` | `DashboardView` | Yes | |
| `/daily/:date` | `DailyView` | Yes | `date` param is `YYYY-MM-DD` |
| `/marketplace` | `MarketplaceView` | Yes | |
| `/stats` | `StatsView` | Yes | |
| `/:pathMatch(.*)` | redirect | — | Catch-all → `/dashboard` |

### Global `beforeEach` guard logic

```
1. Wait for auth to be ready (waitForAuth)
2. If route requires auth AND user is not logged in → redirect to /login, save returnUrl
3. If user is logged in AND has no family AND route is not onboarding/profile/join → redirect to /onboarding
4. If user is logged in AND navigating to a guest route → redirect to /dashboard (or returnUrl)
5. Otherwise → proceed
```

The `returnUrl` is saved in `sessionStorage` so that a user who was deep-linked before login ends up at the right place after authenticating.

---

## 6. Views

### LandingView
Marketing surface. Standalone — does not share the app shell nav. Calls `useAuthStore` only to redirect authenticated visitors away.

### LoginView
Form with email/password fields and a Google Sign-In button. On success, the auth store handles navigation via the guard. Error messages are displayed via the auth store's `error` reactive field.

### OnboardingView
Multi-step wizard:
1. Family name entry.
2. Main caregiver name / alias setup.
3. (Optional) Add objects of care (actors).

Calls `POST /api/families` then `POST /api/families/:id/actors` for each actor added.

### JoinView
Reads a `?token=` query param (invite link UUID) or `?family=` + `?invitation=` params (email invitation). Makes either `POST /api/families/join-by-token` or `POST /api/families/join-request`.

### DashboardView
Fetches `GET /api/dashboard/:familyId`. Displays:
- Member coin balance cards (uses `avatarStyle.js` for per-member colour).
- Upcoming activity count and next scheduled task.
- Recent completions list.
- KPI cards (hours this week, tasks completed this month).

### DailyView (signature view)
Most complex view. Key internals:
- `useTimeline` composable processes the raw activities array into an ordered list of `{ type: 'event' | 'gap', ...data }` items for rendering.
- `useDaySwipe` enables horizontal touch swipe to change the day parameter in the URL.
- `DailyModals.vue` renders all 7 action modals (schedule, recurrence, delete, bounty, accept-bounty, absence, absence-detail) as conditional overlays.
- `TaskLibrary.vue` is a slide-up panel listing approved activities that can be quickly scheduled to this day.
- The NOW divider position is computed from the current time and updated every minute via `setInterval`.

### ActivitiesView
Fetches `GET /api/activities?familyId=`. Status filter chips at the top. Activity cards show status chips, coin value, assignee avatar, and duration. Inline actions (approve, reject, schedule, validate, delete) call the corresponding API endpoints and refresh the list.

### MarketplaceView
Two sections:
1. **Available rewards** — `GET /api/marketplace/rewards/:familyId`. Filter: active, within validity window, not sold out.
2. **Recent claims** — shown below, last 30 redemptions.

Redeem button calls `POST /api/marketplace/rewards/:rewardId/redeem`. The response includes the updated coin cost; the family store is refreshed to reflect the new balance.

### StatsView
Fetches `GET /api/stats/:familyId?month=YYYY-MM`. Uses `vue-echarts` wrappers around ECharts to render:
- Bar chart: coins earned per member per month.
- Line chart: cumulative hours across the month.
- Donut chart: task distribution by category.

Month selector navigates backwards/forwards by modifying the query string.

### ProfileView
Three tab panels:

**AccountSettings** — avatar upload (`POST /api/me/avatar`, `multipart/form-data`), display name, email, and alias edits (`PATCH /api/me/profile`). Account deletion (`DELETE /api/me`) with a confirmation modal.

**FamilyCircle** — member list with role chips. Caregiver-only actions: invite by email (`POST /api/families/:id/invitations`), generate invite link (`POST /api/families/:id/invite-links`), display QR code for the link (uses `qrcode` library), approve/reject pending members, change member roles, add/remove actors, upload actor avatars.

**WalletPanel** — coin balance, ledger table by month (`GET /api/me/ledger?familyId&month`), last 20 login events (`GET /api/me/login-history`), notification preference toggles (`GET/PUT /api/me/notification-preferences`).

---

## 7. Components

### `VButton.vue`
Props: `type` (`primary` | `secondary` | `outline` | `danger`, default `primary`), `disabled`, `block` (full-width). Renders a `<button>` with the correct design token classes.

### `VCard.vue`
A styled `<div>` with `background: var(--surface)`, `border-radius: var(--r-lg)`, `border: 1px solid var(--border)`, and `padding: 1.5rem`. No logic — purely presentational.

### `VInput.vue`
Props: `modelValue`, `type`, `placeholder`, `disabled`, `error`. Emits `update:modelValue`. Applies the pill-radius input style with focus ring. Shows an error message below the field when the `error` prop is set.

### `VSelect.vue`
Same API as `VInput` but renders a `<select>` element styled to match the input visual language.

### `KpiCard.vue`
Props: `label`, `value`, `unit`, `subtitle`, `delta`, `deltaTone` (`success` | `warning` | `danger` | `primary` | `muted`), `accent` (`primary` | `success` | `warning` | `danger` | `ink`), `progress` (0–100, omit to hide bar), `compact`. Renders a metric tile used in Dashboard and Stats.

### `DailyModals.vue`
A compound component owned by `DailyView`. Contains all 7 inline modals, communicating via props and emits:
- **Schedule modal**: time picker (hour/minute) for `POST /api/activities/:id/schedule`.
- **Recurrence modal**: frequency + until-date picker for `POST /api/activities/:id/recurrence`.
- **Delete modal**: single vs series confirmation for `DELETE /api/activities/:id`.
- **Bounty modal**: coin amount input for `POST /api/activities/:id/bounty`.
- **Accept-bounty modal**: confirmation for `POST /api/activities/:id/accept-bounty`.
- **Absence modal**: log an absence (title, start/end times) for `POST /api/absences`.
- **Absence detail modal**: view and remove an existing absence for `DELETE /api/absences/:id`.

### `TaskLibrary.vue`
Slide-up panel that lists approved, unscheduled activities. Tapping an activity pre-populates the schedule modal with that activity's data, saving the user from re-entering details for recurring tasks.

### `AccountSettings.vue`, `FamilyCircle.vue`, `WalletPanel.vue`
Decomposed sub-components of `ProfileView` for maintainability. Each owns its own API calls and local state.

---

## 8. Composables

### `useTimeline.js`
**Input:** a reactive array of activity objects for a given day.
**Output:** a sorted array of timeline items, each typed as `event` (an activity card) or `gap` (a free-block indicator). Gaps are only generated when the free interval exceeds 30 minutes. The NOW marker position (as a percentage of the visible day window) is also computed reactively.

### `useCardSwipe.js`
Attaches touch event listeners to an activity card element. Exposes a swipe threshold and fires callbacks for swipe-left (complete) and swipe-right (delete/revert) to enable quick actions without opening a modal.

### `useDaySwipe.js`
Wraps `DailyView`'s container element. Detects horizontal swipes and programmatically calls `router.push` with the previous or next date param, enabling gesture-based day navigation.

### `useNotifications.js`
Encapsulates the FCM setup flow:
1. Checks `isSupported()` (FCM requires a secure context and a modern browser).
2. Requests `Notification.permission`.
3. Calls `getToken(messaging, { vapidKey })` to obtain the FCM device token.
4. Registers the token with the backend via `POST /api/me/fcm-token`.
5. Sets up `onMessage` (foreground notification handler) to show an in-app toast.

### `useCurrentFamily.js`
Returns the first family from `familyStore.families` as a reactive `computed`. Used throughout views as a shorthand when multi-family support is not yet in scope.

---

## 9. Push Notifications (FCM)

### Architecture

```
Backend (Node.js) ──FCM Admin SDK──► Firebase Cloud Messaging ──► Browser Service Worker
                                                                 ──► App (foreground)
```

### Client setup

1. `firebase.js` exports `getFirebaseMessaging()` — lazily initialises `getMessaging(app)` after checking `isSupported()`.
2. `useNotifications.js` requests permission and registers the token with the backend.
3. In the foreground, `onMessage` is called when a push arrives while the app is open; this triggers an in-app toast instead of an OS notification.

### Background service worker (`public/firebase-messaging-sw.js`)

Generated at build time by a custom Vite plugin (`generate-firebase-sw`) in `vite.config.js`. The plugin injects the Firebase config from env vars so the service worker uses the correct project credentials without any runtime fetch.

The SW handles:
- `onBackgroundMessage` — shows an OS notification with icon, badge, and deep-link URL.
- `notificationclick` — focuses or opens the app at the URL stored in `notification.data.url`.
- App badge API (`setAppBadge` / `clearAppBadge`) for badge counts on supported platforms.

### Notification categories (user-configurable)

| Key | Description |
|---|---|
| `activity_assigned` | Activity scheduled for this user |
| `activity_validated` | Caregiver validated a completed activity |
| `activity_completed` | Any family member completed an activity |
| `bounty_offered` | A bounty was posted on an activity |
| `family_events` | Member joined, deletion requested, etc. |

---

## 10. Progressive Web App (PWA)

Configured via `vite-plugin-pwa` in `registerType: 'autoUpdate'` mode — the service worker updates in the background and activates on next navigation.

### Manifest (`manifest.webmanifest`)

```json
{
  "name": "CareCoins",
  "short_name": "CareCoins",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#F7F8FA",
  "theme_color": "#2563EB",
  "icons": [
    { "src": "/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icon-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
```

### Two service workers

The app registers two service workers:
1. **Workbox SW** (generated by vite-plugin-pwa) — precaches all built assets for offline use, handles cache updates.
2. **Firebase Messaging SW** (`firebase-messaging-sw.js`) — handles background push notifications. Must be at the root scope to intercept all push events.

Workbox and the Firebase SW coexist because they register at different scopes or the Firebase SW is explicitly imported alongside the Workbox SW scope.

---

## 11. API Communication

All requests go through `authStore.request(path, options)`:

```js
async request(path, options = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 10_000); // 10 s timeout
  const response = await fetch(`${this.apiBase}${path}`, { ...options, signal: controller.signal });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `Request failed (${response.status})`);
  return data;
}
```

**Pattern:**
- Every request attaches `Authorization: Bearer <token>` via `authHeaders()`.
- The `apiBase` is empty in production (same-origin, proxied by nginx) and `http://localhost:3000` in local dev.
- 10-second timeout via `AbortController` prevents hanging requests.
- Non-2xx responses throw an `Error` with the server's `error` message, caught by `setError()` in views.

**File uploads** use raw `fetch` with `FormData` (no `Content-Type` header — the browser sets the multipart boundary automatically).

---

## 12. Build & Deployment

### Local development

```bash
cd frontend
npm install
npm run dev          # Vite dev server at http://localhost:5173
# or
npm run dev:test     # Uses Firebase Auth Emulator at http://localhost:9099
```

### Production build

```bash
npm run build
# Output: frontend/dist/
```

The `dist/` folder is a static SPA. `index.html` is the only entry point; nginx serves it for all routes (catch-all).

### Dockerfile (multi-stage)

```
Stage 1 (node:20-alpine) — npm ci, vite build (all env vars injected as ARG/ENV)
Stage 2 (nginx:alpine)   — copy dist/ to /usr/share/nginx/html, apply nginx.conf
```

### nginx.conf

```
/         → serve index.html (SPA fallback for all non-file routes)
/api/*    → proxy_pass http://backend:3000
/uploads/* → proxy_pass http://backend:3000
```

The frontend container is the only one that exposes a port (80). The backend and postgres containers are internal-only on the Docker network.

---

## 13. Testing

### Unit tests (Vitest)

Run with `npm test`. Environment: `jsdom`. Located in `src/**/__tests__/`.

**Covered:**
- `useTimeline.js` — timeline derivation logic, gap insertion, NOW marker position.
- `auth.js` store — login, logout, token refresh, error handling.
- `family.js` store — fetchUserData, state reset.

### End-to-End tests (Playwright)

Run with `npm run test:e2e`. Requires the full stack (backend + postgres + Firebase Emulator) to be running.

**Test suites:**

| File | Coverage |
|---|---|
| `global.setup.js` | **Global setup** — clears the Firebase emulator, creates 3 test users, seeds the shared family/activities/rewards, and saves all 3 auth state files (`auth.state.json`, `auth2.state.json`, `onboarding.state.json`) |
| `auth.setup.js` | Shared page helpers (`waitForDashboard`, `navigateToLogin`) imported by other spec files |
| `landing.spec.js` | Landing page renders, CTA navigates to login |
| `onboarding.spec.js` | New user (no family) goes through the onboarding wizard end-to-end |
| `dashboard.spec.js` | Dashboard loads with correct family data |
| `happy-paths.spec.js` | Full activity lifecycle: create → approve → schedule → complete → validate |
| `two-users.spec.js` | Multi-user scenarios: invite, join, bounty accept |
| `marketplace.spec.js` | Create reward, redeem, balance check |
| `notifications.spec.js` | FCM token registration, preference toggle |

Playwright is configured with **six browser projects** — `chromium`, `chromium-public`, `chromium-multi`, `chromium-onboard`, `webkit`, and `webkit-public` — each targeting a different subset of specs. There are three storage states:
- `auth.state.json` — authenticated as user 1 (has a family)
- `auth2.state.json` — authenticated as user 2 (invited member)
- `onboarding.state.json` — authenticated but no family (used by onboarding tests)

Tests run with `fullyParallel: false` and no retries to keep database state deterministic across suites.
