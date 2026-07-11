# Store Release Checklist — CareCoins (Flutter)

How the native apps reach production: both store builds talk to the same
public gateway the web app uses — nginx on `https://mycarecoins.app`
proxies `/api` and `/uploads` to the backend container. Nothing extra to
expose; release builds just bake in the absolute URL:

```bash
flutter build ipa       --dart-define=API_BASE=https://mycarecoins.app
flutter build appbundle --dart-define=API_BASE=https://mycarecoins.app
```

Cleartext HTTP is dev-only as of 2026-07-11: iOS ships
`NSAllowsLocalNetworking` (no `NSAllowsArbitraryLoads`), Android's
`usesCleartextTraffic` lives only in the debug manifest.

---

## Once per release (both stores)

- [ ] Bump `version:` in `fluterFront/pubspec.yaml` (`x.y.z+buildNumber`;
      the build number must increase on every store upload).
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
- [ ] Create `android/key.properties` (gitignored) with storeFile /
      storePassword / keyAlias / keyPassword, and wire the
      `signingConfigs.release` block into `android/app/build.gradle.kts`
      (the Flutter template currently signs release with debug keys —
      Play will reject that).
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

- [ ] Privacy policy URL — **required** by both stores (the app has
      accounts, avatars, push). Host it on mycarecoins.app.
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
