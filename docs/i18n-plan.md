# Internationalization Plan — Spanish, French, German

Goal: let users choose the app language, shipping **English (default),
Spanish, French, and German** in the Flutter frontend (`fluterFront/`),
using Flutter's official localization system (`flutter_localizations` +
ARB files + the SDK's built-in `gen-l10n` generator).

Why this system: each language lives in one ARB file, the generator
produces **typed Dart getters** (a string missing from any language file
fails the build instead of silently falling back to English), ICU syntax
handles plurals/placeholders, and it needs no third-party dependency.

Scope estimate: ~380 user-facing strings across 10 screens and ~10 shared
widgets (`grep -c "Text("` ≈ 364, plus tooltips, hints, labels, snackbars,
and dialog copy).

---

## To-do

### 1. Wire up the localization system (one-time, ~30 min)

- [ ] `fluterFront/pubspec.yaml`:
  ```yaml
  dependencies:
    flutter_localizations:
      sdk: flutter
  flutter:
    generate: true
  ```
- [ ] Create `fluterFront/l10n.yaml`:
  ```yaml
  arb-dir: lib/l10n
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  untranslated-messages-file: untranslated.json
  ```
- [ ] Create `lib/l10n/app_en.arb` (template), `app_es.arb`, `app_fr.arb`,
  `app_de.arb`.
- [ ] In `MaterialApp` (`lib/main.dart`):
  ```dart
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: appState.locale, // null = follow device language
  ```

### 2. Language selection by the user

- [ ] Add `locale` to `AppState` (`lib/state/app_state.dart`), persisted
  with `shared_preferences` (already a dependency). `null` means "follow
  the device language" — keep that as the default.
- [ ] Add a language picker to the Profile screen
  (`lib/screens/profile_screen.dart`): System / English / Español /
  Français / Deutsch. Show each language in its own name, not translated.
- [ ] Setting the locale notifies listeners → `MaterialApp` rebuilds →
  the whole app switches instantly, no restart.

### 3. Extract hardcoded strings into ARB (the bulk of the work)

Replace literals with `AppLocalizations.of(context)` getters, one file at
a time. Suggested order (most user-visible first):

- [ ] `screens/shell.dart` — tab labels, app-level chrome
- [ ] `screens/dashboard_screen.dart`
- [ ] `screens/daily_screen.dart` + `widgets/absence_dialog.dart`
- [ ] `screens/login_screen.dart` + `screens/landing_screen.dart`
- [ ] `screens/onboarding_screen.dart` + `widgets/activation_checklist.dart`
- [ ] `screens/marketplace_screen.dart`
- [ ] `screens/activities_screen.dart`
- [ ] `screens/profile_screen.dart` + `widgets/family_circle.dart`
- [ ] `screens/stats_screen.dart` + `widgets/charts.dart`
- [ ] `widgets/coach_marks.dart`, `widgets/help_sheet.dart`,
  `widgets/ui.dart`, snackbar/error messages in `services/`

Extraction rules:

- Use **ICU plurals** wherever a count appears:
  `"{count, plural, one{# task} other{# tasks}}"` — never `"$count tasks"`.
- Use **placeholders** for names/amounts: `"Assigned to {name}"`,
  `"{coins} cc earned"`.
- Key naming: `screenElement` camelCase (`dailyScheduleTitle`,
  `marketplaceBuyNow`), with `@key` description entries in `app_en.arb`
  so translators get context.
- Dates/numbers: switch `DateFormat(...)` calls to locale-aware forms
  (`DateFormat.yMMMd(locale)`); `intl` is already a dependency.

### 4. Translate

- [ ] Machine-draft `app_es.arb`, `app_fr.arb`, `app_de.arb` from the
  English template.
- [ ] Native-speaker review pass (Spanish first — closest tester pool).
- [ ] Watch for German length: strings run ~30% longer, so check buttons,
  tab labels, and chips for overflow at 320 px width.

### 5. Keep languages aligned (guardrails)

- [ ] `untranslated.json` (written on every build) must be empty before a
  release; add a CI step that runs `flutter gen-l10n` and fails if any
  key is missing in any language.
- [ ] PR rule: any change to `app_en.arb` must touch the other three ARB
  files in the same PR (even if only with a `TODO-translate` draft).

### 6. Testing

- [ ] Widget test that pumps the app in each of the four locales and
  asserts a known string per screen (catches delegate wiring breaks).
- [ ] Manual smoke in Spanish on a phone: onboarding → schedule a task →
  marketplace purchase → profile.
- [ ] RTL is out of scope (none of the four languages is RTL), but avoid
  hardcoded `left`/`right` in new code — use `start`/`end`.

### 7. Out of scope for this pass (follow-ups)

- **Push notification texts** are composed by the backend
  (`backend/src/utils/notify.js`) and will remain English until the
  backend knows each user's locale — needs a `locale` column on users and
  translated templates server-side.
- **User-generated content** (task titles, reward names, family names) is
  never translated.
- The **marketing landing page** SEO copy may eventually want per-locale
  routes on the web build; not needed for the in-app picker.

---

## Suggested order & effort

| Step | Effort |
|---|---|
| 1–2. Wiring + language picker | ~half a day |
| 3. String extraction | 2–3 days (mechanical, screen by screen) |
| 4. Translations + review | 1 day machine draft; review depends on reviewers |
| 5–6. CI guardrail + tests | ~half a day |

Steps 1–3 can ship incrementally: untranslated screens simply keep
showing English while extraction progresses, as long as new keys land in
all four ARB files.
