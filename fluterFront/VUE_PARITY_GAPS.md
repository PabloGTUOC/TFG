# Vue → Flutter parity gaps

Audit date: 2026-07-06 (after the Daily-parity + Family Circle + charts batch).
Method: full re-scan of `frontend/src` (views, components, composables) against `fluterFront/lib`.

## ⚡ Progress update — 2026-07-06 (parity batch 2)

Closed since the audit below was written (tables NOT updated in place):

- **§1 Daily desktop** — hour-grid timeline, drag & drop from Task Library
  panel, drag-out unschedule, now-line + auto-scroll, gap indicators. ✅
- **§2 Dashboard** — week pagination + label, absences in strip, Log Time
  Off, Recent Activity feed, full KPI row, clickable offers, Stats nav. ✅
- **§3 Activities** — 3 tabs, budget economics (bounded slider), approve
  flow, isRecurrent, 30-min duration select, Budget gauge tab. ✅
- **§4 Marketplace** — validFrom/validUntil on create, expiry badge,
  history rows fixed to real backend fields (buyer_name/redeemed_at). ✅
- **§5 Stats** — all 10 panels + compare-caregivers toggle + KPI row +
  Overview/Members/Economy tabs. ✅
- **§6 Personal Area** — profile tabs, full AccountSettings (name/email/
  alias via PATCH), delete account, deletion-requests banner, delete
  family, notification-preference toggles, ledger reason labels +
  un-check revert + preview/full toggle, insights card. ✅
- **§7 Onboarding** — full create wizard (caretakers + objects of care),
  alias prompt on invite accept, token extraction from pasted links. ✅
- **§8 Shell** — refetch on app resume (AppLifecycleListener). ✅

Still open:

- Avatar images/upload everywhere (needs `image_picker` + backend
  multipart upload; Flutter still renders initials).
- Push notifications (blocked on `firebase login` → `flutterfire configure`).
- `/join?token=…` deep links + URL routing (`go_router` + app links).
- Marketing landing page (login remains the Flutter entry screen).
- End-to-end testing against the real backend (all of batch 2 is
  analyzer/build-verified but not yet exercised in the running app).

Legend: ✅ ported · ⚠️ partial / simplified · ❌ missing

---

## 1. Daily view (`DailyView.vue` + `useTimeline` / `TaskLibrary` / `DailyModals`)

| Feature | Vue | Flutter | Notes |
|---|---|---|---|
| Hour-grid timeline (6:00–24:00, 19 labelled hour lines) | positioned chips, height ∝ duration, overlap offsetting (`useTimeline.js`) | ❌ | Flutter renders a flat sorted list with a time label column |
| **Drag & drop scheduling** | drag template → drop on timeline slot (30-min snapping) → prefilled schedule modal | ❌ | biggest visible gap on desktop/tablet; Flutter equivalent: `Draggable`/`DragTarget` |
| Drag scheduled chip **out** of timeline to unschedule | ✅ (`dropOut`, single/series modal for recurring) | ❌ | |
| Red "now" line + auto-scroll to current time | `nowLineTop`, `scrollToNow()` | ❌ | |
| Task Library **sidebar** on desktop (search, filters, grouped care/household, drag source) | ✅ | ⚠️ | Flutter only has the mobile-style bottom sheet behind the FAB |
| Day progress bar | "X / Y done · 🪙 Zcc" (coins earned that day, `todayCoins`) | ⚠️ | progress + count ported; coins-earned-today figure missing |
| Date/week indicator | "Wednesday, Jul 6" long format + ESC-to-close overlay over dashboard | ⚠️ | Flutter shows "Wed, Jul 6" in an app bar (pushed screen instead of overlay — acceptable divergence, but the long weekday label is nicer) |
| Schedule modal with explicit hour/minute selects (06–23:30) | ✅ | ⚠️ | Flutter uses the system time picker (fine, but no 6:00–23:30 clamping) |
| Log absence | ✅ button in header + modal (also from Dashboard) | ✅ ported (✈️ app-bar icon) | Vue label "+ Log Time Off" is more discoverable than the icon |
| Absence banners + detail/remove | ✅ | ✅ | |
| Bounty: delegate / take over / offering chip / assigned chip | ✅ | ✅ | same role/assignee decision tree |
| Recurrence "Schedule Future Copies" (daily/weekdays/weekly + until) | ✅ | ✅ | |
| Single vs series delete for recurring | ✅ | ✅ | |
| Day-swipe, swipe-to-delete | ✅ (touch) | ✅ (+ trash affordance Vue lacks) | |
| Time-gap indicators between mobile cards (`formatGap`: "2h 30min") | ✅ | ❌ | |
| Tap empty state to open task sheet | ✅ | ✅ | |

## 2. Dashboard (`DashboardView.vue`)

| Feature | Vue | Flutter | Notes |
|---|---|---|---|
| **Week pagination** (`«` / `»`, `currentWeekOffset`, week label "Jul 6 – Jul 12") | ✅ | ❌ | Flutter is locked to the current week |
| **Absences in the week strip** (✈️ day marker, red absence chips per day, `day-col--absence` tint) | ✅ | ❌ | Flutter dashboard never loads `/api/absences` |
| "+ Log Time Off" from the dashboard | ✅ | ❌ | only on Daily in Flutter |
| **Recent Activity feed** (merged completed tasks + claimed rewards, relative timestamps, highlighted names) | ✅ | ❌ | |
| KPI parity | Family Balance · Tasks Today (+"N awaiting validation") · **Open Bounties (+total cc up for grabs)** · Recent Activity count | ⚠️ | Flutter has Family coins / Tasks today / Members; missing Open Bounties + Recent Activity KPIs |
| Offer cards clickable → navigate to that day's Daily | ✅ | ❌ | Flutter offers are display-only |
| Today summary card → navigates to Stats | ✅ | ❌ | |
| Member cards, pending approvals, chips w/ status colours + bounty badge | ✅ | ✅ | |
| Day column tap → Daily | ✅ | ✅ | |

## 3. Activities (`ActivitiesView.vue`)

| Feature | Vue | Flutter | Notes |
|---|---|---|---|
| **Three tabs: Catalogue / New Activity / Budget** | ✅ | ❌ | Flutter is a single scroll page with filter chips |
| **Budget integration** (`GET /api/families/{fid}/budget`): suggested coins = hours × `baseRatePerHour`; slider bounded min = 0.5×, max = 1.5× of suggestion | ✅ | ❌ | Flutter uses a hardcoded 1–100 slider and a `(duration/15)*5` heuristic — wrong economics |
| **Template approval flow**: created templates are `pending`, caregiver **Approve** button (`POST /activities/{id}/approve`), approved/pending badges | ✅ | ❌ | Flutter create says "Activity created!" but it lands pending and can't be approved from Flutter |
| `isRecurrent` checkbox on creation | ✅ | ❌ | |
| Duration as 30-min-step select up to 12 h | ✅ | ⚠️ | Flutter slider 15–180 min |
| Budget tab (family budget display) | ✅ | ❌ | |
| Catalogue list + category filter + delete w/ confirm | ✅ | ✅ | |

## 4. Marketplace (`MarketplaceView.vue`)

| Feature | Vue | Flutter | Notes |
|---|---|---|---|
| Create: `validFrom` / `validUntil` dates | ✅ | ❌ | payload supports them; form lacks the two date fields |
| `valid_until` expiry badge on reward cards | ✅ | ❌ | Flutter only shows uses-left/sold-out |
| History row detail (who redeemed, when) | ✅ | ⚠️ | Flutter guesses response field names — verify against backend once testing starts |
| Store grid, banner colour by id hash (5 variants), redeem, uses/max badge, Create tab caregiver-only | ✅ | ✅ | |

## 5. Stats (`StatsView.vue` — ECharts)

Vue renders **10 chart panels**; Flutter currently has 5 equivalents.

| Vue panel | Flutter | Notes |
|---|---|---|
| Income Generation Trend (+ **"Compare caregivers" toggle** → per-caregiver multi-line) | ⚠️ | total-only line ported; compare toggle missing |
| Coin Flow by Reason (stacked bars) | ✅ | |
| Coin Balance Leaderboard | ✅ (bar rows) | |
| Completion Rate | ✅ (bar rows) | |
| Activity Status Distribution (pie) | ⚠️ | ported as count chips, not a pie |
| **Category Balance** (care vs household per caregiver) | ❌ | `categorySplit` data unused |
| **Task Frequency** | ❌ | |
| **Bounties — Offered vs Earned vs Refunded** (`bountyStats`) | ❌ | |
| **Rewards Claimed by Member** | ❌ | |
| **Most Popular Rewards** | ❌ | |

## 6. Personal Area (`ProfileView.vue` + `AccountSettings` / `WalletPanel` / `FamilyCircle`)

| Feature | Vue | Flutter | Notes |
|---|---|---|---|
| Mobile tab bar (My Profile / Family / Wallet) | ✅ | ❌ | Flutter stacks everything in one scroll |
| **AccountSettings**: full name, email, per-family alias, avatar upload | ✅ | ⚠️ | Flutter has display name only |
| **Delete account** | ✅ | ❌ | |
| **Notification preferences** (enable/disable push + 5 per-event toggles, `GET/PUT /api/me/notification-preferences`) | ✅ | ❌ | pairs with the FCM work |
| **Deletion requests banner** (approve/deny `POST /families/{fid}/deletion-requests/{id}/{action}`) | ✅ | ❌ | |
| **Delete family** (starts deletion-request flow) | ✅ | ❌ | |
| Wallet: ledger **reason labels** (`activity_reverted`, `bounty_earned`… humanised) | ✅ | ⚠️ | Flutter shows raw title/reason |
| Wallet: **"un-check" revert** on activity ledger rows (`POST /activities/{id}/revert` + confirm, strikethrough on reverted rows) | ✅ | ❌ | |
| Wallet: preview (3 rows) vs full-ledger toggle | ✅ | ⚠️ | Flutter always shows the full month list |
| Family banner, month picker, balance widget | ✅ | ✅ | |
| Family Circle: roster, add/remove dependents, email invites, invite link + QR | ✅ | ✅ | |
| Family Circle: **actor avatar upload**, type/care-time via VSelect | ✅ | ⚠️ | dropdowns ported; avatar upload missing |

## 7. Onboarding & Join (`OnboardingView.vue`, `JoinView.vue`)

| Feature | Vue | Flutter | Notes |
|---|---|---|---|
| Create wizard: main caretaker name/email (prefilled), **additional caretakers list** (dynamic rows → invitations), **objects of care list** (name/type/care-time) | ✅ | ❌ | Flutter sends empty `caretakers`/`objectsOfCare` arrays |
| Accept invite with alias prompt | ✅ | ⚠️ | Flutter accepts without asking alias |
| Pending-request notice | ✅ | ✅ | |
| Join by token | ✅ | ✅ | |
| `/join?token=…` **deep link** (QR scans land here) | ✅ | ❌ | Flutter has no URL routing; QR links open the Vue web app — fine while Vue is primary, needs app-links for native |

## 8. Global / app shell

| Feature | Vue | Flutter | Notes |
|---|---|---|---|
| **Avatar images** (user + actor `avatar_url` served by backend) | ✅ | ❌ | Flutter renders initials everywhere |
| **Push notifications** (FCM token registration, foreground `Notification`, badge clearing) | ✅ | ❌ | blocked on `flutterfire configure` |
| Refetch on tab visibility change | ✅ | ⚠️ | Flutter has pull-to-refresh instead; add `AppLifecycleListener` refetch |
| **Marketing landing page** (`LandingView.vue`, 1185 lines) | ✅ | ❌ | Login is the Flutter entry screen |
| URL routing / web history (`/dashboard`, `/daily/:date`…) | ✅ | ❌ | Flutter uses stateful navigation; consider `go_router` before web deployment matters |
| Toasts, auth guards, coin counter, bottom tabs / pill header | ✅ | ✅ | |

---

## Suggested order of attack

1. **Daily desktop experience** — hour-grid timeline with positioned chips, now-line, drag & drop from a Task Library side panel, drop-out to unschedule. (The single biggest "feels missing" area.)
2. **Dashboard completeness** — week pagination + label, absences in the strip, log-time-off, clickable offers, Recent Activity feed, missing KPIs.
3. **Activities economics** — budget endpoint, bounded coin slider, approve-template flow, isRecurrent, tabs.
4. **Personal Area depth** — notification prefs (with FCM), delete account/family + deletion requests, ledger revert + reason labels, avatar uploads (needs `image_picker`).
5. **Stats remaining charts** + compare-caregivers toggle.
6. **Onboarding wizard depth** + `/join` deep links (`go_router` + app links).
7. Marketplace validity dates, landing page, visibility-refetch.
