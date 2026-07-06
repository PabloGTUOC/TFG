# CareCoins — Flutter frontend (`fluterFront`)

Flutter port of the Vue frontend in `../frontend`, targeting **web, iOS and Android**.
It is not the main frontend yet — it exists to start optimizing for native deployment.
It talks to the same backend (`../backend`, port 3000) with the same Firebase-ID-token auth.

## What is ported

- **Design system** (`lib/theme/app_theme.dart`): the exact tokens from `frontend/src/style.css`
  (colors, radii, Plus Jakarta Sans via `google_fonts`), plus Flutter twins of `VCard`,
  `VButton`, `VInput`, `KpiCard` and the pill header / bottom tab bar from `App.vue`
  (`lib/widgets/ui.dart`, `lib/screens/shell.dart`).
- **State + API** (`lib/state/app_state.dart`, `lib/services/api_client.dart`): mirrors
  `stores/auth.js` / `stores/family.js` — Firebase auth (email/password + Google), `/api/me`
  sync, login/logout events, success/error toasts with the same timings.
- **Screens**: Login, Onboarding (create family / join by code / invitations), Family Hub
  dashboard (member cards, week strip, offers, KPIs), Daily timeline (schedule from library,
  validate, remove), Activities (filters + New Activity with coin slider), Marketplace
  (Store / History / Create), Stats (balances, completion rates, status distribution),
  Personal Area (family banner, dark wallet + monthly ledger, account settings, logout).

## Not ported yet (first-pass simplifications)

- Recurrence editing, bounties/bribes actions, absences, delegation/take-over,
  invite links + QR, avatar upload, push notifications (FCM), the marketing landing page.
- Stats trend-by-month and coin-flow charts (needs a chart package or custom painters).
- Swipe gestures from the Daily view (swipe day change, swipe-to-delete).

## Running it

```bash
cd fluterFront
flutter pub get

# Web (Chrome)
flutter run -d chrome --dart-define=API_BASE=http://localhost:3000

# iOS simulator / Android emulator
flutter run --dart-define=API_BASE=http://localhost:3000     # iOS
flutter run --dart-define=API_BASE=http://10.0.2.2:3000      # Android emulator
```

The backend URL defaults to `http://localhost:3000`; override with `--dart-define=API_BASE=…`
(use your machine's LAN IP for a physical phone).

## Firebase setup (required for real sign-in)

`lib/firebase_options.dart` currently carries the same dev fallbacks as
`frontend/src/firebase.js`. For real auth (and before any native release):

```bash
dart pub global activate flutterfire_cli
flutterfire configure        # select the same Firebase project as the web app
```

This regenerates `firebase_options.dart` and adds `google-services.json` /
`GoogleService-Info.plist` for Android/iOS. Google Sign-In on iOS additionally needs the
reversed client ID URL scheme in `ios/Runner/Info.plist`; on Android, register the app's
SHA-1 in the Firebase console.

You can also inject the web config without flutterfire via dart-defines:
`--dart-define=FIREBASE_API_KEY=… --dart-define=FIREBASE_PROJECT_ID=…` etc.

## Platform folders

`android/`, `ios/` and `web/` are generated with `flutter create`. If they are missing
(fresh checkout), regenerate them without touching `lib/`:

```bash
cd fluterFront
flutter create --org com.carecoins --project-name carecoins_flutter --platforms web,ios,android .
```
