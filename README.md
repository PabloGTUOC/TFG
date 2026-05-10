# CareCoins: General Architecture & System Description

This document provides a comprehensive overview of the Vue frontend architecture, the Node.js Express backend API routes, and the PostgreSQL database schema.

---

## Part 1: Vue Frontend Components

### Core UI Components (`src/components/`)
These are reusable, low-level UI blocks designed to maintain visual consistency across the application.

*   **`KpiCard.vue`**
    Displays Key Performance Indicators (KPIs) in a styled card. It supports custom labels, numeric values, units, subtext, delta changes, and optional progress bars. It features various color accents (primary, success, warning, danger) and a responsive `compact` mode for mobile displays.
*   **`VButton.vue`**
    A customizable, styled button component supporting multiple variants (`primary`, `secondary`, `outline`, `danger`). It features hover micro-interactions, disabled states, and a `block` property to expand to full width.
*   **`VCard.vue`**
    A structural container component providing a modern glassmorphic background, consistent padding, rounded borders, and subtle shadow effects. It optionally accepts a `title` prop for a pre-styled header.
*   **`VInput.vue`**
    A wrapper for standard text inputs (`<input>`). It includes an integrated top label, placeholder text, and active/focus/disabled states. It natively handles two-way data binding via `v-model`.
*   **`VSelect.vue`**
    A styled wrapper for native HTML `<select>` dropdowns. It renders an array of `{ value, label }` options, includes a custom chevron icon, and integrates seamlessly with `v-model` for state management.

### Application Views (`src/views/`)
These are high-level page components connected to Vue Router, orchestrating the main features of the application.

*   **`App.vue` (Root Layout)**
    The top-level container for the application. It provides the main layout structure, including the responsive floating "Pill" navigation bar on desktop, a hamburger overlay menu for mobile, user avatar dropdowns, and global success/error notification banners.
*   **`DashboardView.vue` (Family Hub)**
    The central dashboard overview. It aggregates top-level information: active family members, care dependents (and their remaining CareCoin GDP), open task bounties, top KPIs, and a recent activity ledger. It also features a horizontal weekly calendar scroll to navigate to daily schedules and visualize absences.
*   **`DailyView.vue` (Daily Schedule)**
    A rich, interactive timeline for managing daily tasks. Users can drag-and-drop task templates from the "Task Library" onto a vertical 24-hour timeline. From here, users can schedule tasks, set up recurrences, offer coin "bounties" to delegate tasks, accept bounties, log absences, and validate completed work.
*   **`ActivitiesView.vue` (Admin & Budget Hub)**
    The template management center. Caregivers can define reusable task templates categorized into "Care" and "Household". They can configure titles, durations, recurrence, and coin values. It also visualizes the family's overall "Budget Health" with a custom SVG gauge showing remaining monthly coin pools.
*   **`MarketplaceView.vue` (Reward Store)**
    The family store where accumulated CareCoins can be spent. Caregivers can create custom rewards with specific costs, maximum use limits, and expiration dates. Members can browse available treats and instantly redeem them by deducting coins from their personal balance.
*   **`ProfileView.vue` (Personal Area)**
    A comprehensive account and family management page. It handles updating profile details, uploading avatars (for both users and dependents), adding new dependents, and inviting new caregivers via shareable URLs or QR codes. It also contains a detailed Monthly Ledger of coin transactions and handles complex actions like approving family deletion requests.
*   **`StatsView.vue` (Performance Analytics)**
    A data visualization dashboard powered by Apache ECharts. It visualizes lifetime family wealth, coin flow trends, category splits, completion rate leaderboards, and marketplace popularity. It includes a toggle switch to transition between aggregate family data and comparative individual caregiver stats.
*   **`OnboardingView.vue` (Setup Wizard)**
    The initial flow for new users. It allows users to create a brand new family (defining their alias, inviting caretakers, and setting up dependents) or process incoming invitations via token links to join an existing family.
*   **`JoinView.vue` (Invite Handler)**
    A dedicated landing page for processing invite links. It parses invite tokens from the URL, prompts the user for an optional alias, and automatically redirects them to authentication and onboarding flows before adding them to the family.
*   **`LoginView.vue` (Authentication)**
    The authentication gateway. Handles user sign-up and sign-in flows using standard email/password credentials as well as integrated Google OAuth logins.

---

## Part 2: Backend Architecture & Endpoints

The backend is an Express.js server providing a REST API, protected by Firebase Authentication and rate limiters. Data is stored in a PostgreSQL database managed via standard `pg` connection pools.

### Main Service Classes & Middleware
*   **`middleware/auth.js` (`requireAuth`)**: Secures endpoints by verifying Firebase ID tokens passed in the `Authorization` header. It injects the user's `uid` and `email` into the request object.
*   **`middleware/rbac.js` (`requireRole`)**: Role-Based Access Control middleware that verifies if a user has sufficient privileges (e.g., `admin`, `member`) within a specific family before allowing the request to proceed.
*   **`middleware/validate.js`**: Utility wrapper to validate request payloads (body or params) against Joi schemas.
*   **`db/pool.js`**: Core database connection wrapper that exports the PostgreSQL `Pool` instance.
*   **`db/check_act.js`, `db/check_care.js`, `db/check_valid.js`**: Reusable database utility modules for quickly validating task states, family memberships, and the existence of specific dependents (care objects) to enforce business logic cleanly.

### API Routes & Endpoints (`src/routes/`)

#### 1. Personal & Account Management (`/api/me`)
*   `GET /`: Retrieve the current user's profile information.
*   `PATCH /profile`: Update the user's display name, alias, and other profile details.
*   `POST /avatar`: Upload and set a new profile avatar image.
*   `GET /invites`: List all pending family invitations for the current user.
*   `GET /login-history`: Retrieve the user's historical login events.
*   `GET /ledger`: View detailed CareCoin transactions across all families.
*   `POST /login-event` / `POST /logout-event`: Register authentication events for auditing.
*   `DELETE /`: Delete the user's account entirely.

#### 2. Family Management (`/api/families`)
*   `GET /`: List all families the current user belongs to.
*   `POST /`: Create a new family hub.
*   `DELETE /:familyId`: Request the deletion of a family hub.
*   `GET /:familyId/budget`: Fetch high-level budget health for a family.
*   `GET /:familyId/members`: List all caregivers/members inside the family.
*   `PATCH /:familyId/members/:userId/role`: Modify a member's role (e.g., promote to admin).
*   `POST /:familyId/actors`: Add a new care dependent (child/elder).
*   `DELETE /:familyId/actors/:actorId`: Remove a care dependent.
*   `POST /:familyId/actors/:actorId/avatar`: Upload an avatar for a dependent.
*   `GET /:familyId/invitations` / `POST /:familyId/invitations`: View and send new email invitations.
*   `POST /join-request` / `POST /join-by-token` / `POST /:familyId/members/:userId/approve`: Handling flows for joining a family.
*   `GET /:familyId/deletion-requests` / `POST /.../approve` / `POST /.../reject`: Manage multi-user consensus for deleting a family.

#### 3. Task & Activity Engine (`/api/activities`)
*   `GET /`: Retrieve all available task templates for a family.
*   `POST /`: Create a new task template (Care or Household).
*   `DELETE /:id`: Remove a task template.
*   `POST /:activityId/approve`: Approve a pending task template creation.
*   `POST /:activityId/schedule`: Instantiate a task template onto the daily calendar timeline.
*   `POST /:activityId/recurrence`: Create a batch of future scheduled tasks based on recurrence rules.
*   `POST /:activityId/complete`: Mark a scheduled task as "done".
*   `POST /:id/validate`: Review and validate a completed task, triggering the coin payout.
*   `POST /:id/revert`: Un-check a task, removing it from validation pending status.
*   `POST /:id/bounty`: Add a CareCoin bounty to a task to encourage delegation.
*   `POST /:id/accept-bounty`: Accept a bounty, reassigning the task to the current user.

#### 4. Marketplace (`/api/marketplace`)
*   `GET /rewards/:familyId`: List all custom rewards available in the family store.
*   `POST /rewards`: Create a new custom reward (setting cost, limits, and expiration).
*   `POST /rewards/:rewardId/redeem`: Purchase a reward using accumulated CareCoins.

#### 5. Absences (`/api/absences`)
*   `GET /`: List logged absences for the family.
*   `POST /`: Log a new absence (time off / unavailability).
*   `DELETE /:id`: Remove a logged absence.

#### 6. Dashboard & Analytics
*   **`/api/dashboard`**
    *   `GET /:familyId`: Fetches aggregate data for the dashboard view (members, dependent GDP, top KPIs, recent activity log).
*   **`/api/stats`**
    *   `GET /:familyId`: Retrieves comprehensive JSON analytics for ECharts rendering (lifetime wealth, task completion rates, categorical breakdowns).

---

## Part 3: Database Schema & Relationships

The application uses PostgreSQL as its relational database. The schema is defined in `backend/src/db/schema.sql`.

### Key Tables

1. **`users`**: Core user accounts. Stores `firebase_uid`, `email`, and profile information.
2. **`families`**: The core tenant entity representing a family hub. It tracks the `monthly_coin_budget`.
3. **`family_members`**: A join table mapping users to families. It tracks the user's `role` (`caregiver` or `member`), specific `alias` within that family, and their active `coin_balance`.
4. **`family_invitations`**: Tracks pending email invitations to join a family.
5. **`actors`**: Represents dependents or objects of care (e.g., children, elders). Linked to a `family` and optionally a `user_id` if they have their own login.
6. **`activities`**: Represents both task templates and scheduled tasks. Includes start/end times, category, coin value, bounty amounts, and status. It connects to the creator, the assignee, and the approver.
7. **`coin_ledger`**: The immutable transaction history for CareCoins. Links a user, family, and optionally an activity to track the flow of coins.
8. **`marketplace_rewards`**: Custom rewards created by caregivers for their family members to redeem.
9. **`reward_redemptions`**: Logs when a user successfully redeems a marketplace reward.
10. **`absences`**: Logs periods of time when a user is unavailable or absent.
11. **`invite_links`**: Tracks shareable token links generated for a family to allow quick joining.
12. **`family_deletion_requests` & `family_deletion_approvals`**: Tables used to manage the multi-caregiver consensus required before permanently deleting a family hub.

### Core Relationships

*   **User to Family (Many-to-Many)**: A user can belong to multiple families, managed via the `family_members` table. Each membership tracks unique roles and coin balances.
*   **Family to its Entities (One-to-Many)**: The `families` table acts as the main partition key. `activities`, `actors`, `marketplace_rewards`, `absences`, and `coin_ledger` rows all directly reference a `family_id` to ensure strict multi-tenant isolation.
*   **Activity Associations**: An `activity` references multiple users: the `created_by` user, the `assigned_to` user (who completes it), the `approved_by` user (who validates it), and potentially a `bounty_offered_by` user.
*   **Financial Flow**: The `coin_ledger` enforces a double-entry-like record, linking `user_id` and `family_id` with an `amount` for every transaction.

---

## Part 4: Main User Flows (Activities)

The core functionality of CareCoins revolves around completing tasks (Care or Household activities) to earn CareCoins. Here is the typical lifecycle of an activity:

### 1. Template Creation & Approval
A user navigates to the **Activities Hub** to define a new "Task Template". They set the task's title, duration, category, and assign it a base CareCoin value. If the creator does not have Admin privileges, the template enters a "pending" state and must be approved by an Admin before it appears in the family's shared library.

### 2. Scheduling & Instantiation
From the **Daily Schedule** view, users can drag-and-drop an approved template from the Task Library directly onto the 24-hour vertical timeline. They can schedule a task as a one-off event or set up recurrence rules (e.g., "Every weekday at 8:00 AM"). This action instantiates a concrete task on the calendar.

### 3. Bounties & Delegation (Optional)
If a family member realizes they cannot complete a scheduled task, they can attach a "Bounty" to it. They offer extra CareCoins from their own balance to incentivize help. Another caregiver can see this open bounty on the Dashboard and accept it, transferring the responsibility of the task to themselves in exchange for the bonus coins.

### 4. Completion & Validation
Once the real-world task is done, the assigned user marks it as "Complete" on their Daily Schedule. The task enters a "Pending Validation" state. To ensure accountability, a *different* caregiver must review and click "Validate". Upon validation, the backend engine mints the CareCoins and logs a transaction in the `coin_ledger`, updating the user's active balance.

---

## Part 5: Testing & Local Environment

### How to Test the Application
To test the application, users do not need complex pre-configurations. Simply navigate to the application's login screen and:
1. **Create an account** using a standard Email and Password combination.
2. Alternatively, **use a Gmail account** via the Google OAuth integration for instant access.

Once authenticated, the app will intuitively guide you through an onboarding process to create a new family hub or join an existing one.

### System & VM Dependencies
If you are setting up the project in an isolated Virtual Machine (VM) or a fresh environment, you will need the following system-level and project-level dependencies installed:

**System Requirements**
*   **Node.js**: `v20.x` or higher (required by the backend engine).
*   **PostgreSQL**: `v12` or higher (for the database).
*   **npm**: Node package manager (comes bundled with Node.js).

**Backend Dependencies (Node.js)**
Navigating to `/backend` and running `npm install` will fetch:
*   `express` & `cors`: For the HTTP server and cross-origin resource sharing.
*   `dotenv`: For environment variable management.
*   `express-rate-limit`: For API request rate-limiting protection.
*   `firebase-admin`: For validating Firebase Auth tokens server-side.
*   `multer`: For handling multipart/form-data (avatar uploads).
*   `pg`: PostgreSQL client for Node.js.

**Frontend Dependencies (Vue 3)**
Navigating to `/frontend` and running `npm install` will fetch:
*   `vue` (v3.5+) & `vue-router` (v4.6+): Core frontend framework and routing.
*   `pinia`: Global state management.
*   `firebase`: Client-side authentication SDK.
*   `echarts` & `vue-echarts`: For rendering analytics and charts.
*   `lucide-vue-next`: Icon library.
*   `qrcode`: For generating shareable invite QR codes.
*   *Dev Tools*: `vite` (bundler), `vitest` (testing), `vite-plugin-pwa` (PWA support).

### Running the Application Locally

To launch the project locally, open two separate terminal windows—one for the backend and one for the frontend.

**1. Start the Backend API**
Navigate to the backend folder and start the development server (which includes live-reloading):
```bash
cd backend
npm install
npm run dev
```
*(To run in production mode without watch flags, you can use `npm start`)*

**2. Start the Frontend Client**
Navigate to the frontend folder and launch the Vite development server:
```bash
cd frontend
npm install
npm run dev
```

The frontend will be accessible locally, typically at `http://localhost:5173`. If you need to test the optimized production build locally, you can run:
```bash
npm run build
npm run preview
```

### Running with Docker

For a production-ready environment or simplified local deployment, CareCoins provides a complete containerized setup via `docker-compose.yml`.

To launch the entire application stack (PostgreSQL database, Node API, and NGINX frontend):
```bash
docker compose up --build -d
```

**Docker Architecture Summary:**
*   **`postgres` Service**: Runs `postgres:16`, binding port 5433 to 5432, and persists database files to a Docker volume (`pgdata`).
*   **`db-init` Service**: A transient container that builds the backend image specifically to execute the database initialization script (`npm run db:init`) once Postgres is ready.
*   **`backend` Service**: Runs the Node.js API on port 3000. It mounts a local volume (`./backend/uploads`) to ensure user avatar uploads persist across container restarts, and securely loads Firebase credentials via an `.env` file.
*   **`frontend` Service**: A multi-stage Docker build that compiles the Vue 3 frontend using Vite (injecting the `VITE_API_URL`) and serves the static production assets through a lightweight NGINX web server on port 80 (mapped to your host's port 5173).
