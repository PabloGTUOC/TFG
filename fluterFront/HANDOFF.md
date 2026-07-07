# Handoff — Flutter mobile bring-up (`fluterFront`)

Written 2026-07-07 on branch `claude/flutter-frontend-audit-kxfn3i`, for resuming on a
dev laptop (human + Claude Code). Read this first, then `MOBILE_AUDIT.md` for the full
findings; `README.md` has the runbooks referenced below.

## Where things stand

Work done on this branch, newest last:

| Commit | What |
|---|---|
| `919dc54` | `MOBILE_AUDIT.md` — full audit: P0 blockers / P1 mobile UX / P2 polish |
| `887234e` | **P1 implemented** — touch-safe drag & drop (`LongPressDraggable` on touch), `isWideLayout()` (phones in landscape keep mobile nav), lazy tabs + refetch-on-activation, Daily pull-to-refresh + "Tasks Today" KPI entry, dashboard `.toLocal()` fixes, `LoadErrorState` + retry on all load screens, app-root toast listener (login errors were invisible before), touch targets, autofill/Enter-submit/forgot-password, textScaler clamp, avatar `cacheWidth` |
| `4b7412a` | **P0 implemented (repo side)** — `INTERNET` + `POST_NOTIFICATIONS` in the main Android manifest, cleartext opt-outs (dev-only, commented), iOS `FirebaseOptions` hand-written from the plist (iOS auth unblocked), Google Sign-In URL scheme, `remote-notification` bg mode, app renamed **CareCoins** + branded icons everywhere (gradient ¢) |
| `886e81c` | UX drive fix: `VInput` as `AlertDialog` content stretched dialogs full-height (`mainAxisSize: min`) |
| `6ee5dda` | `--dart-define=AUTH_EMULATOR=host:port` hook; onboarding overflow fixes (placeholders, `isExpanded` dropdowns) |

**Verified**: `flutter analyze` clean, `flutter test` passing, `flutter build web` succeeding
on **Flutter 3.44.5 stable** (the pinned `firebase_messaging ^15.2.10` needs ≥ ~3.44; 3.24
fails to resolve). The **entire app was driven end-to-end in Chromium at a 390×844 phone
viewport** against the real backend + Postgres + Firebase Auth Emulator: register →
onboarding wizard → Family Hub → all five tabs → Daily task-sheet → schedule dialog →
scheduled card + success toast. Screenshots confirmed every step.

**Never done anywhere**: `flutter build apk` / any iOS build (no Android SDK / no Mac in
the cloud sandbox). That is the very first thing to do on the laptop.

## Running the full stack locally (all offline, no prod Firebase)

```bash
# 1. Postgres (any local PG 14+; docker-compose also works)
createuser carecoins -P   # password: carecoins
createdb -O carecoins carecoins
cd backend && npm install
DATABASE_URL=postgres://carecoins:carecoins@localhost:5432/carecoins npm run db:init

# 2. Firebase Auth Emulator (throwaway accounts, prod project untouched)
firebase emulators:start --only auth --project tfg-carecoins    # port 9099

# 3. Backend
DATABASE_URL=postgres://carecoins:carecoins@localhost:5432/carecoins \
FIREBASE_PROJECT_ID=tfg-carecoins FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
ALLOWED_ORIGINS=http://localhost:8080 RESEND_API_KEY=re_dummy PORT=3000 \
node src/server.js

# 4. App (device/emulator; use LAN IP on a physical phone, 10.0.2.2 on Android emu)
cd fluterFront && flutter run \
  --dart-define=API_BASE=http://<host>:3000 \
  --dart-define=AUTH_EMULATOR=<host>:9099
```

Gotchas already hit for you:
- Backend **crashes at boot without `RESEND_API_KEY`** (Resend constructor) — any dummy value works; invite emails just fail at send.
- Backend CORS allowlist is `ALLOWED_ORIGINS` (default `localhost:5173`).
- The auth emulator injects a red warning banner **overlaying the bottom tab bar** on web
  (dev-only cosmetic; it also swallows taps there).
- Family creation seeds default activity templates — a fresh family is not empty.
- For headless/CI web driving: build with `--no-web-resources-cdn` (engine otherwise
  fetches CanvasKit from gstatic) and give the browser context a `locale` (engine crashes
  on an empty one). A working Playwright driver pattern exists in the session notes if
  you regenerate it via `/run-skill-generator`.

## Task list, in order

### A. Android first (goal: app on your phone today)
1. `cd fluterFront && flutter build apk --debug` — **first ever native build**; fix
   whatever surfaces (manifest/gradle changes are unproven in a real build).
2. Register the debug SHA-1 in Firebase console → Android app → re-download
   `google-services.json` (README "Android Google Sign-In" has the keytool command).
   Without it Google Sign-In fails with error 10; email/password works regardless.
3. Install on a device; run the **on-device touch pass** (this is what the browser drive
   could NOT validate): long-press drag & drop on the Daily grid (tablet/landscape ≥600dp
   shortest side), swipe-to-remove vs day-swipe, pull-to-refresh feel, avatar upload via
   `image_picker`, native Google Sign-In, keyboard + password-manager autofill.
4. Push e2e on Android: enable notifications in Personal Area → confirm a row lands in
   `fcm_tokens` → send a test message (Firebase console) foreground + background;
   verify the Android 13 runtime permission prompt.

### B. iOS bring-up (needs the Mac)
5. `cd ios && pod install`, open in Xcode, set the signing team, first build.
   Repo side is ready: Firebase options, reversed-client-ID URL scheme, ATS exception,
   photo-library usage string, `remote-notification` bg mode.
6. Optionally re-run `flutterfire configure --platforms=ios` (needs
   `sudo gem install xcodeproj`) — should produce the same values as the hand-written
   `FirebaseOptions.ios`; diff to confirm.
7. For push: Push Notifications capability in Xcode + APNs key in Firebase console.

### C. Second-account flows (unexercised anywhere)
8. With two emulator accounts in one family: validate task → coins awarded → ledger →
   un-check revert; bounty delegate/take-over; marketplace create + redeem.

### D. Production gates (before any store release)
9. **Host the backend over HTTPS** (biggest gap — it only exists as localhost/compose),
   then **remove both cleartext opt-outs**: `android:usesCleartextTraffic` in
   `AndroidManifest.xml` and `NSAppTransportSecurity` in `Info.plist` (both carry
   `Remove…` comments), and set real defaults for `API_BASE` + `WEB_APP_ORIGIN`
   (invite QR links currently point at `localhost:5173`).
10. Deep links: `go_router` + `/join?token=…` + App Links / Universal Links so QR scans
    open the native app (audit §4.4).
11. Release mechanics: Android release keystore + its SHA-1, version bump strategy,
    privacy policy + store data-safety forms, screenshots.

### E. High-value P2s (audit §4)
12. Crash reporting (Crashlytics or Sentry) — top priority once real users exist.
13. CI for `fluterFront`: `flutter analyze && flutter test && flutter build web` (nothing
    runs today; that's how unverified commits happened before).
14. Unit tests for the extracted pure logic (timeline overlap/gap math, ledger labels,
    budget min/max), accessibility semantics on emoji-icons/tab bars, offline caching
    (`cached_network_image` — deferred only because it needs a `pub get`), dark mode,
    localization.

## Cautions

- `.env` / secrets: nothing sensitive is committed; keep the Firebase **service account**
  key out of the repo (backend only needs it for *production* token verification — the
  emulator path avoids it entirely).
- The Vue app (`frontend/`) is still the production frontend; nothing on this branch
  touches it or the backend.
- Branch has 5 commits ahead of `main`; no PR opened yet.
