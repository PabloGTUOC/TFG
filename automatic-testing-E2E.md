# CareCoins — Automated Test Suite

> Complete reference for the three test layers introduced in response to CAT3 feedback.
> All tests are deterministic, require no manual steps, and run without connecting to any external service.

---

## Overview

| Layer | Runner | Count | Command |
|---|---|---|---|
| Backend unit tests | Node `--test` (built-in) | 44 | `cd backend && npm test` |
| Frontend unit tests | Vitest | 25 | `cd frontend && npm test` |
| E2E integration tests | Playwright + Firebase Auth Emulator | 30 | `cd frontend && npm run test:e2e` |
| **Total** | | **99** | |

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
Verifies the color-system logic introduced in Phase 2 of the design fixes.

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
| excludes templates from scheduledToday | Activity templates (not scheduled instances) are not shown on the timeline |
| attaches _style with correct top% | An activity at `START_HOUR + 3h` gets `top: (3/18)*100%` |
| sorts activities by start time | Earlier activities appear first |
| completedToday contains only completed activities | Status filter works correctly |
| todayCoins sums coin_value of completed activities | 30 + 50 cc completed = 80 cc (pending 20 cc excluded) |
| nowLineTop is null or a number | The "now" indicator is either hidden (null) or positioned (number) |
| gapBeforeMinutes reflects gap between consecutive activities | An 8:00 activity followed by 11:00 gives a gap ≥ 100 minutes |

### Pre-existing store tests — 7 tests

`auth.test.js` (5 tests): auth store initializes correctly, sets/clears success and error messages, `authHeaders` returns the right structure.

`family.test.js` (2 tests): family store initializes with default state, `fetchUserData` populates state from the API response.

---

## Layer 3 — E2E Integration Tests

**Runner:** Playwright 1.60  
**Browser:** Chromium (headless)  
**Location:** `frontend/e2e/`  
**Infrastructure:** Three servers are started automatically before the test run

### Infrastructure setup

```
Firebase Auth Emulator  →  localhost:9099  (local replacement for Firebase Auth)
Backend (test mode)     →  localhost:3000  (FIREBASE_AUTH_EMULATOR_HOST set)
Frontend (test mode)    →  localhost:5173  (VITE_USE_EMULATOR=true)
```

The Firebase Auth Emulator is a local service that provides the complete Firebase Auth API (sign up, sign in, token verification) without connecting to Google. Using it means:
- No real user accounts are created
- No production data is touched
- Tests run fully offline
- Tests are repeatable (emulator is cleared before each run)

### Global setup (`e2e/global.setup.js`)

Before any test runs, the setup script:
1. Clears all users from the Auth emulator
2. Creates test account `e2e@carecoins.test` via the emulator REST API
3. Calls the backend to bootstrap the user in the local database
4. Creates a test family "E2E Test Family" with one dependent
5. Creates and **approves** two activity templates: "Morning Walk" (care) and "Tidy Kitchen" (household)
6. Opens a Playwright browser, navigates to `/login`, fills the email/password form, submits
7. Waits for the redirect to `/dashboard` confirming successful login
8. Saves the browser's localStorage (containing the Firebase auth token) to `e2e/auth.state.json`

All subsequent authenticated tests load `auth.state.json` as their starting state — they begin already logged in with the seeded data in place.

---

### `landing.spec.js` — 8 tests (public, no auth)

#### Landing page
| Test | What it verifies |
|---|---|
| renders without JavaScript errors | No uncaught JS exceptions on page load |
| page title is CareCoins | `<title>` tag is correct |
| has a navigation link to the login page | Some route to `/login` exists |
| PWA theme-color meta is brand blue | `<meta name="theme-color" content="#2563EB">` (Phase 1 design fix) |
| Plus Jakarta Sans font link is present | Google Fonts `<link>` for Plus Jakarta Sans is in `<head>` (Phase 1 design fix) |

#### Login page
| Test | What it verifies |
|---|---|
| renders login page | `/login` loads without crashing |
| has Google sign-in button | "Sign in with Google" button is present and visible |

#### Join page
| Test | What it verifies |
|---|---|
| renders without crashing on invalid token | `/join?token=invalid` gracefully handles a bad token |

---

### `dashboard.spec.js` — 5 tests (public, no auth)

#### Authentication guard
| Test | What it verifies |
|---|---|
| redirects unauthenticated users away from /dashboard | Router guard sends unauthenticated visitors to `/login` |
| redirects unauthenticated users away from /daily | Protected daily view route is guarded |
| redirects unauthenticated users away from /profile | Profile route requires login |

#### Mobile viewport
| Test | What it verifies |
|---|---|
| login page renders correctly on mobile | No horizontal scroll on 390px viewport |
| landing page has no significant horizontal overflow on mobile | Content stays within the mobile viewport |

---

### `happy-paths.spec.js` — 17 tests (authenticated with seeded data)

All tests in this file start with the test user logged in and the test family + approved templates in the database.

#### Dashboard
| Test | What it verifies |
|---|---|
| renders Family Hub heading | Main dashboard heading is visible after auth loads |
| shows active family members section | Family member cards section is rendered |
| week calendar is visible | The 7-day weekly overview is present |
| KPI cards are present | The 4 KPI metric cards (balance, tasks, bounties, activity) are rendered |
| no JavaScript errors on load | Clean page load with no uncaught errors |

#### Daily view
| Test | What it verifies |
|---|---|
| opens for today from the URL | `/daily/YYYY-MM-DD` route loads the daily schedule view |
| task library shows seeded templates (desktop) | Both "Morning Walk" and "Tidy Kitchen" appear in the desktop sidebar |
| date navigation moves to next day | Clicking the forward arrow changes the URL to tomorrow's date |
| back button returns to dashboard | The back FAB navigates to `/dashboard` |
| task sheet opens on mobile add button click | The `+` button in the mobile bottom bar opens the task picker sheet |

#### Schedule task — end-to-end flow
| Test | What it verifies |
|---|---|
| can schedule Morning Walk on mobile via task sheet | Full scheduling flow: open sheet → select "Morning Walk" → time picker appears → confirm → activity appears in mobile timeline |

#### Profile page
| Test | What it verifies |
|---|---|
| shows Personal Area heading | Profile page loads correctly |
| shows the test family banner | The family name "E2E Test Family" appears in the profile banner |
| Account Settings section is visible | Profile form section is rendered |
| wallet tab shows coin balance | Wallet panel with "TOTAL BALANCE" is visible |

#### Navigation
| Test | What it verifies |
|---|---|
| nav links reach all main sections | Clicking the profile nav link navigates to `/profile` |
| logout clears session and redirects to login | Clicking logout lands on `/login` |

---

## How to run

### Prerequisites

All three services must be running before the E2E suite can start. Playwright starts them automatically if they are not already running.

**Option A — let Playwright manage everything (recommended for CI)**
```bash
cd frontend
npm run test:e2e
```

**Option B — start services manually, then run tests (faster for repeated runs)**
```bash
# Terminal 1 — Firebase Auth Emulator
cd /path/to/project
firebase emulators:start --only auth --project tfg-carecoins

# Terminal 2 — Backend in test mode
cd backend
npm run dev:test

# Terminal 3 — Frontend in test mode
cd frontend
npm run dev:test

# Terminal 4 — Run tests
cd frontend
npm run test:e2e
```

### Running individual layers
```bash
# Backend unit tests only
cd backend && npm test

# Frontend unit tests only
cd frontend && npm test

# E2E tests only (requires services running)
cd frontend && npm run test:e2e
```

### View E2E report
```bash
cd frontend
node node_modules/@playwright/test/cli.js show-report
```

---

## What is NOT tested (scope for CAT4)

- **Validate activity flow**: A second caregiver validating another's completed task and the coin transfer
- **Bounty end-to-end**: Offer bounty → second user accepts → verify coin transfer in both balances
- **Onboarding flow**: First-time user creating a family
- **Mobile browser**: WebKit/Safari (requires `playwright install webkit`)
- **Notification preferences**: Push notification toggle
- **Marketplace**: Reward redemption flow

These flows require either a second authenticated user in the same test session or more complex state setup, and are prioritised for the next test phase.

---

## Important: files to exclude from version control

Before pushing, ensure the following are in `.gitignore`:

```
# Playwright auth state — contains auth tokens, never commit
frontend/e2e/auth.state.json

# Playwright test artifacts
frontend/test-results/
frontend/playwright-report/

# Test output files
backend/test-results-backend.txt
```
