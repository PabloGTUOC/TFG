# Family Setup Questionnaire — Plan

Goal: improve the create-family wizard with a short questionnaire about
the kinds of activities the family wants, use the answers to (a) seed a
**relevant, localized** starter catalogue instead of today's fixed
English list, and (b) record what users actually want so the product can
learn from it.

## Why now — the two problems this solves

1. **Untranslated starter tasks.** `backend/src/db/defaultActivities.js`
   inserts ~21 hard-coded English template rows at family creation
   (`insertDefaultActivities`, called from `familyService.js`). They are
   database rows, not UI strings, so the gen-l10n work (docs/i18n-plan.md)
   can never reach them — a Spanish user gets "Breakfast prep" in an
   otherwise fully Spanish app.
2. **Blind seeding.** The current selection logic is a crude mapping from
   dependent types (child → 9 child tasks, pet → 3 pet tasks, household +
   generic always). Families with no pets still get "Doctor accompany";
   families who mostly need errands/admin get nothing for it, and we
   never learn what they wanted.

## Design

### 1. New wizard step: "What does care look like in your family?"

Insert one questionnaire step into the create-family flow, after
"Objects of Care". Deliberately small — two questions plus a preview:

- **Q1 — Activity areas** (multi-select chips, pre-checked from the
  dependents already entered):
  - 🍽️ Meals & cooking
  - 🧺 Cleaning & laundry
  - 🎒 Kids' routines & school runs *(pre-checked if a child was added)*
  - 📚 Homework & learning
  - 🐾 Pet care *(pre-checked if a pet was added)*
  - 🩺 Elder care & appointments *(pre-checked if elderly was added)*
  - 🧾 Errands & admin (shopping, paperwork) — *new pack*
  - 🌙 Night care *(babies; pre-checked if a child was added)*
- **Q2 — Starting point** (single choice):
  - "Start me with ready-made tasks" (default)
  - "Start empty — I'll create my own"
- **Preview list**: the starter tasks implied by Q1, each with a
  checkbox so individual tasks can be deselected before creation. This
  replaces today's take-it-or-leave-it 21-row dump and doubles as the
  create-family improvement: users see exactly what they'll get.

### 2. Client-side, localized starter packs

Move the starter **catalogue definition to the Flutter app** and send
the chosen tasks in the create-family payload:

- New `lib/data/starter_packs.dart`: packs keyed by area, each task as
  `(l10n key, category, durationMinutes, recurrent)`. Titles resolve
  through `AppLocalizations`, so the tasks are created **in the user's
  current app language** (~30 title keys × en/es/fr/de in the ARB files;
  the existing `untranslated.json` guardrail covers them).
- `POST /api/families` gains an optional `starterTasks: [{title,
  category, durationMinutes, isRecurrent}]` array. Backend inserts them
  verbatim as approved templates (same insert as today, but with the
  received titles). After creation they are ordinary user-editable
  content — consistent with the i18n-plan rule that user content is
  never machine-translated.
- **Fallback:** when `starterTasks` is absent (old clients, e2e tests,
  the retired Vue branch), keep calling `insertDefaultActivities`
  unchanged. No DB migration; existing families keep their English
  titles as normal user content.
- Detail worth fixing in passing: seeded coin values currently use a
  flat 2 cc/hr while user-created tasks use the budget's
  `baseRatePerHour`. Compute starter-task coin values server-side with
  the same budget rule so the catalogue is consistent from day one.

### 3. Record the answers (the "understand what users want" part)

- Log a `setup_questionnaire` telemetry event (existing `Telemetry`
  service → `onboarding_events` table): selected areas, deselected task
  count, and the Q2 choice. No free text, no PII.
- Persist the selection on the family row (`activity_preferences`
  jsonb, added idempotently by db-init) so future features (suggestions,
  marketplace ideas) can use it.
- Extend `backend/scripts/onboarding-report.sql` with an
  area-popularity breakdown: which packs are chosen, which starter tasks
  get deselected most (those are the ones to rewrite or drop).

### 4. Create-family wizard polish (small, while we're in there)

- Convert the single long card into a **paged stepper** (1 Family
  details → 2 Caregivers → 3 Who you care for → 4 Starter tasks), with
  progress dots, per-step validation and Back/Next; wide layouts keep
  the current two-column shell around it.
- Validate caretaker invite e-mail format before submit; disable the
  submit button while the request is in flight.
- On success, land on the dashboard with the existing welcome dialog —
  the activation checklist's "Create a task template" step should
  auto-check when starter tasks were chosen, so new families start at
  step 2 (scheduling) instead of a fully unchecked list.

## Out of scope

- Re-translating starter tasks when the user later switches app
  language (they are user content once created).
- A questionnaire for families that already exist (could be a later
  "Suggested tasks" entry in Activities, fed by the same packs).
- Backend-side i18n of `defaultActivities.js` itself — it becomes a
  legacy fallback only.

## Test plan

- **Widget tests:** questionnaire step pre-checks areas from dependents;
  deselecting a task removes it from the payload; "start empty" sends an
  empty array (not absent!) so the backend skips legacy seeding.
- **Backend tests:** `POST /api/families` with `starterTasks` inserts
  exactly those rows (approved templates, budget-based coin values);
  with the field absent, legacy defaults still appear; with an empty
  array, nothing is seeded.
- **l10n:** `untranslated.json` stays empty across all four languages;
  per-locale widget test keeps passing.
- **Manual:** create a family in Spanish → catalogue titles appear in
  Spanish; onboarding report shows the questionnaire event.

## Suggested order & effort

| Step | Effort |
|---|---|
| Starter packs in Flutter + ARB titles ×4 languages | ~half a day |
| Backend `starterTasks` + fallback + coin-value rule + tests | ~half a day |
| Questionnaire step UI + preview + stepper conversion | 1–1.5 days |
| Telemetry event + `activity_preferences` + report query | ~2 hours |

Steps can ship in two PRs: (1) packs + backend contract (fixes the
untranslated-defaults bug on its own, using the dependent types as the
implicit "questionnaire"), then (2) the questionnaire UI + stepper.
