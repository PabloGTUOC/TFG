# Deployment Guide — CareCoins

The complete path from this repo to users, written to be followed top to
bottom by a person or an AI session with no other context. Three
independent deliveries share one backend:

```
                        ┌─▶ 1. Server (web app + API)   docker compose, ~10 min
git push origin main ───┼─▶ 2. iOS app                  TestFlight → App Store
                        └─▶ 3. Android app              internal track → Play
```

Do **1 first**: the store apps are built against the public API URL, so
the server must already serve the new stack.

State as of 2026-07-11: main serves the Flutter frontend (`fluterFront/`);
the retired Vue app lives complete on the `vue-frontend` branch. The
`fluterFront` Docker image is verified to build. Store network configs are
release-safe (no cleartext HTTP outside debug builds).

---

## 1. Server — web app + backend

Production is a single Docker Compose stack behind Cloudflare:
`Cloudflare (HTTPS) → nginx :80 (frontend container) → backend:3000 + postgres`.
The nginx container serves the **Flutter web build** and proxies `/api`
and `/uploads` to the backend — this same proxy is what the native apps
use, so nothing extra is ever exposed for them.

On the server:

```bash
git pull                          # new docker-compose.yml + fluterFront/
docker compose up --build -d      # rebuilds frontend image, restarts stack
docker compose ps                 # everything Up; db-init exits 0 (normal)
```

Notes:
- `db-init` applies schema + all migrations idempotently on every start —
  the new `onboarding_events` table is created automatically.
- `firebase-credentials.json` must exist next to docker-compose.yml
  (unchanged from the Vue deploys).
- The old `VITE_*` env vars are no longer read by the build; the Flutter
  web app compiles its Firebase config in.

Smoke test at https://mycarecoins.app: landing page renders → sign in
with email → sign in with Google → an avatar image loads (proves
`/uploads` proxying) → enable push notifications (proves the
`firebase-messaging-sw.js` service worker).

**Rollback:** `git checkout vue-frontend && docker compose up --build -d`
restores the Vue frontend against the same backend and data.

---

## 2. iOS — TestFlight, then App Store

Prerequisites (one-time, in this order):

1. **Apple Developer Program** membership ($99/yr) on your Apple ID.
2. Open `fluterFront/ios/Runner.xcworkspace` in Xcode → Signing &
   Capabilities → select your Team → **+ Capability → Push Notifications**.
3. Firebase console → Project settings → Cloud Messaging → Apple app →
   **upload an APNs auth key** (create it in the Apple Developer portal
   under Keys). Without this, FCM cannot deliver to iOS.
4. App Store Connect → create the app record, bundle id
   `com.carecoins.carecoinsFlutter`.

Every release:

```bash
cd fluterFront
# bump version: x.y.z+N in pubspec.yaml (N must increase every upload)
flutter build ipa --dart-define=API_BASE=https://mycarecoins.app
```

Upload `build/ios/ipa/*.ipa` with Xcode Organizer or the Transporter app.
It appears in **TestFlight** — distribute to your test families from
there (no review needed for internal testers). When ready for the public
store, submit for review **with a demo account** in the review notes
(reviewers cannot join a family without an invite).

---

## 3. Android — internal track, then Google Play

Prerequisites (one-time):

1. **Play Console** account ($25 one-time).
2. Create an upload keystore (keep it + passwords safe **outside the repo**):
   ```bash
   keytool -genkey -v -keystore ~/carecoins-upload.jks -alias upload \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
   (`keytool` lives at `/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool`.)
3. Create `fluterFront/android/key.properties` (gitignored) with
   `storeFile`, `storePassword`, `keyAlias`, `keyPassword`, and wire a
   `signingConfigs.release` block into `android/app/build.gradle.kts`.
   **The template currently debug-signs release builds; Play rejects
   those.**
4. Play Console → create app → enroll in **Play App Signing**.
5. Register **two SHA-1s** in Firebase (Project settings → Android app →
   Add fingerprint), then re-download `google-services.json` into
   `fluterFront/android/app/`:
   - the upload keystore's SHA-1 (`keytool -list -v -keystore ~/carecoins-upload.jks`),
   - the Play App Signing SHA-1 (Play Console → Setup → App integrity).
   Missing fingerprints = Google Sign-In "error code 10" in production.

Every release:

```bash
cd fluterFront
# bump version in pubspec.yaml
flutter build appbundle --dart-define=API_BASE=https://mycarecoins.app
```

Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console
→ **Internal testing** first (testers install via link) → promote to
production when satisfied.

---

## 4. Store listings & paperwork (both stores)

- **Privacy policy URL** — hard requirement (accounts, photos, push).
  Host a page on mycarecoins.app before creating listings.
- Data-safety / privacy-nutrition forms: account data (email, name,
  avatar), user content (tasks, rewards), push token. No ads, no
  tracking SDKs.
- Screenshots: iPhone 6.7" + iPad 13" (simulators), Android phone +
  10" tablet (emulators).
- App icon already ships in the builds (generated from
  `assets/icon/icon-512.png`; regenerate with
  `dart run flutter_launcher_icons`).

## 5. Post-deploy verification

On a real device from TestFlight / internal track: Google sign-in works,
a push arrives with the app backgrounded, avatar upload succeeds. Then
run `backend/scripts/onboarding-report.sql` against production after the
first cohort to measure activation (see
`docs/onboarding-help-plan.md`, Phase 4).

See also: `docs/store-release-checklist.md` (condensed per-release
checklist), `fluterFront/README.md` (local dev + Firebase setup).
