# Mobile Usability — Suggested Improvements

Scope: frontend only (`frontend/src`). The database and backend business logic are out of scope.
Findings come from a review of the Vue views, shared components, composables, global CSS, and the PWA/viewport setup, focused on the `@media (max-width: 768px)` experience.

The app already has a solid mobile foundation (bottom tab bar, tab-based layouts per view, bottom sheets and swipe gestures on the Daily view, 16px inputs in `VInput`/`VSelect`, `prefers-reduced-motion` support). The items below are the gaps that remain, ordered by impact.

---

## Critical

### 1. There is no way to log out on mobile
The only logout control is the avatar dropdown in the header (`App.vue:101`), and that whole block is `desktop-only`, so it is hidden at ≤768px. The bottom tab bar has no equivalent, and the Personal Area only offers "Delete account".

- **Fix:** add a Logout action to the Personal Area (`ProfileView.vue` / `AccountSettings.vue`), and/or make the mobile coin counter or avatar open a small menu with Logout.

### 2. Safe-area insets never apply: `viewport-fit=cover` is missing
`index.html:5` declares `width=device-width, initial-scale=1.0` without `viewport-fit=cover`. Every `env(safe-area-inset-bottom)` used in the bottom tab bar (`App.vue:453`), the Daily bottom bar, FABs, bottom sheets, and toasts therefore resolves to `0` on notched iPhones — the tab bar sits under the home-indicator area in the installed PWA.

- **Fix:** change the meta tag to `content="width=device-width, initial-scale=1.0, viewport-fit=cover"`.
- **Related:** with `apple-mobile-web-app-status-bar-style` set to `black-translucent` (`index.html:8`), the app draws under the iOS status bar in standalone mode, but nothing pads the top. Add `padding-top: env(safe-area-inset-top)` to the sticky pill header / `.app-layout`.

---

## High

### 3. Several touch targets are well below the 44×44px minimum
`VButton` correctly enforces `min-height: 44px`, but many raw `<button>`s don't:

| Control | Size | Location |
|---|---|---|
| Day prev/next arrows | 32px | `DailyView.vue` `.date-nav-btn` |
| Week pagination `«` `»` | 36px | `DashboardView.vue` `.pagination-btn` |
| Card remove button | 28px | `DailyView.vue` `.mobile-remove-btn` |
| Remove-pet button | 24px | `FamilyCircle.vue` `.remove-actor-btn` |
| Validate / Delegate / Take Over chips | ~26px tall | Daily timeline cards |
| "Un-check" ledger button | ~20px tall | `WalletPanel.vue` `.uncheck-btn` |
| Category filter tabs | ~24px tall | `ActivitiesView.vue` `.filter-btn` |
| Task-sheet close (X) | ~26px | `DailyView.vue` task sheet header |

- **Fix:** give these a 44px minimum hit area (padding or a transparent `::before` overlay) even if the visual stays small.

### 4. Swipe-to-delete is destructive with no undo and no affordance
On the mobile Daily timeline, swiping a card 80px left (`useCardSwipe.js:42`) immediately unschedules a non-recurring activity (`DailyView.vue` `removeMobile`) — no confirmation, no undo. While swiping, only the row background tints red; no trash icon is revealed, so users can't predict what the gesture does, and accidental swipes silently delete tasks.

- **Fix:** reveal a delete icon/label behind the card during the swipe, and show an "Activity removed — Undo" toast for ~5s after dismissal (or require a second tap on the revealed delete button, iOS-Mail style).
- **Also:** provide a non-gesture fallback (e.g. long-press menu or an edit mode) — swipe is currently the *only* way to remove a scheduled task on mobile.

### 5. Remaining sub-16px inputs trigger iOS auto-zoom
`VInput`/`VSelect` are fixed at 16px, but several ad-hoc inputs are smaller, which makes iOS Safari zoom the page when they receive focus (and it doesn't zoom back out):

- `FamilyCircle.vue` `.text-input` — 0.95rem (15.2px)
- Task-sheet search input in `DailyView.vue` — 0.9rem
- `WalletPanel.vue` `.month-picker` — 0.85rem

- **Fix:** set `font-size: 16px` on every input/select/textarea, or add a global rule for `@media (max-width: 768px)`.

### 6. `100vh` should be `100dvh`/`100svh`
`body`, `.app-layout`, and `.loading-screen` use `min-height: 100vh`. On mobile Safari/Chrome, `100vh` includes the collapsed URL bar, causing content to be cut off or produce a phantom scroll.

- **Fix:** `min-height: 100dvh` (with a `100vh` fallback line above it for older browsers). Same for `.col-card`'s `calc(100vh - 4rem)` in `DailyView.vue`.

---

## Medium

### 7. Unify the mobile modal pattern (bottom sheets vs. centered dialogs)
On mobile, the Schedule and Delete modals become bottom sheets (`bs-overlay` in `DailyModals.vue`), but Recurrence, Bounty, Accept-Bounty, Absence, the Marketplace redeem confirmation, the Activities delete confirmation, and both Dashboard modals stay as centered dialogs. The inconsistency makes the app feel less polished and centered dialogs interact worse with the keyboard.

- **Fix:** extract one `BottomSheet`/`VModal` component (handle bar, slide-up animation, safe-area padding, `@click.self` close) and use it everywhere on mobile.
- **Also:** background content still scrolls behind open overlays — lock `body` scroll (`overflow: hidden` or `position: fixed`) while any modal/sheet is open.

### 8. Gesture discoverability on the Daily view
Horizontal day-swipe (`useDaySwipe.js`) and card swipe-to-delete are invisible features — nothing hints they exist, and they compete for the same horizontal gesture (mitigated by `cancelDaySwipe`, but the first ~8px of a card swipe is ambiguous).

- **Fix:** a one-time coach-mark/hint ("Swipe to change day · swipe a card left to remove"), and/or subtle edge chevrons next to the date. Consider raising the card-swipe activation threshold slightly (8px is very sensitive on high-DPI screens).

### 9. Dashboard week strip: no snap, no "today" auto-scroll, no scroll hint
`.week-scroll` forces a 700px-wide row behind `overflow-x: auto`. On a phone the user sees Mon–Wed and has no cue that more days exist; if today is Sunday it's off-screen on load.

- **Fix:** add `scroll-snap-type: x mandatory` (+ `scroll-snap-align` on day columns), auto-scroll today's column into view on mount (`scrollIntoView({ inline: 'center' })`), and add an edge fade or partial-column peek to signal scrollability.

### 10. Toast notifications
Success/error toasts are fixed to the bottom-right above the tab bar. On phones long messages can cover the Daily view's add/back buttons, they can't be dismissed by tap (only the 3.5s/5s timer), and they lack `role="status"`/`aria-live` so screen readers never announce them.

- **Fix:** full-width (with margins) toast above the tab bar or below the header, dismiss on tap, `role="status"` for success and `role="alert"` for errors.

### 11. Coin-value slider (Activities → New Activity)
- The Min/Suggested/Max labels use `color: rgba(255,255,255,0.4)` (`ActivitiesView.vue:185`) — near-invisible white text on the light card, so on mobile users have no idea what the slider bounds are.
- The 16px slider thumb is hard to grab with a thumb; bump to ~24–28px on touch, or supplement with −/+ stepper buttons.

### 12. Data freshness / pull-to-refresh
Views fetch once on mount/param change. A phone that stays on the Dashboard shows stale balances until navigation; the browser's native pull-to-refresh does a full app reload instead.

- **Fix:** refetch on `visibilitychange → visible` (the handler already exists in `App.vue` for badges) and/or add a lightweight pull-to-refresh on Dashboard/Daily/Marketplace.

---

## Lower priority / polish

### 13. Bundle size on mobile networks
All routes are imported eagerly in `router/index.js`, so ECharts (Stats-only, the heaviest dependency), `qrcode`, and the 1,100-line Landing page all ship in the first paint bundle. Switch route components to dynamic imports (`component: () => import('../views/StatsView.vue')`) so the login/dashboard path loads fast on 4G.

### 14. Font weights are synthesized
Google Fonts loads Plus Jakarta Sans 500/700/800 (`index.html:13`), but the CSS uses 600 and 900 in several places (`font-weight: 900` on balances/titles, 600 on labels). Browsers fake these, which renders blurry on mobile. Load the missing weights or normalize usage to 500/700/800.

### 15. Charts on small screens
ECharts tooltips are hover-oriented; on touch, add `tooltip: { confine: true }` so they don't clip off-screen, and consider a shorter fixed height plus larger axis label font in the 481–768px range (currently 380px applies until 480px).

### 16. Sticky `:hover` effects on touch devices
Hover transforms (member cards, reward cards `translateY(-4px)`, buy buttons, `li:hover` in global CSS) stick after a tap on touch screens. Wrap hover-only effects in `@media (hover: hover) and (pointer: fine)`.

### 17. Small-text legibility on the Dashboard week chips
Activity chips inside day columns use 9–10px text with 10px meta. Below ~11px, text is illegible for many users on a phone held at arm's length. Since columns are tappable anyway, consider showing only a count + first title at ≥11px, with details on the Daily view.

### 18. Accessibility touches
- Add `aria-label` to icon-only buttons that lack one (day prev/next arrows, week `«`/`»`, filter/close buttons); the FABs and tab links already have labels — extend the pattern.
- Add `aria-current="page"` to active bottom-tab links and `aria-selected` semantics to the Store/History/Create-style tab bars (they are plain buttons today).
- The Stats "Compare caregivers" toggle is a bare checkbox+span; wire `role="switch"`/`aria-checked`.

### 19. Landing page CTA on mobile
The marketing landing already has breakpoints, but review the hero on ≤480px so the primary "get started" action is visible without scrolling — it's the first mobile impression of the app.

---

## Suggested implementation order

1. **Quick wins (< 1 day):** #2 viewport meta, #5 input font sizes, #6 `dvh`, #11 slider label color, #14 font weights.
2. **Critical UX (1–2 days):** #1 mobile logout, #3 touch-target pass, #10 toast rework.
3. **Behavioral (2–4 days):** #4 swipe undo + affordance, #7 unified bottom sheet, #9 week-strip snapping, #8 gesture hints.
4. **Ongoing polish:** #12, #13, #15–#19.
