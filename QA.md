# Tribunal Q&A Preparation — CareCoins TFG

Compiled from the deep-dive session on the repository. Covers: likely tribunal questions, verified answers on concurrency, the PWA service-worker story, the Vite plugin explanation, and backend auth verification.

---

## 1. Likely tribunal questions by theme

### Architecture & tech stack justification (almost guaranteed)

- **"Why Vue 3 instead of React or Angular?"** — Don't say "I knew it best" alone; tie it to the project: Composition API composables (`useTimeline`, `useCardSwipe`) let you extract the timeline logic and test it in isolation; Vite gives fast PWA builds.
- **"Why a PWA instead of a native mobile app, given mobile is your primary action surface?"** — One codebase, installable on iOS and Android, push via FCM + service worker, no app-store friction for a family of 2–6 people. Follow-up: *"What did the PWA approach cost you?"* (iOS push limitations, badge API support, the two-service-worker complexity).
- **"Why Express + raw `pg` instead of an ORM like Prisma or Sequelize?"** — Explicit SQL, `withTransaction` gives visible atomicity, fewer abstraction layers for a coin ledger where correctness matters.
- **"Why Firebase Auth instead of implementing your own authentication?"** — Follow-up: *"Vendor lock-in?"* The upsert pattern (`upsertUserFromAuth` linking `firebase_uid` to an internal user) is the answer — the internal user model is decoupled.
- **"Walk me through what happens, end to end, when a user marks an activity as done."** — Rehearse it: tap → `POST /api/activities/:id/complete` → `requireAuth` → RBAC → service layer in a transaction → status `pending_validation` → FCM notification to caregivers → validation → coin mint in `coin_ledger`.

### Database & data integrity

- **"How do you guarantee a coin is never created or lost twice?"** — Immutable `coin_ledger`, every mutation inside `withTransaction` (BEGIN/COMMIT/ROLLBACK), atomic redemption (debit + redemption record in one transaction).
- **"What happens if two caregivers validate the same activity simultaneously?"** — Fully handled; see Section 2 below.
- **"Why do templates and instances share one `activities` table with an `is_template` flag instead of two tables?"** — Classic schema-design probe; prepare a reason (shared columns, single lifecycle, simpler queries).
- **"Why soft-delete users instead of hard delete? GDPR right to erasure?"** — You anonymise data and delete the Firebase account; anonymised data is no longer personal data, which is a defensible GDPR position.

### Security (expect 2–3 of these)

- **"How is the API protected?"** — Layered: Firebase ID token verification (`requireAuth`), RBAC per family (`assertMemberRole`, `requireRole`), parameterised queries, two rate limiters (1000/15min per IP + 300/15min per UID), CORS whitelist, nginx as the only public surface.
- **"Why two rate limiters?"** — The per-UID limiter stops an authenticated user rotating IPs.
- **"How do you prevent a user from one family reading another family's data?"** — Multi-tenancy enforcement: `assertActiveMember` is the most-connected function in the codebase (15 edges in the knowledge graph) — it gates every family-scoped query. Know this cold.
- **"What about file upload attacks?"** — MIME validation, 2 MB cap, IDs cast through `String(Number(id))` against path traversal, normalised filenames.
- **"Invite links are join-without-approval. Isn't that a security hole?"** — UUID token, optional expiry and max-uses, revocable; convenience vs. control trade-off, and email invitations exist for the approval path.
- **"`firebase-credentials.json` sits in the repo root — how do you manage secrets?"** — Check before the defense whether it's gitignored/committed. If it's in git history, fix that *before* presenting.

### Testing & quality (you're strong here — invite these questions)

- **"How did you validate the system works?"** — 116 test definitions across three layers: 44 backend unit (mock DB clients, no database), 25 frontend unit (Vitest), 47 Playwright E2E on Chromium + WebKit using the Firebase Auth Emulator, fully offline.
- **"Why mock the DB in unit tests instead of a real Postgres?"** — Service functions receive a client and return data/error objects, so they're testable without HTTP or DB; the E2E layer covers real integration.
- **"How do you test a flow involving two users?"** — `two-users.spec.js` runs two simultaneous browser contexts to test validation and bounty flows. Mention this proactively in the presentation.
- **"What's your test coverage? What is *not* tested?"** — Know the honest gaps: push notification delivery end-to-end, auto-complete sweep timing, load testing.

### Product & design decisions

- **"How is this different from existing apps (Todoist, OurHome, Sweepy)?"** — Fairness/invisible-labour framing, coins as a fairness tool not gamification, "finite and completable" anti-feed design.
- **"Doesn't paying family members coins for chores undermine intrinsic motivation?"** — A tribunal member *will* play devil's advocate. PRODUCT.md line is the answer: "a team, not a scoreboard"; coins make invisible labour visible.
- **"Did you validate this with real users?"** — If you did any user testing, lead with it; otherwise frame the design-principles document and accessibility targets (WCAG AA, 44px touch targets, reduced motion) as evidence of user-centred process, and name user studies as future work.
- **"Explain the monthly budget model."** — Base rate per hour = budget ÷ 720 hours/month; actor-removal budget adjustment (−720 full-time / −360 part-time). Be able to explain the economics.

### Deployment, scalability, limitations (typical closing questions)

- **"Describe your deployment architecture."** — Docker Compose: postgres → db-init (idempotent migrations) → backend → nginx-served frontend; backend never exposed publicly; nginx terminates and proxies.
- **"What would break first at 100,000 families?"** — Don't oversell: single Postgres, single Node process, no horizontal scaling — then pivot to your own documented principle: "family-scale, not enterprise-scale" is a deliberate design constraint.
- **"Main limitations / what would you do with six more months?"** — Prepare a 3-item list (e.g., offline-first data sync beyond asset caching, iOS push reliability, real user evaluation, i18n).
- **"What was the hardest technical problem you solved?"** — See Section 3.

### Presentation advice

1. **Pre-empt the security and testing questions in your slides** — one slide each. Claiming the material before they ask converts hard questions into easy ones.
2. **Rehearse the full-stack trace out loud** (the "mark activity done" flow). It's the single most likely "show me you understand your own system" question.

---

## 2. Concurrent validation — VERIFIED in code, handled correctly

The mechanism is in `backend/src/services/activityService.js:227` (`validateActivity`), called inside `withTransaction` from `backend/src/routes/activities.js:152`:

```sql
SELECT id, family_id, assigned_to, status, coin_value, bounty_amount
FROM activities WHERE id = $1
  AND family_id IN (SELECT family_id FROM family_members WHERE user_id = $2 AND status = 'active')
FOR UPDATE
```

Three layers make double-minting impossible:

1. **Row-level lock (`FOR UPDATE`)** — if two caregivers validate simultaneously, the second transaction blocks on this SELECT until the first commits.
2. **Status check inside the transaction** — when the second transaction unblocks, Postgres re-evaluates the row and returns the *committed* version, now `status = 'completed'`. The guard `if (act.status !== 'pending_validation') return 409` rejects it cleanly.
3. **Single-transaction mint** — the status flip, the `coin_balance` update, and the `coin_ledger` inserts all happen on the same client between BEGIN and COMMIT. No window where status changed but coins weren't credited.

There's also a self-validation guard: `act.assigned_to === userId` → 403.

The same pattern is applied consistently elsewhere — say this to show it's a *discipline*, not a one-off:

- **`completeActivity`** (`activityService.js:190`) — `FOR UPDATE` with `status = 'approved'` directly in the WHERE clause; a concurrent duplicate gets 404.
- **`offerBounty`** — `FOR UPDATE` then balance check *inside* the transaction, so simultaneous bounty offers can't drive a balance negative. Bounty coins are **escrowed**: deducted from the offerer immediately with a negative `bounty_escrow` ledger entry, so the payout on completion can never double-spend.
- **`runAutoCompleteSweep`** (`backend/src/db/autoComplete.js`) — explicitly uses `FOR UPDATE` to prevent concurrent sweeps double-awarding. A race between the sweep and manual validation is safe: the sweep selects `status = 'approved'`, validation requires `pending_validation` — disjoint states, and the row lock serializes them anyway.

**Rehearsed answer:**

> "Validation runs in a single database transaction that takes a row-level lock with SELECT … FOR UPDATE. A concurrent second request blocks on that lock, and when it proceeds it sees the committed status 'completed' and gets a 409. Since the coin credit and ledger entry are inside the same transaction, coins are minted exactly once. I use the same lock-then-check pattern in completion, bounties, and the auto-complete sweep."

**Honest caveat in your back pocket:** this relies on Postgres row locks, so it's correct on a single database but not load-tested — fine to admit, consistent with the "family-scale by design" framing.

---

## 3. Hardest technical problem — the PWA / two-service-worker story

The architecture: **two service workers coexisting** —

1. **Workbox SW** (generated by `vite-plugin-pwa`, `registerType: 'autoUpdate'`) — precaches built assets for offline use and installability, controls page fetches at `/`.
2. **`firebase-messaging-sw.js`** — handles background push. Firebase registers it under its own scope (`/firebase-cloud-messaging-push-scope`), so the two don't conflict.

Four genuinely hard sub-problems:

### a) Injecting Firebase config into a file outside the build graph

(See Section 4 for full detail.) The push SW must be a static file at a fixed URL, so it can't use `import.meta.env`. Solution: a custom Vite plugin (`generate-firebase-sw` in `frontend/vite.config.js`) whose `buildStart` hook writes `public/firebase-messaging-sw.js` from env vars at build time. The commit "Vit version solved on docker" suggests getting this working inside the Docker build was part of the battle — tell that story.

### b) Foreground/background duality

Push behaves completely differently depending on app state, so the logic exists twice by necessity:

- **App open** → `onMessage` in `useNotifications.js` creates a `Notification` manually and deep-links via `router.push`.
- **App closed** → `onBackgroundMessage` in the SW calls `showNotification`, sets the app badge, and the `notificationclick` handler searches existing window clients to focus-and-navigate rather than opening a duplicate tab.

Every notification carries a `data.url` so both paths deep-link to the right view.

### c) Token lifecycle

FCM tokens rotate silently. `init()` re-fetches and upserts the token on every app startup (deduped via `currentToken`), the `fcm_tokens` table supports multi-device, and the backend prunes stale tokens after a failed send. Without this, notifications silently die after a few weeks — a failure mode invisible in development.

### d) The update problem

An installed PWA aggressively caches itself; after a deploy, users can be stuck on the old version. The commit "PWA refresh updated" is this fight — resolved with `registerType: 'autoUpdate'`: the Workbox SW updates in the background and activates on next navigation.

### Bonus details if probed

- The `Cross-Origin-Opener-Policy: same-origin-allow-popups` header in the dev server config exists because COOP otherwise breaks the Firebase Google sign-in popup.
- `firebase.js` switches auth persistence from indexedDB to localStorage in emulator mode specifically so Playwright's `storageState()` can capture the session — a subtle testing-meets-PWA problem.
- **If asked about hardcoded config fallbacks in `vite.config.js`** (API key etc.): Firebase *web* config is public by design — it ships to every client; security comes from Firebase Auth verification on the backend, not from hiding the config.

### Suggested narrative for the presentation

> "The hardest part was push notifications as a PWA. The work splits across two service workers with different jobs and lifecycles; the messaging worker lives outside the build system, so I wrote a Vite plugin that generates it at build time from environment config; every notification has to work in both foreground and background states with deep linking; and FCM tokens rotate silently, so I built a silent re-registration on startup plus server-side pruning of dead tokens."

If they want a second example, pivot to the concurrency answer (Section 2) — one frontend/platform battle, one backend/correctness battle.

---

## 4. The Vite plugin explained in detail (problem 3a)

### The problem

A service worker is special in three ways:

1. **The browser must fetch it from a fixed URL as a standalone file.** When Firebase's `getToken()` runs, it registers `/firebase-messaging-sw.js` — the browser downloads that exact file and runs it in its own thread, separate from the app's JavaScript.
2. **It can't go through Vite's build pipeline.** Normal app code gets bundled, and Vite replaces `import.meta.env.VITE_FIREBASE_API_KEY` with the actual string at build time. But files in `frontend/public/` are copied to the output **verbatim** — Vite never touches them. `import.meta.env` written inside the SW would reach the browser as literal text and crash, because it's a Vite invention that doesn't exist in a real browser.
3. **Yet the SW needs the Firebase config anyway** — it must call `firebase.initializeApp({...})` with real project values to receive background push.

So: a file that *needs* config values but *can't* read them the way the rest of the app does.

### The alternatives (and why they're worse)

- **Hardcode the config in the SW file.** The config then lives in two places (`firebase.js` reads env vars, the SW has pasted values). Change Firebase project and they silently drift apart — push breaks with no error pointing at why.
- **Have the SW `fetch('/firebase-config.json')` at runtime.** Adds a network round-trip before the SW can initialize, and a SW can be woken cold by a push event — async config loading at exactly the wrong moment.

### The solution: generate the file at build time

Vite plugins are objects with named **hooks** — functions Vite calls at specific moments. `vite.config.js` defines a tiny inline plugin:

```js
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');   // 1. read .env files into a plain object

  return {
    plugins: [
      vue(),
      {
        name: 'generate-firebase-sw',
        buildStart() {                              // 2. hook: runs when a build (or dev server) starts
          fs.writeFileSync('./public/firebase-messaging-sw.js', buildFirebaseSW(env));  // 3.
        },
      },
      // ...
```

`buildFirebaseSW(env)` returns the service worker's **source code as a template string**, with the config baked in:

```js
function buildFirebaseSW(env) {
  const config = {
    apiKey: env.VITE_FIREBASE_API_KEY || '...fallback...',
    projectId: env.VITE_FIREBASE_PROJECT_ID || '...',
    // ...
  };
  return `importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp(${JSON.stringify(config, null, 2)});   // ← config injected HERE
...`;
}
```

The sequence:

1. `npm run build` (or `npm run dev`).
2. Vite calls `loadEnv()` → `VITE_FIREBASE_*` variables are read from `.env` / the environment (in Docker, from build args/env).
3. Vite fires `buildStart` → the plugin **writes a brand-new `public/firebase-messaging-sw.js` to disk**, with real config values printed into the source via `JSON.stringify(config)`.
4. Vite copies `public/` to the output as usual — the deployed site serves a SW that already contains the right config as plain, static JavaScript. No `import.meta.env`, no runtime fetch.

The file in `frontend/public/firebase-messaging-sw.js` is therefore **not hand-written — it's a build artifact**, regenerated on every build. Single source of truth: the environment variables. Both the app bundle and the SW get values from the same place, through two different mechanisms (Vite's env substitution for the app; the plugin's code generation for the SW).

Two supporting details:

- **`importScripts(...)` instead of `import`** — classic service workers can't use ES module imports, so the SW pulls the Firebase *compat* libraries from Google's CDN with `importScripts`, the SW-native way to load scripts.
- **Why this also fixed the Docker problem** — the image builds the frontend inside the container; because generation happens at `buildStart`, whatever env config the container is built with is automatically baked into the SW. No manual step, no shipping a SW pointing at the wrong Firebase project.

### 30-second tribunal version

> "The push service worker has to be served as a static file at a fixed URL, so it can't go through the bundler — which means it can't read environment variables the way the rest of the frontend does, but it still needs the Firebase configuration. Instead of hardcoding the config in two places, I wrote a small Vite plugin: at build start it generates the service worker file, injecting the config from the same environment variables the app uses. So the deployed worker is a build artifact with the config baked in — one source of truth, works identically in local dev and in the Docker build."

If asked *"isn't it insecure to bake the API key into a public file?"* — Firebase web config is public by design (it ships to every browser anyway); security comes from Firebase Auth verification on the backend.

---

## 5. Backend Firebase Auth verification — how it works

The chain separates **authentication** (Firebase's job) from **authorization** (yours).

### Step by step

**1. Login → Firebase issues a signed JWT.** On sign-in (email/password or Google), Firebase Authentication returns an **ID token**: a JWT signed with Google's private key, valid ~1 hour, containing claims like `uid`, `email`, `aud` (your project ID) and `exp`. The backend never sees a password.

**2. The frontend keeps the token fresh and attaches it everywhere.** In `frontend/src/stores/auth.js:28`, `onIdTokenChanged` fires on login and whenever the Firebase SDK silently refreshes the token (automatic, before the 1-hour expiry, using a long-lived refresh token). Every API call goes through `request()` with `authHeaders()` (`auth.js:114`):

```
Authorization: Bearer <ID token>
```

**3. Every API router is gated.** In `backend/src/app.js:66-72`, all seven `/api/*` routers are mounted as:

```js
app.use('/api/activities', requireAuth, perUserLimiter, activitiesRouter);
```

Order matters: `requireAuth` runs first, so `perUserLimiter` can rate-limit by `req.auth.uid`.

**4. `requireAuth` verifies the token — locally, with cryptography.** Core line in `backend/src/middleware/auth.js`:

```js
const decoded = await admin.auth().verifyIdToken(token);
```

`verifyIdToken` does **not** call Firebase on every request. The Admin SDK downloads Google's **public keys** once (and caches them), then verifies each token locally:

- the **signature** checks out against Google's public key (nobody can forge or tamper with a token without Google's private key);
- **`exp`** — not expired;
- **`aud`/`iss`** — issued for *your* Firebase project, not some other app.

Any failure → 401. On success, verified claims become `req.auth = { uid, email, name }`. Auth is **stateless**: no session table, no session cookies — each request carries its own proof.

**5. Firebase UID → internal user.** Route handlers call `upsertUserFromAuth(client, req.auth)` inside the transaction, which finds-or-creates the row in the `users` table keyed by `firebase_uid`. This decoupling layer means everything downstream references *your* user ID, not Firebase's — also the answer to vendor lock-in.

**6. Authorization is yours, in Postgres.** The token only proves *who* the user is. *What they may touch* is enforced by the RBAC layer — `assertActiveMember` / `assertMemberRole` check the `family_members` table on every family-scoped query. A valid token from family A still gets 404/403 on family B's data.

### Two supporting details

- **Emulator mode (how E2E tests work offline):** in `getFirebaseApp()`, if `FIREBASE_AUTH_EMULATOR_HOST` is set, the Admin SDK skips real credentials and accepts the emulator's unsigned tokens locally. That's the switch that lets the 47 Playwright tests run with no real Google account and no network.
- **Service account credentials:** in production, `admin.credential.applicationDefault()` reads the service account JSON pointed to by `GOOGLE_APPLICATION_CREDENTIALS` (`firebase-credentials.json`, mounted into the Docker container). Nuance: token *verification* mostly needs only Google's public keys — the service account's private credentials authorize the privileged operations (FCM sends, `deleteFirebaseUser()` in account deletion).

### 30-second tribunal version

> "The frontend obtains a short-lived JWT from Firebase Auth and sends it as a Bearer header on every request. On the backend, a middleware verifies it with the Firebase Admin SDK — that's a local cryptographic check of the signature against Google's public keys, plus expiry and audience, so it's stateless and adds no per-request network call. The verified UID is then upserted into my own users table, and from there authorization is entirely mine: role checks against the family_members table on every family-scoped query. So Firebase answers 'who is this?', and my database answers 'what can they do?'."

**Likely follow-up:** *"What happens if a token is stolen?"* — Honest answer: it's valid until expiry (≤1 hour); you don't use `checkRevoked` (which would add a per-request Firebase call), and you mitigate exposure via HTTPS-only transport, indexedDB persistence in production, and the login-history table for visibility. Own that trade-off (performance vs. instant revocation) proactively.

---

## 6. Frontend — design system, stores, and views

### Design system

**Q: "Did you follow a design methodology, or did you improvise the UI?"**

> Strong answer: there is a formal design system (`docs/DESIGN.md` + `frontend/src/style.css`) with a stated creative concept — *"The Family Operations Room"* — and explicit tokens: a colour palette where every colour has exactly one semantic job (blue `#2563EB` = action, green = done, amber = household, red = danger), one typeface (Plus Jakarta Sans) with hierarchy achieved through weight and size only, radius tokens (`--r-sm` 8px / `--r-md` 16px / `--r-lg` 24px / pill for interactive elements), and a flat-by-default elevation rule (shadows respond to state, never decorate). The system also has explicit *anti-references*: no social-media feed aesthetics, no cold corporate SaaS, no gamification theater.

**Q: "Why a custom design system instead of a UI framework like Vuetify, Tailwind, or Bootstrap?"**

> A component framework imposes its own visual language; the brand goal (warm, family-scale, anti-corporate) required control over every token. The actual component needs were small — 5 base components (`VButton`, `VCard`, `VInput`, `VSelect`, `KpiCard`) cover the whole app — so a framework would add hundreds of KB for components you don't use. CSS custom properties give you the theming layer a framework would, for free. Follow-up risk: *"Isn't that reinventing the wheel?"* — at 5 components, the wheel is smaller than the framework's documentation.

**Q: "How do activity cards communicate state? What if a user is colour-blind?"**

> Card colour is driven by **status, not assignee** (`pending` → neutral surface, `completed-care` → green, `completed-household` → amber, `rejected` → soft red), mapped in one function: `getCardStyle` in `useTimeline.js` — which is unit-tested (6 cases). Accessibility: colour is never the sole indicator — status chips always pair colour with text or icon; WCAG AA contrast (4.5:1 body) and 44×44px touch targets are stated requirements in PRODUCT.md.

**Q: "Why does the landing page look different from the rest of the app?"**

> Deliberate and documented: `LandingView` is a **brand surface** (design *is* the product, for acquisition — fluid typography, scroll reveals, phone mockup) while all app views are **product surfaces** (design *serves* the caregiving workflow). Two registers, one token system.

### Stores (Pinia)

**Q: "How do you manage state? Why Pinia?"**

> Two deliberately small stores. `auth.js` owns the Firebase session: an `onIdTokenChanged` listener keeps the JWT fresh, `authHeaders()` builds the Bearer header, and a `request()` helper wraps every API call with a 10-second `AbortController` timeout and unified error handling. `family.js` owns family data: profile, families, pending requests, actors — fetched once via `GET /api/me` when auth resolves and refreshed after mutations. Pinia is Vue 3's official store: composable-friendly, typed, and trivially testable (the stores have 7 unit tests). Everything else (timeline positioning, swipe gestures, notifications) lives in composables, not stores, because it's *behaviour*, not shared state.

**Q: "Why isn't there a store for activities or rewards?"**

> Deliberate scope decision: activities and rewards are *view-local* data — each view fetches what it needs and refetches after its own mutations. Only state that is genuinely cross-view (who am I, which family am I in) is global. This avoids the classic SPA failure mode of a giant store that caches stale copies of everything. Trade-off to own: navigating between views refetches; at family scale (2–6 users) that's negligible, and it guarantees freshness in a multi-user app where another caregiver may have changed the data.

**Q: "How does the frontend know the user's session state on page load?"**

> The router's global guard `await authStore.waitForAuth()` blocks navigation until Firebase resolves the persisted session (indexedDB in production). This prevents the classic flash-of-login-screen on refresh.

### Views & router

**Q: "Walk me through the navigation/routing structure."**

> Ten routes in `frontend/src/router/index.js`, each marked `meta: { guest }` or `meta: { requiresAuth }`. A single `router.beforeEach` guard enforces three rules: (1) unauthenticated users hitting a protected route are redirected to `/login`, with the intended URL saved in `sessionStorage` as a `returnUrl` and restored after login; (2) authenticated users **without a family** are forced to `/onboarding` — only `onboarding`, `profile`, and `join` are reachable family-less, so a user can never see an empty dashboard; (3) authenticated users hitting guest pages (landing, login) are bounced to the dashboard. A catch-all route redirects unknown paths to `/dashboard`. The guard is covered by E2E tests (`dashboard.spec.js` tests the auth-guard redirects).

**Q: "DailyView is your signature view — how did you keep it maintainable?"**

> It's a thin coordinator over extracted pieces: three composables (`useTimeline` for the overlap-aware positioning algorithm, `useCardSwipe` for swipe-to-delete, `useDaySwipe` for day navigation) plus two sub-components (`TaskLibrary` — the desktop drag-source sidebar, and `DailyModals` — all 7 modals in one declarative component communicating via props + emits). The same decomposition was applied to ProfileView (`AccountSettings` / `FamilyCircle` / `WalletPanel`). The payoff: the positioning algorithm has 8 unit tests it could never have had while embedded in a 1000-line component.

**Q: "How does the app differ between mobile and desktop?"**

> Same views, different interaction models, chosen by what each device is for (PRODUCT.md: mobile = quick actions, desktop = planning). Desktop: floating pill navigation, drag-and-drop scheduling from the task sidebar. Mobile: bottom tab bar, task sheet instead of drag-and-drop, swipe gestures (day navigation, swipe-to-delete), per-view tab bars (e.g. ActivitiesView's Catalogue / New Activity / Budget). E2E tests run a mobile viewport pass.

---

## 7. Backend — API routes and middleware

### Middleware chain

**Q: "Describe what happens to a request before it reaches your business logic."**

> The chain in `backend/src/app.js`, in order:
> 1. `trust proxy: 1` — real client IP read from `X-Forwarded-For` set by nginx (needed for correct rate limiting).
> 2. **CORS** — origin whitelist from `ALLOWED_ORIGINS` env var; unknown origins rejected with an error. In production CORS barely matters because nginx proxies internally and the backend is never exposed.
> 3. `express.json()` — body parsing.
> 4. **Global rate limiter** — 1,000 requests / 15 min per IP, on everything.
> 5. **`requireAuth`** — Firebase JWT verification (Section 5); attaches `req.auth = { uid, email, name }`.
> 6. **Per-user rate limiter** — 300 requests / 15 min keyed by `req.auth.uid`; mounted *after* `requireAuth` so the UID is guaranteed (the code comments this explicitly).
> 7. **Route-level validation** (`validate.js`) where declared.
> 8. The route handler, which opens `withTransaction` and applies RBAC inside it.
> 9. A final error-handling middleware catches anything thrown and returns a generic 500 — internal details are never leaked to the client.

**Q: "How does your role-based access control work?"**

> Two-level hierarchy (`caregiver` = 2 > `member` = 1) in `backend/src/middleware/rbac.js`, with **two deliberate forms**: `requireRole(role, getFamilyId)` is Express middleware for when the familyId is in the URL (e.g. `PATCH /:familyId/members/:userId/role`), and `assertMemberRole(client, userId, familyId, role)` is an in-transaction helper for when the familyId is only known after a DB lookup (e.g. validating an activity — you must fetch the activity to learn its family). Both check the same thing: an *active* row in `family_members` with sufficient role. The dual form is a good answer to "why not just middleware?" — middleware can't check a familyId it doesn't have yet, and doing the check inside the transaction means the role is evaluated against the same consistent snapshot as the mutation.

**Q: "How do you validate request input?"**

> A zero-dependency validation middleware (`validate.js`) built from composable rule functions — `required()`, `string(min, max)`, `positiveInt()`, `email()`, `isoDate()`, `oneOf([...])` — used declaratively per route: `validateBody({ title: [required(), string(1, 100)] })`. Each rule returns an error message or null; failures return 400 with field-level messages before any DB work happens. Why not a library like Joi or Zod? The needed rule set is ~6 functions; writing them took less code than a library's configuration, with no dependency surface. (Tribunals tend to like a justified "I built it" more than an unjustified `npm install`.)

**Q: "How are your routes organised? Why this structure?"**

> Seven resource-oriented routers (`me`, `families`, `activities`, `dashboard`, `marketplace`, `stats`, `absences`), all mounted identically: `app.use('/api/X', requireAuth, perUserLimiter, router)`. For the complex domains (activities, families, members) routes are thin HTTP adapters: they parse params, open `withTransaction`, call a **service function**, map `{ error: { code, message } }` to an HTTP status, and fire notifications *after* the transaction commits. The core business logic lives in `src/services/` as pure functions that receive a DB client — which is exactly what makes the 44 backend unit tests possible without a database. (Simpler read-heavy routes query inline — see "Where does the SQL actually live?" in Section 8.)

**Q: "Why do notifications fire after the transaction, and what if the notification fails?"**

> Ordering matters: the FCM send happens only after COMMIT succeeds, so a user is never notified about a change that rolled back. The send is fire-and-forget (not awaited into the response path) — a notification failure must never fail the API call. Trade-off to own honestly: delivery is best-effort; there's no outbox/retry queue. At family scale a missed push is acceptable; the in-app state is always authoritative.

**Q: "What does a consistent error contract buy you?"**

> Every service returns either `{ data }` or `{ error: { code, message } }` — never throws for business failures. Routes translate that 1:1 to HTTP. Thrown exceptions are reserved for genuine faults (DB down), which trigger ROLLBACK and the generic 500 handler. This makes error handling testable (unit tests assert on the error object) and keeps status codes consistent across all 50+ endpoints: 401 unauthenticated, 403 wrong role / not a member, 404 not found or not yours, 409 invalid state transition, 400 invalid input.

**Q: "Why is `/health` outside the rate limiter discussion, and `/uploads` outside `/api`?"**

> `/health` is unauthenticated by design — Docker/orchestration needs to probe liveness without credentials. `/uploads` serves avatar images as static files via `express.static`; they're read-only public assets within the deployment, and nginx proxies them in production. Both are conscious exceptions to the "everything behind requireAuth" rule, and being able to name them shows you know your attack surface.

---

## 8. Backend layering — middleware vs. routes vs. services

The three folders are the three layers of a classic layered architecture. The cleanest way to see the difference: ask of each file *what does it know about, what does it receive, and what does it return?*

### `middleware/` — cross-cutting gatekeepers

These files know about **HTTP, but not about the domain**. A middleware function receives `(req, res, next)` and makes a single yes/no decision that applies to *many* routes, before any business logic runs:

- `auth.js` — "does this request carry a valid Firebase token?" → attaches `req.auth` or returns 401.
- `rbac.js` (`requireRole`) — "is this user a caregiver in this family?" → continues or 403.
- `validate.js` — "is the request body well-formed?" → continues or 400.
- `audit.js` — observes and records; decides nothing.

Defining property: **reusable and stackable**. None of them knows whether the request is about activities or rewards — `requireAuth` is the same function in front of all seven routers. They answer "*may* this request proceed?", never "what should happen?".

### `routes/` — HTTP translation layer

These files know about **both HTTP and the domain, but contain no logic of either**. A route handler in `activities.js` does exactly four mechanical things:

1. **Parse** the HTTP request into plain values (`Number(req.params.id)`).
2. **Open the transaction** (`withTransaction`) and call a service function.
3. **Translate** the service's result back into HTTP: `{ error: { code, message } }` → `res.status(code).json(...)`, `{ data }` → `res.json(data)`.
4. **Trigger side effects after commit** — the FCM notifications fire here, once the transaction has succeeded.

A route is an adapter: swapping Express for Fastify, or exposing the same operations over a CLI, would change *only this folder*. In the two most complex routers (`activities.js`, `families.js`) there is zero SQL — everything is delegated to services. (Some simpler routers do query inline — see "Where does the SQL actually live?" below.)

### `services/` — pure business logic

These files know about **the domain and the database, but nothing about HTTP**. The signatures show it:

```js
export async function validateActivity(client, userId, activityId)
```

No `req`, no `res`. A service receives a DB **client already inside a transaction**, plain values, and returns plain objects — `{ data, ... }` or `{ error: { code: 409, message: '...' } }`. The `code` happens to align with HTTP status codes, but the service neither knows nor cares that Express exists. All the rules live here: "you can't validate your own activity", "the activity must be `pending_validation`", "coins are escrowed when a bounty is offered".

This is the property that makes the 44 backend unit tests possible: a test passes a **mock client** and asserts on the returned object — no server, no network, no database.

### One-line version for the tribunal

> "Middleware answers *'may this request proceed?'* and is shared across all routes. Routes answer *'how does HTTP map to my domain?'* and contain no logic — they parse, open a transaction, call a service, translate the result. Services answer *'what are the rules of the system?'* and know nothing about HTTP — they take a transaction client and plain values and return data or a typed error. The boundary discipline is what lets me unit-test all the business rules with a mock database client."

### The apparent violation worth pre-empting

RBAC appears **twice** — as middleware (`requireRole`, when the familyId is in the URL) and as a service-layer helper (`assertMemberRole`, when the familyId is only known after fetching the entity inside the transaction). Same rule, two layers, because an activity's family isn't knowable until you've read the activity. If a tribunal member spots it, naming that reason turns a "gotcha" into a point in your favor.

### Request lifecycle — the call direction, traced end to end

The call direction is **frontend → middleware → route → service**, and the response travels back in reverse. The route calls the service, never the other way around — services have no imports from `routes/` or Express at all.

Concrete trace: a caregiver validates activity 42.

**1. Frontend fires the request** (via the auth store helper):

```js
authStore.request('/api/activities/42/validate', { method: 'POST', headers: authStore.authHeaders() })
```

**2. Express receives it — middleware runs FIRST.** The mounting line in `backend/src/app.js:68` defines the order:

```js
app.use('/api/activities', requireAuth, perUserLimiter, activitiesRouter);
//                         ─────1─────  ──────2───────  ───────3──────
```

Express executes left to right. Before the route handler ever sees the request: `requireAuth` verifies the JWT and attaches `req.auth` (or stops with 401 — the route never runs), `perUserLimiter` checks the rate limit (or 429), and only then does Express enter the router and match `POST /:id/validate` — where the route-level `validateParams('id')` middleware runs before the handler body. The global middleware (CORS, `express.json()`, IP rate limiter) ran even earlier, because they're `app.use(...)`'d above the routers.

**3. The route handler calls the service** (`backend/src/routes/activities.js:148`):

```js
activitiesRouter.post('/:id/validate', validateParams('id'), async (req, res) => {
  const activityId = Number(req.params.id);
  const result = await withTransaction(async (client) => {
    const user = await upsertUserFromAuth(client, req.auth);
    return activityService.validateActivity(client, user.id, activityId);  // ← ROUTE CALLS SERVICE
  });
  if (result.error) return res.status(result.error.code).json({ error: result.error.message });
  notifyUser(result.act.assigned_to, { ... });   // side effect, after commit
  return res.json(result.data);
});
```

Note what the route passes down: not `req`, but extracted plain values (`user.id`, `activityId`) plus the transaction client. That's the layering boundary in action.

**4. The service does the work and returns plain data.** `validateActivity` runs the SQL, enforces the rules, and returns `{ data, act }` or `{ error: { code, message } }`. The result flows back **up** the call stack to the route, which translates it to an HTTP response.

```
Frontend (fetch with Bearer token)
   │
   ▼
nginx ──► Express
   │
   ▼  middleware (gatekeepers — can stop the request)
 CORS → json() → IP limiter → requireAuth → perUserLimiter → validateParams
   │
   ▼  route (translator — calls down, never called from below)
 POST /:id/validate → withTransaction → activityService.validateActivity(client, userId, id)
   │                                          │
   │                                          ▼  service (rules + SQL)
   │                            FOR UPDATE, status check, coin mint
   │                                          │
   ◄──────────── { data } or { error } ◄──────┘
   │
   ▼
 res.status(...).json(...)  ──► back to frontend
```

The dependency arrow only ever points downward: routes import services; services import nothing from routes; middleware is imported by `app.js` and wired in front of routes. That one-way dependency is what "layered architecture" means.

### Where does the SQL actually live? (be precise — don't overclaim)

**Not only in services.** The real distribution (verified by grep over `client.query`/`pool.query`):

| Location | Query calls | What's there |
|---|---|---|
| `services/` | 91 | `activityService` (46), `familyService` (24), `memberService` (21) — the complex, unit-tested domains |
| `routes/` | 62 | `me.js` (19), `stats.js` (13), `dashboard.js` (12), `marketplace.js` (9), `absences.js` (6), `inviteLinks.js` (3) — inline queries, still inside `withTransaction` |
| `db/` | 12 | shared helpers: `pool`/`withTransaction`, `upsertUserFromAuth`, `assertActiveMember`, `autoComplete` sweep, default activities seeding |
| `utils/` | 4 | `notify.js` — FCM token lookups and stale-token pruning |
| `middleware/` | 3 | `rbac.js` role lookup, `audit.js` login history |

Notably, `routes/activities.js` and `routes/families.js` contain **zero** SQL — fully delegated to services.

**The honest framing for the tribunal:**

> "I applied the service layer where the business rules are complex, stateful, and worth unit-testing in isolation — the activity lifecycle state machine, the family-deletion consensus flow, membership and invitations. Read-heavy or single-purpose endpoints like stats, dashboard, and profile keep their queries inline in the route, still inside a transaction. That's a deliberate cost/benefit line: extracting a service for a one-off SELECT adds indirection without adding testability."

**Expect the follow-up:** *"`marketplace.js` redeem has real business logic (atomic coin debit + redemption insert) inline in the route — why isn't that a service?"* — Honest answer: single call site, no reuse, fully transactional; it's a fair candidate for the next service extraction, and recognising that is part of knowing the architecture's boundaries.

---

## 9. Frontend layering — where the logic really lives (be precise — don't overclaim)

Audited by line counts, import graph, and API-call distribution across `views/`, `components/`, `composables/`, `stores/`.

### Views are the orchestrators — and they own the API calls

Distribution of `authStore.request()` calls: **views carry almost all of them** (DailyView 11, ProfileView 9, DashboardView 7, ActivitiesView 5, Onboarding 4, Marketplace 3, Stats 1, Join 1), plus the profile sub-components (FamilyCircle 5, AccountSettings 3). The stores make only **3 API calls total** (`family.js` 2, `auth.js` 1) and composables 2 (`useNotifications`).

So data fetching is deliberately **view-local**: each view loads what it needs and refetches after its own mutations. Only identity and family context are global state. This is consistent — but present it as a decision, not an accident:

> "Views own their data lifecycle; the stores hold only cross-view state (session, family). The trade-off is refetching on navigation, which at family scale is negligible and guarantees freshness in a multi-user app."

### The big views are mostly CSS, not logic

| View | Total | Script | Template | Scoped CSS |
|---|---|---|---|---|
| DailyView | 1,402 | 327 | 249 | **821** |
| LandingView | 1,185 | 49 | 392 | **739** |
| DashboardView | 849 | 294 | 279 | 271 |
| StatsView | 686 | 331 (ECharts configs) | 123 | 227 |

If asked *"DailyView is 1,400 lines — isn't that a god component?"*: the script block is 327 lines; ~60% of the file is scoped CSS, and the logic was extracted into three composables and two sub-components. LandingView's 49-line script vs. 1,130 lines of markup+CSS is the "brand surface" claim made measurable — design *is* the product there.

The CSS weight is the honest cost of the custom design system: no utility framework means hand-written styles per view. Own it: the trade was CSS volume for full control of the brand register and zero framework dependency.

### Two kinds of components — only one is "reuse"

- **Design-system primitives, genuinely reused:** `VButton` (8 importing files), `VCard` (8), `VInput` (5), `VSelect` (4), `KpiCard` (2 — both chart-heavy views).
- **Decomposition components, used exactly once:** `TaskLibrary` and `DailyModals` (only DailyView), `AccountSettings`, `FamilyCircle`, `WalletPanel` (only ProfileView).

If a tribunal member says *"your sub-components are only used once — that's not reuse"*: correct, and that extraction was never for reuse — it was for **separation of concerns** (keeping DailyView and ProfileView as thin coordinators) and **reviewability**. The reuse layer is the V* primitives.

### Composables follow the same split

- **Genuinely reused:** `useCurrentFamily` — imported by 6 views, the most-reused unit in the frontend (derives family, role, familyId from the store). `useNotifications` — App.vue (silent token re-sync on startup) + AccountSettings (enable/disable toggle).
- **Single-consumer, extracted for testability:** `useTimeline` (122 lines — the overlap-aware positioning algorithm), `useCardSwipe`, `useDaySwipe` — all used only by DailyView. The payoff is concrete: `useTimeline` has 8 unit tests that would be impossible with the logic embedded in a `.vue` file.

### Stores are thin by design

`auth.js` (160 lines) is mostly session plumbing: the `onIdTokenChanged` listener, `authHeaders()`, the `request()` helper with timeout/error handling, and toast state. `family.js` is 33 lines — one fetch action and state. No domain logic lives in stores.

### The one-line version for the tribunal

> "The frontend has two extraction motives, used deliberately: primitives extracted for *reuse* — five design-system components imported across up to eight files — and logic extracted for *isolation and testability* — composables and view sub-components that have a single consumer but carry the unit tests. Views orchestrate: they own data fetching and compose the pieces; stores hold only identity and family context; and the bulk of the large view files is scoped CSS, which is the deliberate cost of a custom design system over a utility framework."

---

## 10. Testing — full structure audit and question set

Verified inventory: **44 backend unit tests** (2 files, Node's built-in `node --test`, `--test-concurrency=1`), **25 frontend unit tests** (3 files, Vitest: `useTimeline` 18, auth store 5, family store 2), **47 E2E definitions** (7 spec files, Playwright, 6 projects across Chromium + WebKit ≈ 72 executions). No coverage tooling is configured in either package.

**Q: "Where is unit testing performed — and where is it not?"**

> Unit-tested: 13 of ~29 backend service functions, the timeline composable, and both stores. **Not** unit-tested: middleware (`auth`, `rbac`, `validate`, `audit`), the routes with inline SQL (stats, dashboard, me, marketplace, absences), `notify.js`/`mailer.js`, scheduling/recurrence/creation in `activityService`, `runAutoCompleteSweep`, and all `.vue` components — there are zero mounted-component tests. Those layers are exercised only through the 47 E2E tests, which drive the real middleware chain, real routes, and real components in a browser.

**Q: "Why those 13 service functions and not the rest?"**

> The selection is **risk-based, and you can show the criterion**: every function that *moves coins* (complete, validate, offer/accept/revert bounty, budget calculation) and every consensus or permission flow (family deletion approval, join by token, join by invitation, member approval). Where a wrong line of code costs a family money or lets a stranger in, there's a unit test; where it renders a list, E2E suffices. Error paths are tested as thoroughly as happy paths — 403 self-validation, 409 wrong state, 410 expired/revoked/exhausted invite links.

**Q: "Why no component tests for the Vue views?"**

> Honest answer: the logic worth testing was *extracted out of* the components precisely so it could be tested as plain JavaScript — `useTimeline`'s positioning algorithm has 18 assertions that need no DOM. What remains in components is mostly template wiring and CSS, where mounted-component tests have a poor signal-to-maintenance ratio; the E2E layer tests the real rendered result instead (including a mobile viewport pass and WebKit). Concede the gap honestly if pushed: `DailyModals`' props/emits contracts are untested at unit level.

**Q: "How do backend tests run without a database?"**

> A ~25-line hand-rolled `mockClient(responses)`: each test scripts the DB responses in order, the mock records every query and **throws on any unexpected extra query**, and assertions check both the returned object and the recorded SQL/params. Zero infrastructure, runs in milliseconds, fully deterministic.

**Q: "What's the weakness of that mocking approach?"** *(know this before they say it)*

> Two real ones. (1) The tests are **coupled to query order** — refactoring a service to merge two SELECTs breaks tests without breaking behaviour. (2) The SQL text itself is **never validated** — a typo in a column name passes unit tests and only fails in E2E or production. The honest framing: this is the classic unit/integration trade-off; the gap is partially covered by E2E (which hits the real Postgres schema), and the principled fix would be a third layer of service tests against a throwaway Postgres (e.g. testcontainers) — name it as future work before they do.

**Q: "Explain your E2E architecture."** *(strongest material — invite this)*

> Playwright's `webServer` config **boots the entire stack itself**: Firebase Auth Emulator (port 9099), backend in test mode (`FIREBASE_AUTH_EMULATOR_HOST` set), and frontend in test mode (`VITE_USE_EMULATOR=true`) — one command, fully offline, no real Google account. `global.setup.js` seeds three users via the emulator's REST API and the real backend API (so seeding exercises production code paths), then saves **three `storageState` files**: an authenticated user with a family, a second family member, and a family-less onboarding user. Six Playwright projects then slice the specs: authenticated Chromium, public (no auth), multi-user, onboarding-state, and WebKit for happy paths + landing — so auth-guard redirects, first-run onboarding, and cross-user flows each run under the exact session state they need, without any test logging in through the UI repeatedly.

**Q: "What is the strongest point of your test suite?"**

> The **two-user E2E test** (`two-users.spec.js`): two simultaneous browser contexts where one user completes an activity and the other validates it, and the bounty flow crosses users. It proves the multi-user core of the product — coins, validation-by-another, notification triggers — through the full real stack: browser → nginx-less dev proxy → Express middleware → transactions → Postgres → back to a *different* user's browser. Very few TFGs test cross-user interaction at all.

**Q: "What is the weakest point?"**

> Pick one and own it; candidates in honesty order: (1) **`runAutoCompleteSweep` is untested** — it moves coins, which breaks the "every money path is unit-tested" claim; it's the first test to write next. (2) **No coverage metric** — test selection was risk-based but unmeasured; a coverage report would have exposed gap (1). (3) **Push delivery is never tested end-to-end** — `notifications.spec.js` tests permission detection and preference toggles, but no test asserts an FCM message arrives; that would need real FCM infrastructure or a mock push service.

**Q: "Why `retries: 0` and `fullyParallel: false` in Playwright? Isn't that slow?"**

> Deliberate: retries hide flakiness instead of fixing it, and the specs share seeded state (one family, known activities), so parallel workers would race on the same data. The suite is small enough (~72 executions) that determinism is worth more than the minutes saved. Trade-off to name: proper test isolation (per-worker families) would unlock parallelism — future work.

**Q: "Why Node's built-in test runner on the backend but Vitest on the frontend?"**

> Each runner matches its environment: backend tests are pure Node with zero dependencies (`node --test` ships with Node 20 — no devDependency at all); frontend tests need jsdom, Vue reactivity, and Vite's module resolution, which is exactly what Vitest provides. Using one runner for both would force the heavier tool onto the side that doesn't need it.

**The honest one-liner for the tribunal:**

> "It's a deliberate test pyramid: 69 unit tests on the layers where a bug costs money or access — the coin lifecycle, consensus flows, the timeline algorithm — and 47 end-to-end tests that drive the real stack, offline, against the Firebase emulator, including a two-browser test of the cross-user validation flow. The known gaps are the auto-complete sweep, coverage measurement, and push delivery, and I can rank them by risk."

---

## 11. The auto-complete sweep — lazy evaluation, NOT a background job

**Terminology warning before the defense:** `README.md` (Part 15) calls `runAutoCompleteSweep` a "Background Job". It is not one — there is **no cron, no `setInterval`, no scheduler anywhere in the backend**. If you call it a background job and a tribunal member asks "what schedules it?", you're caught. Introduce it yourself with the accurate name: a **lazy sweep-on-read**.

### How it's actually called — three call sites, all user-triggered

1. **`listActivities`** (`activityService.js:9`) — every time anyone opens the activities view, the sweep runs first (after the membership check, before the SELECT), inside the same transaction. The list a user sees never contains a stale "approved" activity whose end time passed — it has been flipped to `completed` and paid in the same transaction that reads the list.
2. **Dashboard load** (`routes/dashboard.js:99`) — before computing balances, KPIs, and the member grid. (The monthly coin distribution just above it follows the same lazy pattern: it runs on the first dashboard load of the month, not on a timer.)
3. **`scheduleActivity`** (`activityService.js:135`) — the special case: scheduling an activity **in the past** (logging something that already happened) creates it as `approved` and sweeps immediately, so it's completed and paid within the same request; the row is then re-read so the response shows its final state.

### Why lazy-on-read instead of a cron job

- **No scheduler infrastructure** — a cron needs an always-running process, monitoring, and its own connection management; the lazy sweep needs nothing.
- **Transactional consistency with what the user sees** — the sweep runs inside the *same transaction* as the read that follows. An independent cron could complete an activity between two frontend fetches, showing inconsistent data; here the data is swept exactly when it's about to be displayed.
- **Work proportional to usage** — an inactive family costs zero cycles; the sweep is per-family (`WHERE family_id = $1`), so each request cleans only its own tenant.
- **Concurrency-safe by the same mechanism as everything else** — two simultaneous dashboard loads both `SELECT ... FOR UPDATE` the expired rows; the second blocks, then Postgres re-evaluates the rows, sees `status` is no longer `'approved'`, and returns nothing. No double payout.

### The trade-off to own honestly

**If nobody opens the app, nothing happens.** A past-due activity stays `approved` and the coins stay unpaid until the next time anyone in the family loads the activities list or dashboard. For a family app this is acceptable — the data only matters when someone is looking at it. At enterprise scale (server-generated reports, monthly statements, exports) you'd need a real scheduled job. Another clean "family-scale by design" answer.

### 30-second tribunal version

> "Auto-completion is evaluated lazily, on read: when anyone loads the activities list or the dashboard, a per-family sweep runs inside that same transaction, completing past-due approved activities and paying their coins before the data is returned. I chose this over a cron job deliberately — it needs no scheduler, it's transactionally consistent with what the user is about to see, it costs nothing for inactive families, and the FOR UPDATE row locks make concurrent sweeps safe. The trade-off is that payouts wait until someone opens the app, which is the right trade at family scale."

---

## 12. SQL injection — verified not possible

**Q: "Is your app vulnerable to SQL injection?"**

No — verified by reading every `client.query()` call across the backend. Two mechanisms close the attack surface completely.

### Every user value goes through `$N` placeholders

Every `client.query()` call passes user-controlled values as the **second argument** (the params array), never concatenated into the SQL string:

```js
// always this — value is a parameter, never in the string
client.query(`SELECT * FROM activities WHERE id = $1`, [activityId])

// never this — which would be injection
client.query(`SELECT * FROM activities WHERE id = ${activityId}`)
```

The `pg` driver sends the query text and the parameter values as **separate protocol messages to Postgres**. The database receives them independently and never interprets the values as SQL syntax. This is the complete, sufficient defence against injection — no sanitisation library needed.

### The one place that looks dangerous — `prefClause` — is safe

`utils/notify.js:16` is the only place in the whole codebase that dynamically builds a SQL fragment using string interpolation:

```js
const VALID_PREF_KEYS = new Set([
  'activity_assigned', 'activity_validated', 'activity_completed',
  'bounty_offered', 'family_events'
]);

function prefClause(prefKey) {
  if (!prefKey || !VALID_PREF_KEYS.has(prefKey)) return '';
  return `AND COALESCE(np.${prefKey}, true) = true`;
}
```

`prefKey` is interpolated directly into SQL — so if an attacker could supply an arbitrary string here, injection would be possible. Two things prevent it: (1) the **whitelist check** (`VALID_PREF_KEYS.has(prefKey)`) rejects anything not in the set of five known column names, returning an empty string; (2) `prefKey` is a **constant hardcoded at every call site** in the route handlers — it never comes from a user request at the HTTP boundary.

### Path traversal on avatar uploads (same category, also closed)

The only non-SQL place where user input touches a file path:

```js
String(Number(familyId))   // before using as a path segment
String(Number(actorId))
```

Casting to Number and back to String turns any non-numeric input into `"NaN"`, which would be caught upstream. Combined with MIME-type validation and normalised filenames (`avatar.<ext>`), path traversal is also closed.

### 30-second tribunal version

> "All database queries use `pg`'s parameterised query API — user values go in the params array, never in the SQL string, so Postgres receives them as data and never interprets them as syntax. The one dynamic SQL fragment in the codebase is `prefClause` in `notify.js`, which interpolates a column name — but it's guarded by a whitelist Set before interpolation, and the value never comes from a user request anyway. There is no injection surface."
