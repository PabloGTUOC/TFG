# Store Release Checklist — CareCoins (Flutter)

How the native apps reach production: both store builds talk to the same
public gateway the web app uses — nginx on `https://mycarecoins.app`
proxies `/api` and `/uploads` to the backend container. Nothing extra to
expose; release builds just bake in the absolute URL:

```bash
flutter build ipa       --dart-define=API_BASE=https://mycarecoins.app \
                        --dart-define=RC_IOS_KEY=appl_…
flutter build appbundle --dart-define=API_BASE=https://mycarecoins.app \
                        --dart-define=RC_ANDROID_KEY=goog_…
```

> **The RevenueCat defines are not optional.** `PurchaseService` falls back to RevenueCat's
> **test store** key when they are absent, so a release built without them installs, runs,
> shows a paywall — and sells nothing. Nothing in the build output warns you.

Cleartext HTTP is dev-only as of 2026-07-11: iOS ships
`NSAllowsLocalNetworking` (no `NSAllowsArbitraryLoads`), Android's
`usesCleartextTraffic` lives only in the debug manifest.

---

## Once per release (both stores)

- [ ] Bump `version:` in `fluterFront/pubspec.yaml` (`x.y.z+buildNumber`;
      the build number must increase on every store upload).
      Currently **`1.0.0+1`** — good for the first upload, then `+2`, `+3`, …
- [ ] `flutter analyze && flutter test` clean.
- [ ] Smoke-test a **release-mode** build on a real device
      (`flutter run --release --dart-define=API_BASE=https://mycarecoins.app`):
      email login, Google login, create/validate a task, avatar upload,
      push notification.
- [ ] Server is on the latest main: `docker compose up --build -d`
      (the fluterFront image is verified to build).

## Apple App Store

One-time setup:
- [ ] Apple Developer Program membership ($99/yr).
- [ ] In Xcode (open `ios/Runner.xcworkspace`): set your Team under
      Signing & Capabilities; add the **Push Notifications** capability
      (`UIBackgroundModes: remote-notification` is already in Info.plist).
- [ ] Upload an **APNs auth key** in Firebase console → Project settings →
      Cloud Messaging → Apple app configuration (required for FCM on iOS).
- [ ] Create the app record in App Store Connect
      (bundle id `com.carecoins.carecoinsFlutter`).

Every release:
- [ ] `flutter build ipa --dart-define=API_BASE=https://mycarecoins.app`
- [ ] Upload via Xcode Organizer or `xcrun altool`/Transporter.
- [ ] TestFlight pass before submitting for review.

Review notes: ATS is store-safe (local-networking exception only). The
app signs in with Firebase Auth — provide a demo account in the review
notes since reviewers won't have a family invite.

## Google Play

One-time setup:
- [ ] Create an **upload keystore** (do NOT ship debug-signed):
      `keytool -genkey -v -keystore ~/carecoins-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`
      Back it up. Losing it before Play App Signing is enrolled means never
      being able to update the app under the same listing.
- [ ] Copy `fluterFront/android/key.properties.example` to
      `android/key.properties` and fill in the four values. Use an
      **absolute** `storeFile` path — `~` is not expanded, and a relative
      path resolves against `fluterFront/android/`.

      The `signingConfigs.release` block is already wired in
      `android/app/build.gradle.kts`. With `key.properties` present the release
      build uses it. Without it, **`flutter build appbundle` fails outright**
      with instructions — an .aab exists only to be uploaded, and Play rejects
      debug-signed uploads, so producing one is never useful. `flutter run
      --release` and `flutter build apk` still fall back to debug signing (with
      a warning) so local release testing keeps working.

      Confirm with `cd android && ./gradlew :app:signingReport` — under
      `Variant: release` you want `Config: release` and your keystore path,
      not `Config: debug`.
- [ ] Play Console: create the app, enroll in **Play App Signing**.
- [ ] Register **two SHA-1s in Firebase** (Project settings → Android app):
      the upload keystore's SHA-1 and the **Play App Signing** SHA-1
      (Play Console → Setup → App integrity). Re-download
      `google-services.json` after. Without these, Google Sign-In fails
      with error code 10 in production — same issue as the debug SHA-1
      fixed on 2026-07-10.

Every release:
- [ ] `flutter build appbundle --dart-define=API_BASE=https://mycarecoins.app`
- [ ] Upload the `.aab` in Play Console; internal-testing track first.

## Store listings (both)

- [x] Privacy policy and terms **pages exist and are served**:
      `fluterFront/web/privacy.html` and `terms.html`, published with the web
      build, with `nginx.conf` mapping `/privacy` and `/terms` to them.
- [x] Both are **linked from inside the app**, in Personal Area directly under
      the subscription card (`lib/utils/legal_links.dart`). Apple requires this
      for auto-renewable subscriptions (Guideline 3.1.2).
- [ ] **Fill in the bracketed placeholders in both pages before submitting** —
      legal entity, contact email, hosting location, retention period,
      jurisdiction — and have them reviewed. They are drafts: the factual
      sections were written from the real database schema, but the legal
      framing is not advice. For the EULA, Apple's standard one is an accepted
      substitute if you would rather not maintain your own.
- [ ] Confirm both URLs load in a plain browser on the live domain, then paste
      the privacy URL into both store listings.
- [x] **Terms of Use (EULA) + Privacy Policy reachable from inside the app** —
      done, in Personal Area under the subscription card.
- [ ] Optionally also set them as footer links on the **RevenueCat paywall**
      (dashboard → paywall configuration), so they appear at the moment of
      purchase as well as in settings. Cheap, and removes any ambiguity in
      review.
- [ ] Data-safety / privacy-nutrition forms: account data (email, name,
      avatar), user content (tasks, rewards), device token for push.
      No ads, no tracking SDKs.
- [ ] Screenshots (iPhone 6.7", iPad 13", Android phone + 10" tablet) —
      the simulator/emulator setups used in development produce all of
      these.
- [ ] App icon ✓ (already generated from `assets/icon/icon-512.png` via
      `dart run flutter_launcher_icons`).

## Post-launch smoke test

- [ ] Install from TestFlight / internal track on a real device.
- [ ] Sign in with Google (validates SHA-1 / reversed-client-id wiring).
- [ ] Receive a push with the app in background (validates APNs key /
      FCM path).
- [ ] Avatar upload (validates `/uploads` proxying through nginx).
- [ ] Run `backend/scripts/onboarding-report.sql` after the first cohort
      to measure activation.

---

## Subscriptions — **active in the app, so these are required, not preparation**

RevenueCat is wired and the paywall is reachable from Personal Area
(`widgets/subscription_card.dart` → `services/purchase_service.dart`), so the
app ships auto-renewable subscriptions. Everything below is a **review
requirement for the first submission**, not future prep:

- [ ] Subscription products created in App Store Connect and Play Console
      (matching product IDs), attached to a RevenueCat project with a
      `premium` entitlement and the webhook pointed at
      `/api/billing/webhook` (shared secret set).
- [ ] **Restore purchases** entry point present in the app — Apple requires
      it. Ours is trivial: entitlements come from the backend, so "restore"
      is a re-sync, but the button must exist.
- [ ] Paywall shows price, billing period, and auto-renewal terms before
      purchase (both stores reject paywalls that hide the renewal).
- [ ] "Manage subscription" deep links to the store's subscription
      settings (the payment relationship belongs to the user and the
      store — never cancel server-side).
- [ ] Double-purchase guard verified: a family already subscribed on the
      other platform sees "manage it there" instead of a second checkout.
- [ ] Sandbox matrix passed on both stores: purchase, renewal, cancel,
      expiration, billing-issue/grace, and cross-platform visibility
      (iOS sandbox purchase → Android member sees premium).
- [ ] Store listing metadata declares the subscription (App Store
      "In-App Purchases" section / Play "In-app products").
