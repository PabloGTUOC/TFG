# Database Schema Reference

The schema uses PostgreSQL with the `uuid-ossp` extension loaded. Most tables use `BIGSERIAL` (numeric auto-increment) primary keys. Only three tables use UUIDs: `marketplace_rewards`, `reward_redemptions`, and `invite_links`.

---

## Table of Contents

1. [users](#1-users)
2. [families](#2-families)
3. [family_members](#3-family_members)
4. [family_invitations](#4-family_invitations)
5. [actors](#5-actors)
6. [activities](#6-activities)
7. [coin_ledger](#7-coin_ledger)
8. [login_history](#8-login_history)
9. [marketplace_rewards](#9-marketplace_rewards)
10. [reward_redemptions](#10-reward_redemptions)
11. [absences](#11-absences)
12. [invite_links](#12-invite_links)
13. [family_deletion_requests](#13-family_deletion_requests)
14. [family_deletion_approvals](#14-family_deletion_approvals)
15. [fcm_tokens](#15-fcm_tokens)
16. [notification_preferences](#16-notification_preferences)

---

## 1. `users`

Core identity table. Each row represents one registered user, linked to Firebase Authentication.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal numeric identifier |
| `firebase_uid` | TEXT | UNIQUE, NOT NULL | UID issued by Firebase Auth; used for all token verification |
| `email` | TEXT | UNIQUE | User's email address (may be null if provider does not supply it) |
| `display_name` | TEXT | — | Human-readable name shown in the UI |
| `avatar_url` | TEXT | — | URL to the user's profile picture |
| `is_deleted` | BOOLEAN | NOT NULL, DEFAULT false | Soft-delete flag; deleted users are hidden but their data is preserved |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Account creation timestamp |

**Logic notes:**
- Deletion is always soft (`is_deleted = true`), never a physical row removal, to preserve referential integrity across all other tables.
- `firebase_uid` is the join key between the Firebase token (JWT) and the internal user record.
- Child tables that reference `users(id)` (e.g. `family_members`, `actors`, `coin_ledger`) define their foreign keys with `ON DELETE CASCADE`. These constraints are never triggered by normal application flow — they exist as a safety net for direct database operations such as admin cleanup scripts or test teardown where a row might be hard-deleted outside the app.

---

## 2. `families`

Represents a family group. All shared data (activities, coins, rewards) belongs to a family.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal identifier |
| `name` | TEXT | NOT NULL | Display name of the family |
| `monthly_coin_budget` | INTEGER | NOT NULL, DEFAULT 1000, CHECK > 0 | Total CareCoins distributed to caregivers each month |
| `last_coin_distribution_month` | VARCHAR(7) | — | Last month coins were distributed, in `YYYY-MM` format; used to prevent double distribution |
| `created_by` | BIGINT | NOT NULL, FK → users(id) | User who created the family |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Creation timestamp |

**Logic notes:**
- `monthly_coin_budget` must be strictly positive (enforced by CHECK constraint).
- `last_coin_distribution_month` acts as an idempotency guard: the distribution job checks this value before issuing coins for the current month.

---

## 3. `family_members`

Junction table linking users to families with a role and a coin balance.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal identifier |
| `family_id` | BIGINT | NOT NULL, FK → families(id) ON DELETE CASCADE | Family this membership belongs to |
| `user_id` | BIGINT | NOT NULL, FK → users(id) ON DELETE CASCADE | User who is a member |
| `role` | TEXT | NOT NULL, CHECK IN ('caregiver', 'member') | Role within the family |
| `alias` | TEXT | — | Optional nickname shown instead of `display_name` within this family |
| `coin_balance` | INTEGER | NOT NULL, DEFAULT 0 | Current CareCoins balance for this user in this family |
| `status` | TEXT | NOT NULL, DEFAULT 'active', CHECK IN ('active', 'pending', 'inactive') | Membership lifecycle state |
| `joined_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When the user joined |
| _(unique)_ | — | UNIQUE (family_id, user_id) | A user can only have one membership per family |

**Logic notes:**
- `role = 'caregiver'` grants elevated permissions (create activities, approve tasks, manage rewards).
- `role = 'member'` is the dependent being cared for; they receive coins but do not manage the family.
- `status = 'pending'` is set when an invitation is accepted but before a caregiver confirms the join.
- Coin balance is stored here (denormalized) for fast reads; the authoritative source of truth for coin changes is `coin_ledger`.

---

## 4. `family_invitations`

Email-based invitations sent by caregivers to recruit new family members.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal identifier |
| `family_id` | BIGINT | NOT NULL, FK → families(id) ON DELETE CASCADE | Family the invitation is for |
| `email` | TEXT | NOT NULL | Recipient's email address |
| `name` | TEXT | — | Optional display name for the invitee |
| `role` | TEXT | NOT NULL, DEFAULT 'caregiver' | Role that will be assigned on acceptance |
| `invited_by` | BIGINT | NOT NULL, FK → users(id) | Caregiver who sent the invitation |
| `status` | TEXT | NOT NULL, DEFAULT 'pending', CHECK IN ('pending', 'accepted', 'declined') | Current state of the invitation |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When the invitation was created |
| _(unique)_ | — | UNIQUE (family_id, email) | Only one active invitation per email per family |

**Logic notes:**
- The unique constraint on `(family_id, email)` prevents duplicate invitations; a caregiver must decline/revoke an existing one before re-inviting the same address.
- When a user accepts, the application creates a `family_members` row and sets this status to `'accepted'`.

---

## 5. `actors`

Represents individuals tracked within a family. An actor can be a registered user or an unregistered person (e.g. an elderly relative without an account).

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal identifier |
| `family_id` | BIGINT | NOT NULL, FK → families(id) ON DELETE CASCADE | Family this actor belongs to |
| `user_id` | BIGINT | FK → users(id) ON DELETE CASCADE | Linked user account (nullable for unregistered actors) |
| `actor_type` | TEXT | NOT NULL, DEFAULT 'person' | Type of actor |
| `name` | TEXT | — | Display name (used when `user_id` is null) |
| `care_time` | TEXT | CHECK IN ('full_time', 'part_time') | Care intensity; relevant for scheduling and workload metrics |
| `avatar_url` | TEXT | — | Profile picture URL |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Creation timestamp |
| _(unique)_ | — | UNIQUE (family_id, user_id) | A registered user can only be one actor per family |

**Logic notes:**
- `user_id` is nullable to support actors who are not platform users (e.g. a patient being cared for).
- The unique constraint applies only when `user_id` is not null (PostgreSQL ignores NULLs in unique indexes).
- **Only actors with `actor_type = 'pet'` can be deleted.** Attempting to remove a child, elderly, or other actor type returns `403`. This is enforced at the service layer (`removeActor` in `memberService.js`).
- Removing a pet also decreases `families.monthly_coin_budget` by 720 (full-time) or 360 (part-time) — reversing the budget contribution that was added when the actor was created.

---

## 6. `activities`

The central entity of the application. Represents care or household tasks that can be assigned, completed, and rewarded with CareCoins.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal identifier |
| `family_id` | BIGINT | NOT NULL, FK → families(id) ON DELETE CASCADE | Family this activity belongs to |
| `created_by` | BIGINT | NOT NULL, FK → users(id) | User who created the activity |
| `assigned_to` | BIGINT | FK → users(id) | User assigned to perform the task (nullable = unassigned) |
| `title` | TEXT | NOT NULL | Short description of the task |
| `category` | TEXT | NOT NULL, CHECK IN ('care', 'household') | Whether this is a caregiving or domestic task |
| `starts_at` | TIMESTAMPTZ | — | Scheduled start time |
| `ends_at` | TIMESTAMPTZ | — | Scheduled end time |
| `duration_minutes` | INTEGER | NOT NULL, CHECK >= 15 | Expected duration; minimum 15 minutes |
| `coin_value` | INTEGER | NOT NULL, CHECK >= 0 | CareCoins awarded on completion |
| `status` | TEXT | NOT NULL, DEFAULT 'pending', CHECK IN ('pending', 'approved', 'rejected', 'completed', 'pending_validation') | Lifecycle state |
| `is_template` | BOOLEAN | NOT NULL, DEFAULT true | Whether this is a reusable template or a concrete instance |
| `is_recurrent` | BOOLEAN | NOT NULL, DEFAULT false | Whether the task repeats |
| `approved_by` | BIGINT | FK → users(id) | Caregiver who approved or rejected the activity |
| `approved_at` | TIMESTAMPTZ | — | Timestamp of the approval/rejection action |
| `bounty_amount` | INTEGER | NOT NULL, DEFAULT 0 | Additional coin bonus offered for completing this task |
| `bounty_offered_by` | BIGINT | FK → users(id) ON DELETE SET NULL | User who offered the bounty |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Creation timestamp |
| _(check)_ | — | CHECK (ends_at > starts_at) OR both NULL | End must be strictly after start if either is set |

**Status lifecycle:**
```
pending → approved → pending_validation → completed
        → rejected           ↑ revert ↓
                           approved
```

**Logic notes:**
- `duration_minutes >= 15` enforces a minimum meaningful task length.
- `coin_value >= 0` allows zero-coin tasks (chores done purely for contribution).
- The `ends_at > starts_at` check is relaxed when both are NULL (for templates with no scheduled time).
- `bounty_amount` is additive on top of `coin_value`; set to 0 when no bounty is active.
- Two indexes are defined: `(assigned_to, starts_at, ends_at)` for schedule queries and `(family_id, status)` for dashboard filters.

---

## 7. `coin_ledger`

Immutable transaction log for all CareCoins movements. Every credit or debit is recorded here.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal identifier |
| `family_id` | BIGINT | NOT NULL, FK → families(id) ON DELETE CASCADE | Family context |
| `user_id` | BIGINT | NOT NULL, FK → users(id) ON DELETE CASCADE | User whose balance changed |
| `activity_id` | BIGINT | FK → activities(id) ON DELETE SET NULL | Activity that triggered this entry (nullable for non-activity movements) |
| `amount` | INTEGER | NOT NULL | Coin delta; positive = credit, negative = debit |
| `reason` | TEXT | NOT NULL | Human-readable description of the transaction |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Transaction timestamp |

**Logic notes:**
- Rows are never updated or deleted (append-only ledger).
- `activity_id` is SET NULL on activity deletion so historical transactions are not lost.
- `family_members.coin_balance` is the denormalized running total; `coin_ledger` is the source of truth for auditing.

---

## 8. `login_history`

Session audit trail. Records every login and logout event per user.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal identifier |
| `user_id` | BIGINT | NOT NULL, FK → users(id) ON DELETE CASCADE | User this session belongs to |
| `login_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When the session started |
| `logout_at` | TIMESTAMPTZ | — | When the session ended (null = session still open) |
| `ip_address` | TEXT | — | Client IP address at login |
| `user_agent` | TEXT | — | HTTP User-Agent header at login |

**Logic notes:**
- A row is inserted on every successful authentication; `logout_at` is null until the user explicitly logs out.
- On logout, the application updates the most recent open session (`logout_at IS NULL`) for that user.
- Both `ip_address` and `user_agent` are captured only at login; they are not updated during the session.

---

## 9. `marketplace_rewards`

Rewards that family caregivers create and members can redeem with their CareCoins.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | UUID identifier |
| `family_id` | BIGINT | NOT NULL, FK → families(id) ON DELETE CASCADE | Family that owns this reward |
| `creator_id` | BIGINT | NOT NULL, FK → users(id) ON DELETE CASCADE | Caregiver who created it |
| `title` | TEXT | NOT NULL | Name of the reward |
| `description` | TEXT | — | Optional detailed description |
| `cost` | INTEGER | NOT NULL, CHECK > 0 | CareCoins required to redeem |
| `max_uses` | INTEGER | — | Maximum total redemptions allowed (null = unlimited) |
| `valid_from` | TIMESTAMPTZ | — | Start of the validity window (null = immediately available) |
| `valid_until` | TIMESTAMPTZ | — | End of the validity window (null = no expiry) |
| `status` | TEXT | NOT NULL, DEFAULT 'active', CHECK IN ('active', 'archived') | Whether the reward is currently available |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Last modification timestamp |

**Logic notes:**
- `cost > 0` ensures a reward always has a non-zero price.
- `max_uses` is enforced at the application layer by counting rows in `reward_redemptions` before allowing a new redemption.
- Rewards are never hard-deleted; they are archived (`status = 'archived'`) to preserve redemption history.
- An index is defined on `(family_id, status)` for fast marketplace listing.

---

## 10. `reward_redemptions`

Records each time a user redeems a marketplace reward.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | UUID identifier |
| `reward_id` | UUID | NOT NULL, FK → marketplace_rewards(id) ON DELETE CASCADE | Reward that was redeemed |
| `user_id` | BIGINT | NOT NULL, FK → users(id) ON DELETE CASCADE | User who redeemed it |
| `family_id` | BIGINT | NOT NULL, FK → families(id) ON DELETE CASCADE | Family context (denormalized for query efficiency) |
| `redeemed_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When the redemption occurred |

**Logic notes:**
- `family_id` is denormalized here (it could be derived via `reward_id → marketplace_rewards → family_id`) to avoid a join on every redemption query.
- The corresponding coin debit is written to `coin_ledger` as part of the same transaction.

---

## 11. `absences`

Records periods when a user is unavailable (holiday, sick leave, etc.), used to avoid scheduling conflicts.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal identifier |
| `family_id` | BIGINT | NOT NULL, FK → families(id) ON DELETE CASCADE | Family context |
| `user_id` | BIGINT | NOT NULL, FK → users(id) ON DELETE CASCADE | User who is absent |
| `start_time` | TIMESTAMPTZ | NOT NULL | Start of the absence |
| `end_time` | TIMESTAMPTZ | NOT NULL | End of the absence |
| `title` | TEXT | NOT NULL | Label for the absence (e.g. "Vacation", "Doctor") |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Creation timestamp |
| _(check)_ | — | CHECK (end_time > start_time) | End must be strictly after start |

**Logic notes:**
- The `CHECK (end_time > start_time)` constraint prevents zero-length or inverted absences at the database level.
- An index on `(family_id, start_time, end_time)` supports efficient overlap queries for scheduling.

---

## 12. `invite_links`

Shareable one-click invitation links that allow anyone with the URL to join a family.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | UUID used as the link token |
| `family_id` | BIGINT | NOT NULL, FK → families(id) ON DELETE CASCADE | Family being joined |
| `created_by` | BIGINT | NOT NULL, FK → users(id) | Caregiver who generated the link |
| `max_uses` | INTEGER | — | Maximum number of times the link can be used (null = unlimited) |
| `uses` | INTEGER | NOT NULL, DEFAULT 0 | How many times the link has been used so far |
| `expires_at` | TIMESTAMPTZ | — | Expiry timestamp (null = never expires) |
| `revoked` | BOOLEAN | NOT NULL, DEFAULT false | If true, the link is immediately invalidated |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Creation timestamp |

**Logic notes:**
- The UUID primary key serves double duty as the unguessable token embedded in the invite URL.
- The application validates three conditions before accepting a link: `revoked = false`, `expires_at > NOW()` (if set), and `uses < max_uses` (if set).
- `uses` is incremented atomically on each successful join.
- An index on `family_id` supports listing all active links for a given family.

---

## 13. `family_deletion_requests`

Initiated when a caregiver requests that the entire family be deleted. Requires consent from all caregivers.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal identifier |
| `family_id` | BIGINT | NOT NULL, FK → families(id) ON DELETE CASCADE | Family targeted for deletion |
| `requested_by` | BIGINT | NOT NULL, FK → users(id) ON DELETE CASCADE | Caregiver who initiated the request |
| `status` | TEXT | NOT NULL, DEFAULT 'pending', CHECK IN ('pending', 'approved', 'rejected') | Outcome of the multi-step approval process |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When the request was created |

**Logic notes:**
- A request moves to `'approved'` only after all caregivers have submitted an `'approved'` entry in `family_deletion_approvals`.
- If any caregiver rejects, the request moves to `'rejected'` and no deletion occurs.

---

## 14. `family_deletion_approvals`

Tracks each caregiver's individual vote on a family deletion request.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal identifier |
| `request_id` | BIGINT | NOT NULL, FK → family_deletion_requests(id) ON DELETE CASCADE | The deletion request being voted on |
| `caregiver_id` | BIGINT | NOT NULL, FK → users(id) ON DELETE CASCADE | Caregiver casting the vote |
| `status` | TEXT | NOT NULL, DEFAULT 'pending', CHECK IN ('pending', 'approved', 'rejected') | This caregiver's vote |
| `responded_at` | TIMESTAMPTZ | — | When the vote was cast (null = not yet voted) |
| _(unique)_ | — | UNIQUE (request_id, caregiver_id) | Each caregiver can only vote once per request |

**Logic notes:**
- One row is created per caregiver (with `status = 'pending'`) when a deletion request is opened.
- The unique constraint on `(request_id, caregiver_id)` prevents duplicate votes.
- After every vote update, the application re-evaluates the parent `family_deletion_requests.status`.

---

## 15. `fcm_tokens`

Stores Firebase Cloud Messaging device tokens for push notification delivery.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PRIMARY KEY | Internal identifier |
| `user_id` | BIGINT | NOT NULL, FK → users(id) ON DELETE CASCADE | User this token belongs to |
| `token` | TEXT | NOT NULL, UNIQUE | FCM registration token for a specific device/browser |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When the token was registered |

**Logic notes:**
- A user can have multiple tokens (one per device/browser).
- Tokens are upserted via `POST /api/me/fcm-token` — if the same token is re-registered it is a no-op.
- After each FCM send, tokens reported as invalid or unregistered by Firebase are pruned automatically.
- An index on `user_id` supports fast lookup of all tokens for a given user.

---

## 16. `notification_preferences`

Per-user opt-in/opt-out settings for each push notification category.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `user_id` | BIGINT | PRIMARY KEY, FK → users(id) ON DELETE CASCADE | User these preferences belong to |
| `activity_assigned` | BOOLEAN | NOT NULL, DEFAULT true | Receive notifications when an activity is assigned or scheduled |
| `activity_validated` | BOOLEAN | NOT NULL, DEFAULT true | Receive notifications when a completed activity is validated |
| `activity_completed` | BOOLEAN | NOT NULL, DEFAULT true | Receive notifications when any family member completes an activity |
| `bounty_offered` | BOOLEAN | NOT NULL, DEFAULT true | Receive notifications when a bounty is offered on an activity |
| `family_events` | BOOLEAN | NOT NULL, DEFAULT true | Receive notifications for family-level events (member joined, deletion requested) |

**Logic notes:**
- One row per user (primary key = `user_id`). The row is created/replaced atomically via `PUT /api/me/notification-preferences`.
- Before sending a push notification, `notify.js` LEFT JOINs this table and skips users where the relevant column is `false`.
- All categories default to `true`, so users who have never visited the preferences screen receive all notifications.

---

## Indexes Summary

| Index | Table | Columns | Purpose |
|---|---|---|---|
| `idx_activities_assignee_period` | `activities` | `(assigned_to, starts_at, ends_at)` | Schedule queries for a specific assignee |
| `idx_activities_family_status` | `activities` | `(family_id, status)` | Dashboard and kanban filters |
| `idx_marketplace_family_status` | `marketplace_rewards` | `(family_id, status)` | Active reward listing per family |
| `idx_absences_family_period` | `absences` | `(family_id, start_time, end_time)` | Overlap detection for scheduling |
| `idx_invite_links_family` | `invite_links` | `(family_id)` | List all links for a family |
| `idx_fcm_tokens_user_id` | `fcm_tokens` | `(user_id)` | Fetch all device tokens for a user before sending push notifications |
