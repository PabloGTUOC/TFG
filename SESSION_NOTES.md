# Session Notes — Mobile Daily View UI/UX Review & Fixes

## What was done this session

### 1. Project context created
- `PRODUCT.md` written at project root — register (product + brand landing), users, brand personality (loving, trusted, fun), anti-references (no Facebook/Instagram), design principles.

### 2. P0 fixes — all complete (`DailyView.vue`, `App.vue`)

| # | Issue | Fix |
|---|---|---|
| 1 | `.mobile-only` had no CSS rule — desktop showed both timeline AND mobile card list simultaneously | Added `display: none` globally + `display: flex` in `@media (max-width: 768px)` in `App.vue` |
| 2 | `.mobile-agenda` missing `display: flex` | Fixed by the same `.mobile-only` CSS rule above |
| 3 | No delete flow for tasks on mobile | Added `removeMobile(activity)` + ✕ button on each non-completed card; routes to delete modal for recurring tasks, calls `unSchedule` directly for one-off |
| 4 | `window.confirm()` used in `acceptBounty` | Replaced with `openAcceptBountyModal(activity)` + `confirmAcceptBounty()` + proper `VCard` modal |

### 3. P1 fixes — all complete (`DailyView.vue`)

| # | Issue | Fix |
|---|---|---|
| 5 | FAB too close to iPhone home indicator | `bottom: 2rem` → `calc(2rem + env(safe-area-inset-bottom, 0px))` |
| 6 | `opacity: 0.8` on pending cards failed contrast | Removed from both desktop chips and mobile cards |
| 7 | "Nope" / "Yes I'll" / "Generate" button labels | → "Cancel" / "Schedule" / "Create schedule" |
| 8 | Header line-break risk | Existing `flex-wrap: wrap` already handles it — no change needed |
| 9 | No tap affordance on task library rows | Added `background: var(--primary-soft)` + `border-color: var(--primary)` to `:active` state |
| 10 | Coin value missing from mobile cards | Added `🪙 Ncc` always visible; bounty shown as secondary pill when present |

### 4. P2 fixes — all complete (`DailyView.vue`)

| # | Issue | Fix |
|---|---|---|
| 11 | Flat empty state on mobile agenda | Calendar icon + "Your day is wide open." + instruction line |
| 12 | Completed bar placement unclear on mobile | Added "Done today" label (mobile-only) |
| 13 | Absence banner hierarchy wrong | Name (`user_alias`) is now bold primary; reason is smaller + muted |
| 14 | No AM/PM context in time select | Reactive AM/PM badge added next to minute select |
| 15 | Tracked-eyebrow category headers | Replaced all-caps + letter-spacing with colour pip + sentence-case label |
| 16 | "Generate" recurrence button label | → "Create schedule" |

### 5. P3 fixes — all complete (`DailyView.vue`)

| # | Issue | Fix |
|---|---|---|
| 17 | No loading skeleton for mobile agenda | Added `isLoadingActivities` ref; 3 shimmer skeleton cards show while data loads |
| 18 | `datetime-local` inconsistent on mobile | Split into separate `<input type="date">` + `<input type="time">` fields in absence modal |
| 19 | `min-width: 160px` hardcoded inline on date | Moved to `.date-display` CSS class; shrinks on mobile |
| 20 | No `prefers-reduced-motion` guard | Added block covering chip transitions, FAB, task rows, skeleton animation |

### 6. Mobile timeline — full redesign (`DailyView.vue`)

Replaced the flat colored card list with a condensed timeline. All 6 phases implemented.

#### Phase 1 — Progress bar in header
- "X Tasks Remaining" replaced with a green progress bar + "X / Y done · 🪙 Ncc"
- Communicates progress instead of countdown anxiety

#### Phase 2 — Data layer
- `gapBeforeMinutes` added to each item in `scheduledToday` (minutes since previous task end)
- `nowIndex` computed — index of first future task, used to place the NOW divider
- `formatGap()` helper — formats gap minutes as "1h 30min free"
- `scrollToNow()` — scrolls the timeline to the NOW divider on load

#### Phase 3 — Condensed timeline list
- Tasks rendered as a flex list with a 52px time label column on the left
- Gap indicators between tasks when gap > 30 min ("1h 30min free")
- Red NOW divider inserted between past and future tasks; at the end when all tasks are done
- Empty state with calendar icon + "Your day is wide open."
- Old `.mobile-agenda` kept with `v-if="false"` (instant rollback if needed)

#### Phase 4 — Time-first scheduling
- `openScheduleAtHour(hour)` pre-fills the time and opens the task sheet
- `tapToScheduleFromSheet(activity)` wires sheet selection into the existing schedule modal
- `confirmSchedule` guards against empty `activityId`

#### Phase 5 — Task library bottom sheet
- Green `+` button opens a bottom sheet with search, filter chips, and task rows
- Sheet slides up with animation, backdrop tap closes it
- Tapping a task from the sheet pre-fills the activity and opens the schedule modal

#### Phase 6 — Cleanup
- Task library column (`col-card`) hidden on mobile via `display: none`
- `flex-direction: column-reverse` removed from `.daily-grid` on mobile
- VCard title hidden on mobile (`.agenda-card :deep(.v-card-title) { display: none }`) — date shown once in header only

#### Additional fixes during timeline work
- `width: 100%` added to `.tl-list` and `.tl-row` — cards now span full width on all days
- `.tl-now-divider` aligned to card left edge via `padding-left: calc(52px + 0.75rem)`
- `.tl-gap` aligned consistently with card column
- `task-sheet-fab` scoped entirely inside `@media (max-width: 768px)` to prevent desktop leak
- `nextTick` + `mobileTimelineRef` used to scroll to NOW divider after data loads

#### Bottom bar
- Unified fixed bottom bar replaces separate floating FABs
- Left: blue back button (`var(--primary)`, white icon, matching original FAB)
- Right: green `+` add button
- Completed bar restored as a separate section above the bar, scrollable horizontally on mobile
- Overlay `padding-bottom` accounts for bar height so completed bar is never hidden underneath

---

## What is still pending

### Other views not yet reviewed
- `DashboardView.vue` — main family hub (has uncommitted changes from before this session)
- `ActivitiesView.vue`
- `MarketplaceView.vue`
- `StatsView.vue`
- `ProfileView.vue`
- `LandingView.vue` — **brand register** surface, highest priority for acquisition

### Landing page (brand register)
Needs a full brand-register review with `/impeccable critique LandingView` or `/impeccable craft landing page`.

### DESIGN.md not created
Run `/impeccable document` to capture the current visual system so future impeccable commands stay on-brand automatically.

### DailyView — remaining opportunities
- **Day-swipe gesture** — navigating between days uses `<` / `>` buttons; swipe left/right is a likely user expectation
- **Bottom sheet modals** — Schedule and Delete modals would feel more native as bottom sheets rather than centered overlays
- **Old `.mobile-agenda` cleanup** — the `v-if="false"` block can be fully deleted once the timeline is confirmed stable on device

### DashboardView.vue has uncommitted changes
`git status` at session start showed `M frontend/src/views/DashboardView.vue`. Those changes were not touched.
