# CareCoins — Automated Test Suite

> Complete reference for all three test layers.
> All tests are deterministic, require no manual steps, and run without connecting to any external service.

---

## Overview

| Layer | Runner | Tests | Command |
|---|---|---|---|
| Backend unit tests | Node `--test` (built-in) | 44 | `cd backend && npm test` |
| Frontend unit tests | Vitest | 25 | `cd frontend && npm test` |
| E2E integration tests | Playwright + Firebase Auth Emulator | 72 | `cd frontend && npm run test:e2e` |
| **Total** | | **141** | |

---

## Layer 1 — Backend Unit Tests

**Runner:** Node.js built-in test runner (`node --test`)
**Location:** `backend/tests/`
**Dependencies:** `supertest` (already installed), no DB required — all tests use mock DB clients
**Architecture:** Each service function receives a `client` parameter. Tests pass a mock client that returns pre-programmed query responses in order, so no real database is needed.

### `activityService.test.js` — 21 tests

Tests the business logic in `backend/src/services/activityService.js`.

#### `completeActivity`
| Test | What it verifies |
|---|---|
| awards coin_value to assignee | Coins equal to `coin_value` are credited when an activity is completed |
| awards coin_value + bounty_amount when bounty is set | Total award includes both base coins and any offered bounty |
| returns 404 when activity not found | Missing activity returns HTTP 404 error object |
| awards zero coins when coin_value is 0 | No coin queries are made if value is zero (query count assertion) |

#### `validateActivity`
| Test | What it verifies |
|---|---|
| awards coins to assignee when validated by another user | Caregiver validates a pending activity, coins go to assignee |
| returns 403 when user tries to validate their own activity | Self-validation is blocked |
| returns 409 when activity is not pending_validation | Wrong status returns conflict error |
| returns 404 when activity not found | Missing activity returns 404 |

#### `offerBounty`
| Test | What it verifies |
|---|---|
| deducts coins from offerer and sets bounty | Offerer's balance is reduced by the bounty amount |
| returns 403 when user is not the assignee | Only the task owner can offer a bounty |
| returns 409 when user has insufficient coins | Balance check blocks insufficient offers |
| returns 404 when activity not found | Missing activity returns 404 |

#### `acceptBounty`
| Test | What it verifies |
|---|---|
| reassigns activity to accepting user | `assigned_to` is updated to the accepting user |
| returns 409 when user already owns the shift | You cannot accept your own bounty |
| returns 409 when activity is completed | Completed activities cannot change assignee |
| returns 409 when no bounty is set | No bounty available returns conflict |

#### `revertActivity`
| Test | What it verifies |
|---|---|
| deducts coins and marks activity as rejected | Coins are taken back and status set to rejected |
| refunds bounty to original offerer on revert | Bounty amount is returned to the person who offered it |
| returns 403 when user is not the assignee | Only the task owner can revert |
| returns 409 when activity is not completed | Only completed activities can be reverted |

#### `listActivities`
| Test | What it verifies |
|---|---|
| returns 403 when user is not a family member | Non-members cannot list activities |

---

### `familyService.test.js` — 23 tests

Tests `backend/src/services/familyService.js` and `backend/src/services/memberService.js`.

#### `createFamily` — budget calculation
| Test | What it verifies |
|---|---|
| sets budget to 1000 when no objectsOfCare | Default fallback budget when no dependents |
| calculates 720 per full_time dependent | Each full-time dependent adds 720 coins/month |
| calculates 360 per part_time dependent | Part-time dependent adds 360 coins/month |
| sums budget across multiple dependents | Two dependents (full + part) = 1080 coins/month |

#### `deleteFamily`
| Test | What it verifies |
|---|---|
| deletes immediately when only one caregiver | Single-caregiver family is deleted instantly |
| creates deletion request when multiple caregivers | Multi-caregiver families require consensus |
| returns 409 when deletion request already pending | Duplicate requests are blocked |
| returns 404 when family not found | Non-existent family returns 404 |

#### `approveDeletion`
| Test | What it verifies |
|---|---|
| deletes family when all approvals received | Final approval triggers actual deletion |
| returns pendingApproval when other approvals still needed | Partial approval leaves family intact |
| returns 404 when request not found | Missing deletion request returns 404 |

#### `joinByToken` (invite link flow)
| Test | What it verifies |
|---|---|
| returns 410 when link is revoked | Revoked links are rejected |
| returns 410 when link is expired | Expired links are rejected |
| returns 410 when max uses reached | Used-up links are rejected |
| returns 409 when already an active member | Duplicate membership is blocked |
| returns 404 when token not found | Invalid token returns 404 |

#### `joinByInvitation` (email invite flow)
| Test | What it verifies |
|---|---|
| returns 400 when user has no email | Accounts without email cannot use email invitations |
| returns 403 when no pending invitation for email | Only invited emails can join |

#### `approveMember`
| Test | What it verifies |
|---|---|
| returns 404 when pending member not found | Approving a non-existent pending member returns 404 |
| returns success when member approved | Valid approval succeeds |

#### `removeActor`
| Test | What it verifies |
|---|---|
| returns 403 when actor is not a pet | Only pets can be removed (not children or elderly) |
| returns 404 when actor not found | Non-existent actor returns 404 |
| removes pet and adjusts budget | Removing a pet decreases the monthly coin budget |

---

## Layer 2 — Frontend Unit Tests

**Runner:** Vitest 4.x with `vmThreads` pool
**Location:** `frontend/src/composables/__tests__/`, `frontend/src/stores/__tests__/`
**Environment:** jsdom (browser-like DOM in Node)

### `useTimeline.test.js` — 18 tests

Tests the pure logic extracted into `frontend/src/composables/useTimeline.js`.

#### `getCardStyle` — 6 tests
Verifies the color-system logic introduced in the design fixes (Phase 2).

| Test | What it verifies |
|---|---|
| returns danger-soft for rejected | Rejected activities get the danger palette |
| returns success for completed care | Completed care tasks get the green success color |
| returns warning for completed household | Completed household tasks get amber |
| returns surface for pending | Pending tasks get neutral white surface |
| returns surface for approved | Approved-but-unstarted tasks get neutral surface |
| returns surface for pending_validation | Awaiting validation also gets neutral surface |

#### `formatGap` — 4 tests
Tests the human-readable time gap formatter shown between timeline activities.

| Test | What it verifies |
|---|---|
| returns minutes only when < 60 | `45` → `"45min"` |
| returns hours only when exact hour | `120` → `"2h"` |
| returns hours + minutes | `90` → `"1h 30min"` |
| handles 0 minutes | `0` → `"0min"` |

#### `useTimeline` composable — 8 tests
Tests the timeline positioning algorithm that places activity chips on the daily grid.

| Test | What it verifies |
|---|---|
| scheduledToday filters to target date only | Activities from other days are excluded |
| excludes templates from scheduledToday | Activity templates are not shown on the timeline |
| attaches _style with correct top% | An activity at `START_HOUR + 3h` gets `top: (3/18)*100%` |
| sorts activities by start time | Earlier activities appear first |
| completedToday contains only completed activities | Status filter works correctly |
| todayCoins sums coin_value of completed activities | 30 + 50 cc completed = 80 cc (pending 20 cc excluded) |
| nowLineTop is null or a number | The "now" indicator is either hidden (null) or positioned (number) |
| gapBeforeMinutes reflects gap between consecutive activities | An 8:00 activity followed by 11:00 gives a gap ≥ 100 minutes |

### Pre-existing store tests — 7 tests

`auth.test.js` (5): auth store initializes, sets/clears success and error messages, `authHeaders` returns the right structure.

`family.test.js` (2): family store initializes with default state, `fetchUserData` populates state from the API response.

---

## Layer 3 — E2E Integration Tests

**Runner:** Playwright 1.60
**Browsers:** Chromium (headless) + WebKit/Safari (headless)
**Location:** `frontend/e2e/`

### Infrastructure

Three servers start automatically before the test run:

```
Firebase Auth Emulator  →  localhost:9099  (local Firebase Auth, no Google connection)
Backend (test mode)     →  localhost:3000  (FIREBASE_AUTH_EMULATOR_HOST set)
Frontend (test mode)    →  localhost:5173  (VITE_USE_EMULATOR=true)
```

### Projects (browser × auth state)

| Project | Browser | Auth state | Spec files |
|---|---|---|---|
| `chromium` | Chromium | `auth.state.json` (user1) | happy-paths, marketplace, notifications |
| `chromium-public` | Chromium | None | landing, dashboard (auth guards) |
| `chromium-multi` | Chromium | `auth.state.json` | two-users |
| `chromium-onboard` | Chromium | `onboarding.state.json` | onboarding |
| `webkit` | WebKit/Safari | `auth.state.json` | happy-paths |
| `webkit-public` | WebKit/Safari | None | landing |

### Global setup (`e2e/global.setup.js`)

Before any test runs, the setup:
1. Clears all users from the Auth emulator
2. Creates three test accounts: `e2e@carecoins.test` (user1), `e2e2@carecoins.test` (user2), `e2e-onboard@carecoins.test` (no family)
3. Bootstraps all three in the backend DB via `/api/me`
4. Creates **"E2E Test Family"** with user1 as caregiver
5. Invites user2 by email; user2 joins and becomes an active caregiver
6. Creates and approves templates: **Morning Walk** (care, 30cc), **Tidy Kitchen** (household, 20cc), **Evening Care** (care, 45cc)
7. Schedules Morning Walk **3 days ago** → auto `pending_validation` → user2 validates it → **user1 earns 30cc**
8. Schedules a second Morning Walk **yesterday** → `pending_validation`, left for the UI validate test
9. Schedules Evening Care **tomorrow** → future activity for the bounty test
10. Creates marketplace reward: **"Movie Night"**, cost 10cc (user1 has 30cc)
11. Logs each user in via Playwright browser, saves three auth state files

---

### `landing.spec.js` — 8 tests (Chromium + WebKit, public)

#### Landing page
| Test | What it verifies |
|---|---|
| renders without JavaScript errors | No uncaught JS exceptions on page load |
| page title is CareCoins | `<title>` tag is correct |
| has a navigation link to the login page | Route to `/login` exists |
| PWA theme-color meta is brand blue | `<meta name="theme-color" content="#2563EB">` |
| Plus Jakarta Sans font link is present | Google Fonts `<link>` for Plus Jakarta Sans is in `<head>` |

#### Login page
| Test | What it verifies |
|---|---|
| renders login page | `/login` loads without crashing |
| has Google sign-in button | "Sign in with Google" button is present and visible |

#### Join page
| Test | What it verifies |
|---|---|
| renders without crashing on invalid token | `/join?token=invalid` handles bad token gracefully |

---

### `dashboard.spec.js` — 5 tests (Chromium, public / no auth)

#### Authentication guard
| Test | What it verifies |
|---|---|
| redirects unauthenticated users away from /dashboard | Router guard sends visitors without a session to `/login` |
| redirects unauthenticated users away from /daily | Protected daily view route is guarded |
| redirects unauthenticated users away from /profile | Profile route requires login |

#### Mobile viewport
| Test | What it verifies |
|---|---|
| login page renders correctly on mobile | No horizontal scroll on 390px viewport |
| landing page has no significant horizontal overflow on mobile | Content stays within the mobile viewport (tolerance: 30px) |

---

### `happy-paths.spec.js` — 17 tests (Chromium + WebKit, user1 authenticated)

All tests start with user1 logged in and the seeded family + approved templates in the database.

#### Dashboard
| Test | What it verifies |
|---|---|
| renders Family Hub heading | Main dashboard heading is visible after auth loads |
| shows active family members section | Family member cards section is rendered |
| week calendar is visible | The 7-day weekly overview is present |
| KPI cards are present | The 4 KPI metric cards are rendered |
| no JavaScript errors on load | Clean page load with no uncaught errors |

#### Daily view
| Test | What it verifies |
|---|---|
| opens for today from the URL | `/daily/YYYY-MM-DD` route loads the schedule view |
| task library shows seeded templates (desktop) | Both "Morning Walk" and "Tidy Kitchen" appear in the desktop sidebar |
| date navigation moves to next day | Clicking the forward arrow changes the URL to tomorrow |
| back button returns to dashboard | The back FAB navigates to `/dashboard` |
| task sheet opens on mobile add button click | The `+` button in the mobile bar opens the task picker sheet |

#### Schedule task — end-to-end flow
| Test | What it verifies |
|---|---|
| can schedule Morning Walk on mobile via task sheet | Full flow: open sheet → select "Morning Walk" → time picker → confirm → activity appears in mobile timeline |

#### Profile page
| Test | What it verifies |
|---|---|
| shows Personal Area heading | Profile page loads |
| shows the test family banner | Family name "E2E Test Family" appears in the banner |
| Account Settings section is visible | Profile form section is rendered |
| wallet tab shows coin balance | Wallet panel with "TOTAL BALANCE" is visible |

#### Navigation
| Test | What it verifies |
|---|---|
| nav links reach all main sections | Clicking profile nav link navigates to `/profile` |
| logout clears session and redirects to login | Clicking logout lands on `/login` |

---

### `two-users.spec.js` — 3 tests (Chromium, user1 + user2 contexts)

Each test opens two browser contexts simultaneously: user1 (`auth.state.json`) and user2 (`auth2.state.json`).

| Test | What it verifies |
|---|---|
| validate activity: user2 validates user1 past activity | User2 navigates to yesterday's daily view, sees the "✓ Validate" button on Morning Walk (assigned to user1, status `pending_validation`), clicks it, and the chip changes to "✓ Done" |
| validate activity: user1 coin balance increases after validation | After user2 validates, user1's wallet on the profile page shows a balance > 0 (earned 30cc from the 3-days-ago instance validated in setup) |
| bounty flow: user1 offers bounty, user2 takes over | User1 opens tomorrow's daily view and clicks "Delegate (-cc)" on Evening Care → bounty modal → enters 10cc → confirms. User2 navigates to the same view, sees "Take Over (+10cc)", clicks it → accept bounty modal → confirms. Evening Care chip no longer shows "Take Over" for user2 |

---

### `onboarding.spec.js` — 3 tests (Chromium, onboarding user — no family)

| Test | What it verifies |
|---|---|
| authenticated user with no family lands on /onboarding | Navigating to `/dashboard` triggers the router guard and redirects to `/onboarding` |
| onboarding page shows create and join options | "Create a New Family" and "Join via Invite Link" cards are present |
| can create a new family and lands on dashboard | Click "Create Family" → fill name → click "Complete Setup" → app creates the family, calls `fetchUserData`, and navigates to `/dashboard` showing "Family Hub" |

---

### `marketplace.spec.js` — 6 tests (Chromium, user1 authenticated)

User1 has 30cc (earned from the 3-days-ago validated activity). A "Movie Night" reward (10cc) was seeded in setup.

| Test | What it verifies |
|---|---|
| marketplace page loads correctly | `/marketplace` renders with "The Reward Store" heading |
| seeded reward "Movie Night" is visible in the store | The reward card created in global setup appears in the store |
| reward card shows coin cost | The "10" coin amount badge is visible on the card |
| can redeem a reward end-to-end | Click "Buy Now" → "Confirm Redemption" modal appears → click "Spend coins" → success message shown |
| History tab shows claimed rewards after redemption | After redemption, the History tab section is accessible and visible |
| caregiver can create a new reward | Navigate to Create section → fill "Reward Title" and "Coin Cost" fields → click "Add Reward to Store" → success indicator appears |

---

### `notifications.spec.js` — 5 tests (Chromium, user1 authenticated)

Uses `page.addInitScript` to inject `Notification.permission = 'granted'` before Vue reads it at component init time, simulating a user who has already granted browser notification permission.

| Test | What it verifies |
|---|---|
| notification permission is detected as granted | `Notification.permission` evaluates to `'granted'` in the page context |
| notification preferences panel is visible when permission is granted | "✓ Notifications enabled" text and `.notif-pref-list` are rendered |
| shows all 5 notification preference toggles | `.notif-pref-toggle` count is exactly 5 |
| can toggle a notification preference off and on | Toggle starts checked → click → unchecked → click → back to checked |
| disable button is visible when notifications are enabled | A "Disable" button is present when the prefs panel is shown |

---

## How to run

### Prerequisites

Playwright starts all three servers automatically when they are not already running.

**Option A — let Playwright manage everything (recommended for CI)**
```bash
cd frontend
npm run test:e2e
```

**Option B — start services manually, then run tests (faster for repeated runs)**
```bash
# Terminal 1 — Firebase Auth Emulator
firebase emulators:start --only auth --project tfg-carecoins

# Terminal 2 — Backend in test mode
cd backend && npm run dev:test

# Terminal 3 — Frontend in test mode
cd frontend && npm run dev:test

# Terminal 4 — Run tests
cd frontend && npm run test:e2e
```

### Running individual layers
```bash
# Backend unit tests
cd backend && npm test

# Frontend unit tests
cd frontend && npm test

# E2E only (requires services running)
cd frontend && npm run test:e2e
```

### View Playwright HTML report
```bash
cd frontend && node node_modules/@playwright/test/cli.js show-report
```

---

## Test data setup summary

| Resource | Value | Purpose |
|---|---|---|
| User 1 | `e2e@carecoins.test` | Primary authenticated user — runs happy-paths, marketplace, notifications |
| User 2 | `e2e2@carecoins.test` | Second caregiver — validates activities, accepts bounties |
| Onboarding user | `e2e-onboard@carecoins.test` | No family at setup — tests the first-time onboarding flow |
| Family | "E2E Test Family" | Shared between user1 and user2 |
| Templates | Morning Walk (care, 30cc), Tidy Kitchen (household, 20cc), Evening Care (care, 45cc) | Appear in task library; used for scheduling tests |
| Past instance 1 | Morning Walk, 3 days ago, validated by user2 | Gives user1 30cc for marketplace test |
| Past instance 2 | Morning Walk, yesterday, `pending_validation` | Used by the UI validate test (user2 clicks Validate) |
| Future instance | Evening Care, tomorrow | Used by the bounty flow test |
| Marketplace reward | "Movie Night", 10cc | Used by the redeem end-to-end test |

---

## Important: files excluded from version control

The following are in `.gitignore` and must never be committed:

```
frontend/e2e/auth.state.json        ← user1 Firebase auth token
frontend/e2e/auth2.state.json       ← user2 Firebase auth token
frontend/e2e/onboarding.state.json  ← onboarding user auth token
frontend/test-results/
frontend/playwright-report/
backend/test-results-backend.txt
```
