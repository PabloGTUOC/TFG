# Onboarding & In-App Help Plan

**Problem.** Users report they don't understand the app's mechanics. CareCoins has a
7-step core loop (create task → approve → schedule → complete → validate → coins land →
spend in store) spread across 5 tabs, plus invented vocabulary (cc, bounty, validation,
object of care, monthly budget allocation). The existing onboarding wizard only covers
*family setup* — it never teaches the economy. New users land on an empty dashboard with
no idea what to do first.

**Approach.** Three layers, cheapest-first. Each phase ships alone.

## Layer 1 — Always-available help (the safety net)

- **"How CareCoins works" help sheet**, reachable from a `?` icon in the header and from
  the Personal Area. Contents:
  - The four-step explainer that already exists on the landing page (reuse copy + step
    visuals).
  - A **glossary**: cc, bounty, validation, object of care, budget.
  - Per-tab FAQ (e.g. "Why can't I edit a completed activity?" — users already hit this;
    the Daily view now shows a dialog for it).
- **Teaching empty states**: every empty list becomes an instruction. "No activities yet →
  **Create your first task template**" with the button right there. Empty states exist on
  all screens; they currently say "nothing here" instead of "do this next".

## Layer 2 — First-run guided tour

- **Coach marks per tab, not one long carousel.** The Flutter shell builds tabs lazily on
  first visit — hook the tour into exactly that. First time a user opens:
  - **Daily**: hour grid, + button, NOW line.
  - **Dashboard**: member cards, week agenda.
  - **Activities**: budget gauge, approve flow.
  - **Marketplace / Stats**: 2–3 marks each.
  Always skippable, never repeated.
- One **welcome dialog** after onboarding ends ("Tasks earn coins, coins buy rewards —
  we'll point things out as you go") so the tour has a frame.
- **"Replay the tour"** button inside the help sheet for users who skipped.

## Layer 3 — Activation checklist (teaches by doing)

- Dismissible **"Get your family going" card** on the dashboard with 5 checkable steps:
  create a task → schedule it → mark it done → validate it → create a reward.
- Each row deep-links to the right screen.
- Auto-checks from real data (backend already knows if each has happened); disappears
  when complete.

## Technical shape

- **State**: per-user flags for "seen tour X / dismissed checklist". Start with
  `SharedPreferences` (Flutter) / `localStorage` (Vue) — device-local, zero backend work.
  If cross-device matters later, add an `onboarding_state` JSONB column on `users`.
- **Flutter coach marks**: hand-rolled spotlight overlay (~150 lines: dark scrim + cutout
  + pill-styled tooltip using the design system) rather than a package — matches
  DESIGN.md, no dependency risk. (`showcaseview` is the fallback package option.)
- **Vue**: `driver.js` for the same tours. Keep the copy for both frontends in one shared
  JSON so the two apps never drift.
- **Measurement**: log `tour_completed`, `tour_skipped`, `checklist_step_done` events
  (same pattern as `login_history`). Define activation as "first validated task within
  7 days" to evaluate whether this worked (useful evaluation section for the TFG).

## Phasing

1. **Help sheet + glossary + teaching empty states** — pure content, biggest confusion
   relief per hour of work (~1 day).
2. **Per-tab coach marks** + welcome dialog + replay (meatiest phase: the overlay widget).
3. **Activation checklist** on the dashboard.
4. **Measurement + iterate** on whichever step users abandon.

**Order of implementation**: Flutter first (active dev + user-testing track), port to Vue
once the copy stabilizes.
