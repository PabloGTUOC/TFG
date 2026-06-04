# Product — CareCoins

> Note: the landing page (`LandingView.vue`) operates as a **brand** surface — design IS the product there for acquisition. All other views (DailyView, DashboardView, ActivitiesView, etc.) are **product** surfaces — design SERVES the caregiving workflow. Apply brand-register thinking to landing; product-register thinking to app views.

---

## Users

Family caregivers — parents, partners, grandparents — coordinating the daily logistics of a household with children or dependents. They use the app in brief, high-stress moments: morning routines, handoffs between caregivers, end-of-day review. Mobile is the primary device for quick task actions; desktop is where planning and scheduling happen.

Secondary users: dependents (elderly relatives, young adults) who receive and complete tasks but do not manage the family.

---

## Product Purpose

CareCoins helps families share caregiving and household work fairly, using a coin reward system to make contributions visible and valued. It removes the invisible labour problem — the person who always does everything finally has a record, and the person who should do more has an incentive. Success looks like a family that ends the day feeling like a team, not a scoreboard.

---

## Brand Personality

Loving, trusted, fun. Warm without being saccharine. Confident without being clinical. The app should feel like a well-organised family friend, not a productivity tool or a social network.

---

## Anti-references

- **Facebook / Instagram**: No algorithmic feeds, no engagement-bait UI, no like/follower counts, no notification badges designed to create anxiety, no infinite scroll. The app should feel finite and completable — you open it, do your thing, close it.
- No cold corporate SaaS (no navy + white + grey, no hero metrics, no enterprise dashboard aesthetic).
- No gamification-first (coins are a tool for fairness, not the point — avoid leaderboard-trophy-streak culture that makes it feel like a game rather than a home).

---

## Design Principles

1. **Finite and completable** — every screen should have a clear "done" state. The day view has an end. The task list empties. Users should feel accomplishment, not the pull of an infinite feed.
2. **Warmth through substance** — warmth is expressed through voice, spacing, and thoughtful defaults, not cream backgrounds or decorative illustrations that soften the truth.
3. **Fairness is the feature** — the coin system only works if the UI makes contribution transparent and legible. Visual hierarchy should always surface who did what, when.
4. **Mobile is the primary action surface** — quick actions (mark done, validate, delegate) happen on phone. Design for thumb reach and glanceability first.
5. **Family-scale, not enterprise-scale** — this is 2–6 people who know each other. Personalization (aliases, avatars, member colours) matters more than scalability abstractions.

---

## Accessibility & Inclusion

- Target WCAG AA as a minimum for all text (4.5:1 body, 3:1 large text).
- Reduced motion support required — many users open this in low-attention moments.
- Touch targets minimum 44×44px on all interactive elements (mobile-first).
- Colour is used as an enhancement, never the sole indicator of status (all status chips must include text or icon alongside colour).

---

## Feature Set

### 1. Authentication

Users authenticate with **email/password** or **Google Sign-In** via Firebase Authentication. The auth state is persisted in indexedDB (production) or localStorage (emulator/testing). On first login the backend performs an upsert to create or retrieve the internal user record linked to the Firebase UID. Session events (login / logout with IP and user agent) are recorded in the `login_history` table.

### 2. Onboarding & Family Setup

New users land on the onboarding flow where they:
- Create a family with a name.
- Set up their own caregiver profile (display name, alias).
- Optionally add initial caregivers or objects of care (actors).

A family can have **multiple caregivers** and **multiple members** (dependents). Each family has a monthly CareCoins budget (default 1 000 coins) that is distributed to caregivers once per month.

### 3. Joining a Family

There are two ways to join an existing family:
- **Email invitation**: a caregiver sends an invite to an email address; the recipient registers or logs in and the invitation is matched by email address, creating a pending membership that a caregiver must approve.
- **Invite link**: a caregiver generates a one-click shareable URL (UUID token) with optional expiry and max-use limit. Anyone with the link can join directly without a caregiver approval step.

### 4. Daily Schedule View

The signature product view. Displays all activities for a selected day on a vertical time-line. Key features:
- Time-labelled rows with per-assignee colour coding (MEMBER_THEMES palette).
- **NOW divider** — a red horizontal rule showing the current time within the schedule.
- **Gap indicators** — free-time blocks shown between activities when the gap exceeds 30 minutes.
- **Day swipe navigation** — swipe or tap arrows to move between days.
- **Complete and revert** — activities can be marked done and undone without leaving the view.
- **Bounty banner** — activities with an active bounty show the bonus coin amount prominently.

### 5. Activities / Task Library

A kanban-style view of all activities in the family, grouped by status. Lifecycle:

```
pending → approved → pending_validation → completed
                   → rejected
```

Features:
- **Create activity**: title, category (care/household), duration (min 15 min), coin value, optional recurrence.
- **Approve / reject**: caregivers review newly created activities.
- **Schedule**: assign a start time to an approved activity, turning it into a concrete instance.
- **Recurrence**: generate repeated instances from a template (daily, weekdays, weekly) up to a given end date.
- **Complete**: mark an instance done; triggers a validation request to caregivers.
- **Validate**: caregiver confirms completion; coins are credited to the assignee's balance and recorded in the ledger.
- **Bounty**: a caregiver can attach a bonus coin amount to any activity to incentivise someone else to take it.
- **Accept bounty**: another family member takes over an activity with an active bounty, receiving the extra coins on completion.
- **Delete**: deletes a single instance or the full recurrence series.
- **Revert**: undo a completion before it is validated.

### 6. Dashboard

A summary view showing:
- Coin balances for all family members.
- Activity counts by status (pending, completed, upcoming).
- Recent activity feed with per-member attribution.
- KPI cards for caregiving hours and task distribution.

### 7. Marketplace

Caregivers create **rewards** that members can redeem with their CareCoins. Features:
- Rewards have a title, description, coin cost (must be > 0), optional max uses, and optional validity window.
- Members browse active, in-window, non-sold-out rewards and redeem them atomically (coin deduction + redemption record in a single transaction).
- Redemption history is visible to all family members.
- Rewards can be archived (never hard-deleted) to preserve history.

### 8. Statistics

Charts and summaries of caregiving activity over time:
- Coin distribution over months.
- Hours contributed per member per category (care vs household).
- Activity completion rates.
- Ledger view: itemised coin credits/debits for a selected month.

### 9. Absences

Caregivers can record absence periods (holiday, sick leave, appointment) for any member. Absences are visible on the schedule and used to avoid assigning activities to unavailable members. The `end_time > start_time` constraint is enforced at the database level.

### 10. Profile & Account

Each user can:
- Upload a profile avatar (JPEG / PNG / WebP, max 2 MB).
- Edit display name and email.
- Set a per-family alias (shown instead of display name within that family).
- View their last 20 login events (IP address, user agent, timestamps).
- Manage push notification preferences (5 categories: activity assigned, activity validated, activity completed, bounty offered, family events).
- Register / deregister FCM push tokens.
- Delete their account (soft-delete: data is anonymised, Firebase account is removed, future activities are cancelled).

### 11. Family Management

Caregivers can:
- Invite members by email.
- Approve pending join requests.
- Change member roles (caregiver ↔ member).
- Add and remove actors (non-user entities such as elderly relatives or pets).
- Upload actor avatars.
- Request family deletion — requires unanimous approval from all caregivers before the family record is removed.

### 12. Push Notifications

Real-time web push via **Firebase Cloud Messaging**. Notifications are sent server-side (Node.js Admin SDK) in response to product events. Users can opt out per-category. Stale tokens (unregistered or invalid) are automatically pruned after a failed send attempt. The service worker handles background (app-closed) notifications and deep-links the user to the relevant view on tap.

**Notification events:**
| Event | Recipients |
|---|---|
| New activity pending approval | All family caregivers |
| Activity scheduled | Assigned user |
| Activity needs past-time validation | All family caregivers |
| Activity completed | All family members |
| Activity validated (coins awarded) | Assignee |
| Bounty offered | All family members |
| New member joined | All family caregivers |
| Family deletion requested | All family caregivers |

### 13. Progressive Web App (PWA)

CareCoins is installable as a PWA on iOS (Add to Home Screen) and Android (install prompt). Features:
- `manifest.webmanifest` with name, icons (192 × 192, 512 × 512), standalone display mode, and brand colours.
- Service worker via **Workbox** (auto-update mode) for offline asset caching.
- Separate `firebase-messaging-sw.js` service worker for background push notifications.
- App badge API support (clears on notification tap).

---

## Technical Overview (summary)

| Layer | Technology |
|---|---|
| Frontend | Vue 3 + Vite, Pinia, Vue Router |
| Backend | Node.js 20, Express 4 |
| Database | PostgreSQL 16 |
| Auth | Firebase Authentication |
| Push | Firebase Cloud Messaging |
| Email | Resend |
| Container | Docker Compose (nginx + node + postgres) |
| Testing | Vitest (unit), Playwright (E2E) |

See `docs/frontend.md` and `docs/backend.md` for detailed technical documentation.
