# Graph Report - .  (2026-06-12)

## Corpus Check
- 99 files · ~78,058 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 440 nodes · 627 edges · 47 communities (34 shown, 13 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 36 edges (avg confidence: 0.91)
- Token cost: 18,500 input · 6,200 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Backend Core & DB Layer|Backend Core & DB Layer]]
- [[_COMMUNITY_DailyView UI Components|DailyView UI Components]]
- [[_COMMUNITY_Docker & Architecture Docs|Docker & Architecture Docs]]
- [[_COMMUNITY_Frontend Dependencies|Frontend Dependencies]]
- [[_COMMUNITY_Default Activities Data|Default Activities Data]]
- [[_COMMUNITY_Frontend Composables & Router|Frontend Composables & Router]]
- [[_COMMUNITY_Backend Dependencies|Backend Dependencies]]
- [[_COMMUNITY_Profile View Components|Profile View Components]]
- [[_COMMUNITY_RBAC & Background Jobs|RBAC & Background Jobs]]
- [[_COMMUNITY_Design System|Design System]]
- [[_COMMUNITY_E2E Global Test Setup|E2E Global Test Setup]]
- [[_COMMUNITY_Push Notification Utils|Push Notification Utils]]
- [[_COMMUNITY_Timeline Composable|Timeline Composable]]
- [[_COMMUNITY_Frontend Auth & Pinia Docs|Frontend Auth & Pinia Docs]]
- [[_COMMUNITY_Wallet Panel|Wallet Panel]]
- [[_COMMUNITY_DailyView Deletion Actions|DailyView Deletion Actions]]
- [[_COMMUNITY_Status Constants|Status Constants]]
- [[_COMMUNITY_Vite Build Config|Vite Build Config]]
- [[_COMMUNITY_Playwright Config|Playwright Config]]
- [[_COMMUNITY_Firebase Messaging SW|Firebase Messaging SW]]
- [[_COMMUNITY_Server Entry Point|Server Entry Point]]
- [[_COMMUNITY_Backend Rate Limiting|Backend Rate Limiting]]
- [[_COMMUNITY_Backend Tech Stack Docs|Backend Tech Stack Docs]]
- [[_COMMUNITY_Frontend Tech Stack Docs|Frontend Tech Stack Docs]]
- [[_COMMUNITY_Onboarding Feature Docs|Onboarding Feature Docs]]
- [[_COMMUNITY_Target Users Docs|Target Users Docs]]
- [[_COMMUNITY_Favicon Asset|Favicon Asset]]
- [[_COMMUNITY_Brand Mark Asset|Brand Mark Asset]]

## God Nodes (most connected - your core abstractions)
1. `assertActiveMember()` - 15 edges
2. `upsertUserFromAuth()` - 10 edges
3. `Express.js REST API Backend` - 10 edges
4. `withTransaction()` - 9 edges
5. `scripts` - 9 edges
6. `activities table` - 9 edges
7. `useAuthStore` - 8 edges
8. `CareCoins Design System` - 8 edges
9. `users table` - 8 edges
10. `globalSetup()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `PWA Icon 192x192 (icon-192.png)` --references--> `PWA — Two Service Workers`  [INFERRED]
  frontend/public/icon-192.png → docs/frontend.md
- `PWA Icon 512x512 (icon-512.png)` --references--> `PWA — Two Service Workers`  [INFERRED]
  frontend/public/icon-512.png → docs/frontend.md
- `getFirebaseMessaging()` --calls--> `getMessaging()`  [INFERRED]
  frontend/src/firebase.js → backend/src/utils/notify.js
- `Running Instructions` --references--> `Docker Compose Deployment`  [INFERRED]
  docs/running-instructions.txt → README.md
- `CareCoins Coin Reward System` --semantically_similar_to--> `coin_ledger table`  [INFERRED] [semantically similar]
  docs/PRODUCT.md → docs/database-schema.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Activity Lifecycle Flow** — docs_backend_activity_service, docs_schema_activities_table, docs_schema_coin_ledger_table, docs_backend_autocomplete, readme_activity_lifecycle [INFERRED 0.85]
- **Push Notification Pipeline** — docs_backend_notify, docs_schema_fcm_tokens_table, docs_schema_notification_prefs_table, docs_frontend_pwa, readme_push_notifications [INFERRED 0.85]
- **Docker Service Dependency Chain** — docker_compose_postgres_service, docker_compose_db_init_service, docker_compose_backend_service, docker_compose_frontend_service [EXTRACTED 1.00]

## Communities (47 total, 13 thin omitted)

### Community 0 - "Backend Core & DB Layer"
Cohesion: 0.07
Nodes (48): pool, withTransaction(), assertActiveMember(), upsertUserFromAuth(), logLoginHistory(), deleteFirebaseUser(), getFirebaseApp(), requireAuth() (+40 more)

### Community 1 - "DailyView UI Components"
Cohesion: 0.03
Nodes (35): absenceForm, absences, absencesToday, acceptBountyTarget, bountyForm, deleteTarget, familyActivities, familyMembers (+27 more)

### Community 2 - "Docker & Architecture Docs"
Cohesion: 0.07
Nodes (52): backend Docker Service, db-init Docker Service, frontend Docker Service, postgres Docker Service, activityService.js, requireAuth — Firebase Token Middleware, runAutoCompleteSweep Background Job, Database Layer — pool + withTransaction (+44 more)

### Community 3 - "Frontend Dependencies"
Cohesion: 0.06
Nodes (30): dependencies, echarts, firebase, lucide-vue-next, pinia, qrcode, vue, vue-echarts (+22 more)

### Community 4 - "Default Activities Data"
Cohesion: 0.09
Nodes (15): CHILD_ACTIVITIES, GENERIC_CARE_ACTIVITIES, HOUSEHOLD_ACTIVITIES, insertDefaultActivities(), PET_ACTIVITIES, approveDeletion(), createFamily(), deleteFamily() (+7 more)

### Community 5 - "Frontend Composables & Router"
Cohesion: 0.13
Nodes (9): useCurrentFamily(), useNotifications(), router, app, firebaseConfig, getFirebaseMessaging(), app, useAuthStore (+1 more)

### Community 6 - "Backend Dependencies"
Cohesion: 0.08
Nodes (24): dependencies, cors, dotenv, express, express-rate-limit, firebase-admin, multer, pg (+16 more)

### Community 7 - "Profile View Components"
Cohesion: 0.09
Nodes (18): accountSettingsRef, activeTab, actors, confirmBody, confirmDanger, confirmTitle, currentMonth, deleteAccount() (+10 more)

### Community 8 - "RBAC & Background Jobs"
Cohesion: 0.16
Nodes (13): runAutoCompleteSweep(), assertMemberRole(), meetsRole(), acceptBounty(), approveActivity(), completeActivity(), createActivity(), deleteActivity() (+5 more)

### Community 9 - "Design System"
Cohesion: 0.12
Nodes (19): Operations Colour Palette, Daily Timeline Signature Component, Flat-by-Default Elevation, Flat-by-Default Elevation Rule, One Job Rule (semantic colour), PWA Design Considerations, CareCoins Design System, Plus Jakarta Sans Typography System (+11 more)

### Community 10 - "E2E Global Test Setup"
Cohesion: 0.33
Nodes (8): apiPost(), bootstrapUser(), clearEmulatorUsers(), getIdToken(), globalSetup(), saveAuthState(), seedAll(), signUpUser()

### Community 11 - "Push Notification Utils"
Cohesion: 0.50
Nodes (8): getMessaging(), notifyFamilyAll(), notifyFamilyCaregivers(), notifyUser(), prefClause(), pruneStale(), sendToTokens(), VALID_PREF_KEYS

### Community 12 - "Timeline Composable"
Cohesion: 0.43
Nodes (3): formatGap(), getCardStyle(), useTimeline()

### Community 13 - "Frontend Auth & Pinia Docs"
Cohesion: 0.40
Nodes (4): Frontend Authentication Flow, Pinia State Management, Vue Router + Navigation Guards, Feature: Authentication

### Community 15 - "DailyView Deletion Actions"
Cohesion: 0.40
Nodes (5): confirmDeleteSeries(), confirmDeleteSingle(), dropOut(), removeMobile(), unSchedule()

## Knowledge Gaps
- **155 isolated node(s):** `name`, `version`, `description`, `main`, `type` (+150 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `getMessaging()` connect `Push Notification Utils` to `Frontend Composables & Router`?**
  _High betweenness centrality (0.151) - this node is a cross-community bridge._
- **Why does `getFirebaseMessaging()` connect `Frontend Composables & Router` to `Push Notification Utils`?**
  _High betweenness centrality (0.151) - this node is a cross-community bridge._
- **What connects `name`, `version`, `description` to the rest of the system?**
  _161 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Backend Core & DB Layer` be split into smaller, more focused modules?**
  _Cohesion score 0.07372229760289462 - nodes in this community are weakly interconnected._
- **Should `DailyView UI Components` be split into smaller, more focused modules?**
  _Cohesion score 0.03333333333333333 - nodes in this community are weakly interconnected._
- **Should `Docker & Architecture Docs` be split into smaller, more focused modules?**
  _Cohesion score 0.06561085972850679 - nodes in this community are weakly interconnected._
- **Should `Frontend Dependencies` be split into smaller, more focused modules?**
  _Cohesion score 0.06451612903225806 - nodes in this community are weakly interconnected._