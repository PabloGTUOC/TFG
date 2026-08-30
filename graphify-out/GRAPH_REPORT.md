# Graph Report - TFG  (2026-08-30)

## Corpus Check
- 199 files · ~172,854 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1760 nodes · 2756 edges · 119 communities (81 shown, 38 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 45 edges (avg confidence: 0.86)
- Token cost: 398,154 input · 0 output

## Community Hubs (Navigation)
- Backend Bootstrap & Scripts
- Daily Screen Internals
- Daily & Dashboard Data
- Design System UI Kit
- Admin & Profile Screens
- App State & Auth Flow
- Onboarding Wizard
- Personal Time Dialog
- Retention & Heartbeat Services
- Localization Tests
- Default Activity Seeding
- SQL Migrations
- Landing Screen
- Activities Screen
- Theme Tokens & Colors
- Stats Screen
- Marketplace Screen
- Admin Screen Tabs
- Backend Dependencies
- Timeline & Card Widgets
- Absence & Distribution Services
- App Shell & Navigation
- Chart Painters
- Personal Time Service
- Coach Marks Tour
- Family Circle Widget
- App Entry & Auth Gate
- Activity & Ledger Services
- API Client
- Activation Checklist
- iOS Runner Host
- Personal Time Design Docs
- Starter Pack Data
- Admin Screen State
- Purchase Service
- Subscription Card
- Absence Dialog
- Documentation Hub
- Tour Service
- Daily Timeline & Vue Legacy
- Flutter Port Docs
- Login Screen
- Billing Service
- Family & Member Services
- Push Service (Flutter)
- Legal Links
- Third-Party Integrations
- Billing Provider Boundary
- Test Coverage & API Surface
- Web App Manifest
- Admin Privacy & Retention
- Push Notification Backend
- Avatar Upload
- Deploy Script
- Activity RBAC & Locking
- Firebase Options
- Telemetry Client
- Express Middleware Chain
- Personal Time Data Model
- Onboarding Help Layers
- ARB Plural Tests
- P0 Release Blockers
- P1 Mobile UX Issues
- Task Action Routes
- JSON Helpers
- Docker Compose Stack
- Entitlement Merge
- Service Worker Architecture
- Running Instructions
- Onboarding Telemetry
- Design Principles
- Android Runner Host
- Family Row Navigation
- Absence API
- Marketplace Tables
- Database Reset Flag
- Daily Screen State
- Task Sheet
- Cover Request Card
- Dashboard Screen State
- Onboarding Screen State
- Stats Screen State
- Personal Time Sheet
- Firebase Messaging SW
- Email Annotation
- Audit Middleware
- Distribution Service
- Email Sender
- Events Router
- Marketplace Router
- Stats Router
- Validation Middleware
- Absences Table
- Invite Links Table
- Login History Table
- Activities Screen File
- Dashboard Screen File
- Landing Screen File
- Login Screen File
- Marketplace Screen File
- Profile Screen File
- Stats Screen File
- Tour Service File
- Retired Dashboard View
- Retired Landing View
- Retired Profile View
- Retired Family Composable
- Retired Card Component
- RevenueCat Paywall
- Notification Prefs Table

## God Nodes (most connected - your core abstractions)
1. `AppState` - 112 edges
2. `users` - 30 edges
3. `Activity Subclasses, Personal Time & Coverage — Plan (rev 3)` - 24 edges
4. `assertActiveMember()` - 22 edges
5. `families` - 21 edges
6. `Personal Time & Coverage — handoff` - 17 edges
7. `withTransaction()` - 15 edges
8. `CareCoins Architecture & System Description` - 15 edges
9. `upsertUserFromAuth()` - 14 edges
10. `createRequest()` - 13 edges

## Surprising Connections (you probably didn't know these)
- `Subscription terms (MyCareCoins Pro, auto-renewal)` --references--> `Platform Admin & Subscriptions Plan`  [INFERRED]
  fluterFront/web/terms.html → docs/admin-family-management-plan.md
- `frontend service (Flutter web + nginx)` --conceptually_related_to--> `Flutter Frontend Technical Reference`  [INFERRED]
  docker-compose.yml → docs/flutter-frontend.md
- `npm run dev:test cannot send push, fails silently` --semantically_similar_to--> `Local full-stack setup (Postgres + Firebase Auth Emulator)`  [INFERRED] [semantically similar]
  docs/personal-time-handoff.md → fluterFront/HANDOFF.md
- `CareCoins Architecture & System Description` --references--> `Family Setup Questionnaire Plan`  [EXTRACTED]
  README.md → docs/family-setup-questionnaire-plan.md
- `RevenueCat purchases_flutter/purchases_ui_flutter dependency (mobile-only)` --references--> `Platform Admin & Subscriptions Plan`  [EXTRACTED]
  fluterFront/pubspec.yaml → docs/admin-family-management-plan.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Backend Service Layer Pattern** — docs_backend_activityservice, docs_backend_familyservice, docs_backend_memberservice, docs_backend_adminservice, docs_backend_entitlementservice, docs_backend_billingservice, docs_backend_retentionservice, docs_backend_absenceservice, docs_backend_personaltimeservice, docs_backend_distributionservice [EXTRACTED 1.00]
- **Entitlement Merge Flow (Plan, Subscription, Grants)** — docs_database_schema_plans, docs_database_schema_family_plans, docs_database_schema_admin_grants, docs_backend_entitlementservice, docs_admin_family_management_plan_entitlement_merge [EXTRACTED 1.00]
- **Admin Privacy Boundary Enforcement** — docs_database_schema_users, docs_database_schema_admin_audit_log, docs_backend_adminservice, docs_backend_rbac, docs_admin_family_management_plan_privacy_boundary [EXTRACTED 1.00]
- **Documents citing the Vue frontend retirement (commit 7132e6a)** — docs_onboarding_help_plan, fluterfront_readme, fluterfront_vue_parity_gaps, fluterfront_handoff, docs_running_instructions [EXTRACTED 1.00]
- **Personal time & coverage feature documentation set** — docs_personal_time_handoff, docs_personal_time_plan, fluterfront_mobile_audit [INFERRED 0.85]
- **App store compliance & subscription documents** — fluterfront_web_privacy, fluterfront_web_terms, fluterfront_pubspec [INFERRED 0.80]

## Communities (119 total, 38 thin omitted)

### Community 0 - "Backend Bootstrap & Scripts"
Cohesion: 0.05
Nodes (71): __dirname, __filename, adminLimiter, ALLOWED_ORIGINS, app, __dirname, __filename, perUserLimiter (+63 more)

### Community 1 - "Daily Screen Internals"
Cohesion: 0.03
Nodes (74): _absenceDetail, _absences, _acceptBounty, _activities, _activityEmoji, build, _buildChip, _buildDismissibleCard (+66 more)

### Community 2 - "Daily & Dashboard Data"
Cohesion: 0.03
Nodes (71): daily_screen.dart, a, abs, _absences, _absencesOn, active, _activities, actor (+63 more)

### Community 3 - "Design System UI Kit"
Cohesion: 0.03
Nodes (59): EdgeInsetsGeometry, accent, actionLabel, autofillHints, background, behavior, block, body (+51 more)

### Community 4 - "Admin & Profile Screens"
Cohesion: 0.05
Nodes (56): admin_screen.dart, build, active, _alias, amount, balance, build, _buildAccountCard (+48 more)

### Community 5 - "App State & Auth Flow"
Cohesion: 0.04
Nodes (50): dart:ui, dynamic get, actors, _afterSignIn, api, _authMessage, authReady, clearMessages (+42 more)

### Community 6 - "Onboarding Wizard"
Cohesion: 0.04
Nodes (50): ../data/starter_packs.dart, _acceptInvite, _alias, _areaIcons, _areas, build, _buildCreateWizard, _CareObjectEntry (+42 more)

### Community 7 - "Personal Time Dialog"
Cohesion: 0.04
Nodes (47): DateTime get, _balance, _baseline, build, _candidates, _conflicts, _coverageNeeded, _coverName (+39 more)

### Community 8 - "Retention & Heartbeat Services"
Cohesion: 0.08
Nodes (28): main(), clearHeartbeatThrottle(), familyHeartbeat(), lastTouch, touchFamilyHeartbeat(), createGrant(), createPlan(), getFamilyBilling() (+20 more)

### Community 9 - "Localization Tests"
Cohesion: 0.07
Nodes (35): AppLocalizations, _app, main, minAbsence, main, boundApp, main, main (+27 more)

### Community 10 - "Default Activity Seeding"
Cohesion: 0.08
Nodes (26): CHILD_ACTIVITIES, GENERIC_CARE_ACTIVITIES, HOUSEHOLD_ACTIVITIES, insertDefaultActivities(), insertStarterTasks(), PET_ACTIVITIES, STARTER_TYPES, validateStarterTasks() (+18 more)

### Community 11 - "SQL Migrations"
Cohesion: 0.11
Nodes (34): family_deletion_approvals, family_deletion_requests, fcm_tokens, notification_preferences, onboarding_events, personal_time_requests, admin_grants, billing_events (+26 more)

### Community 12 - "Landing Screen"
Cohesion: 0.05
Nodes (39): double?, accent, active, background, build, _buildHero, _check, child (+31 more)

### Community 13 - "Activities Screen"
Cohesion: 0.05
Nodes (38): dart:math, active, _activities, ActivitiesScreen, _ActivitiesScreenState, _approve, _budget, build (+30 more)

### Community 14 - "Theme Tokens & Colors"
Cohesion: 0.05
Nodes (38): accentGradient, accents, accentSecondary, AppColors, AppRadii, base, bg, border (+30 more)

### Community 15 - "Stats Screen"
Cohesion: 0.05
Nodes (37): bool get, active, _BarRow, build, _buildCategoryBalance, _buildEconomy, _buildMembers, _buildOverview (+29 more)

### Community 16 - "Marketplace Screen"
Cohesion: 0.06
Nodes (34): DateTime, active, banner, _bannerColors, _buildCreate, _buildHistory, _buildStore, _claimed (+26 more)

### Community 17 - "Admin Screen Tabs"
Cohesion: 0.06
Nodes (34): _billing, build, createState, d, dispose, _editPlan, _error, _eventsCard (+26 more)

### Community 18 - "Backend Dependencies"
Cohesion: 0.06
Nodes (33): dependencies, cors, dotenv, express, express-rate-limit, firebase-admin, multer, pg (+25 more)

### Community 19 - "Timeline & Card Widgets"
Cohesion: 0.06
Nodes (34): _ActivityAction, _TimelineCard, _AbsenceChip, _ActChip, _DayColumn, _DayHeader, _DayRow, _MemberCard (+26 more)

### Community 20 - "Absence & Distribution Services"
Cohesion: 0.08
Nodes (25): MIN_ABSENCE_HOURS, validateAbsenceWindow(), distributionShares(), nextMonth(), presentHours(), runMonthlyDistribution(), settleMonth(), base (+17 more)

### Community 21 - "App Shell & Navigation"
Cohesion: 0.06
Nodes (31): activities_screen.dart, AppLifecycleListener, dashboard_screen.dart, active, build, createState, dispose, _go (+23 more)

### Community 22 - "Chart Painters"
Cohesion: 0.07
Nodes (31): Color, CustomPainter, _GaugePainter, _FamilyFiguresPainter, build, color, DonutChart, _DonutPainter (+23 more)

### Community 23 - "Personal Time Service"
Cohesion: 0.15
Nodes (25): acceptRequest(), activeCaregivers(), baseRateFor(), cancelRequest(), conflictsFor(), createRequest(), declineRequest(), endOfDay() (+17 more)

### Community 24 - "Coach Marks Tour"
Cohesion: 0.07
Nodes (30): CoachMark get, _advance, body, build, CoachMark, _CoachOverlay, _CoachOverlayState, createState (+22 more)

### Community 25 - "Family Circle Widget"
Cohesion: 0.08
Nodes (26): _addActor, badge, build, _CircleCard, _copyLink, createState, FamilyCircle, _FamilyCircleState (+18 more)

### Community 26 - "App Entry & Auth Gate"
Cohesion: 0.09
Nodes (24): firebase_options.dart, _appTheme, _AuthGate, _AuthGateState, build, CareCoinsApp, child, createState (+16 more)

### Community 27 - "Activity & Ledger Services"
Cohesion: 0.16
Nodes (15): runAutoCompleteSweep(), ACTIVITY, COVERAGE, payoutReasons(), assertMemberRole(), acceptBounty(), approveActivity(), completeActivity() (+7 more)

### Community 28 - "API Client"
Cohesion: 0.09
Nodes (22): dart:async, Exception, apiBase, ApiClient, ApiErrorKind, ApiException, delete, _headers (+14 more)

### Community 29 - "Activation Checklist"
Cohesion: 0.10
Nodes (19): ActivationChecklist, build, ChecklistStep, done, label, onDismiss, onGo, steps (+11 more)

### Community 30 - "iOS Runner Host"
Cohesion: 0.11
Nodes (14): Any, Bool, AppDelegate, SceneDelegate, RunnerTests, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge (+6 more)

### Community 31 - "Personal Time Design Docs"
Cohesion: 0.15
Nodes (19): npm run dev:test cannot send push, fails silently, Activity Subclasses, Personal Time & Coverage — Plan (rev 3), Absence primitive, Activity class model: category/type subclassing, Activity primitive (care|household), Bounty primitive, Never surface declined counts (social pressure risk), Subclass-aware overlap matrix (care/coverage/self) (+11 more)

### Community 32 - "Starter Pack Data"
Cohesion: 0.11
Nodes (17): areas, areasForDependents, durationMinutes, isRecurrent, kUniversalAreas, StarterArea, starterAreaLabel, starterEntries (+9 more)

### Community 33 - "Admin Screen State"
Cohesion: 0.16
Nodes (18): AdminFamilyDetailScreen, _AdminFamilyDetailScreenState, AdminScreen, _AdminScreenState, _FamiliesTab, _FamiliesTabState, _PlansTab, _PlansTabState (+10 more)

### Community 34 - "Purchase Service"
Cohesion: 0.11
Nodes (17): _androidKey, _configured, _ensureConfigured, entitlementId, hasProLocally, _iosKey, logOut, presentCustomerCenter (+9 more)

### Community 35 - "Subscription Card"
Cohesion: 0.12
Nodes (17): build, _busy, createState, _ent, _familyId, initState, _load, _loading (+9 more)

### Community 36 - "Absence Dialog"
Cohesion: 0.12
Nodes (15): @visibleForTesting, absenceWindowFromRange, anchor, app, confirmed, firstDate, l, lastDate (+7 more)

### Community 37 - "Documentation Hub"
Cohesion: 0.36
Nodes (15): CareCoins Docker Compose Stack, Platform Admin & Subscriptions Plan, Automated Test Suite Doc, Backend Technical Reference, Database Schema Reference, Deployment and Delivery Runbook, CareCoins Design System, theme/app_theme.dart (+7 more)

### Community 38 - "Tour Service"
Cohesion: 0.14
Nodes (13): ChangeNotifier, hasSeen, I, _key, markSeen, resetTabTours, shouldShow, suppressAll (+5 more)

### Community 39 - "Daily Timeline & Vue Legacy"
Cohesion: 0.16
Nodes (14): Daily Timeline (Signature Component), daily_screen.dart, widgets/ui.dart (Design-System Kit), DailyModals.vue (retired), DailyView.vue (retired), TaskLibrary.vue (retired), useCardSwipe.js (retired), useDaySwipe.js (retired) (+6 more)

### Community 40 - "Flutter Port Docs"
Cohesion: 0.20
Nodes (14): Onboarding & In-App Help Plan, Handoff — Flutter mobile bring-up, Ordered bring-up task list (Android/iOS/second-account/prod gates), iOS LaunchImage assets readme (default Flutter boilerplate), Flutter frontend mobile audit, P2 — polish, accessibility, hygiene, CareCoins Flutter frontend README, Local end-to-end testing via Firebase Auth Emulator (+6 more)

### Community 41 - "Login Screen"
Cohesion: 0.15
Nodes (13): build, createState, dispose, _email, _forgotPassword, _google, _GoogleMark, _isRegistering (+5 more)

### Community 42 - "Billing Service"
Cohesion: 0.19
Nodes (7): attributedFamilyId(), ENTITLEMENT_PLAN_MAP, planCodeFor(), PLATFORM_BY_STORE, processWebhookEvent(), STATUS_BY_EVENT, baseEvent

### Community 43 - "Family & Member Services"
Cohesion: 0.17
Nodes (13): Flutter Unit + Widget Tests (44 on main), defaultActivities.js (insertStarterTasks / insertDefaultActivities), familyService.js, memberService.js, /api/families Router, actors table, family_deletion_approvals table, family_deletion_requests table (+5 more)

### Community 44 - "Push Service (Flutter)"
Cohesion: 0.15
Nodes (12): _currentToken, disable, enable, _foregroundListenerActive, init, _kVapidKey, PushService, _setupForegroundListener (+4 more)

### Community 45 - "Legal Links"
Cohesion: 0.15
Nodes (12): app, build, kPrivacyPolicyUrl, kTermsOfUseUrl, l, label, _LegalLink, LegalLinks (+4 more)

### Community 46 - "Third-Party Integrations"
Cohesion: 0.25
Nodes (11): Google Firebase (auth, push delivery), Resend (invitation/account email delivery), RevenueCat (subscription purchases), Flutter analyzer lint configuration, CareCoins Flutter package manifest (pubspec.yaml), RevenueCat purchases_flutter/purchases_ui_flutter dependency (mobile-only), Firebase setup for web/Android/iOS, Flutter Web app shell (index.html) (+3 more)

### Community 47 - "Billing Provider Boundary"
Cohesion: 0.22
Nodes (11): Provider Swappability (RevenueCat Boundary), family_id Subscriber Attribute (Purchase Attribution), billingService.js, /api/billing Router, /api/personal-time Router, billing_events table, Production Deployment Probe, purchase_service.dart (+3 more)

### Community 48 - "Test Coverage & API Surface"
Cohesion: 0.20
Nodes (11): Backend Unit Tests (200 on main), No E2E Layer on main (Gap), Playwright E2E Suite (retired, vue-frontend branch), /api/me Router, ApiClient (api_client.dart), AppState (ChangeNotifier), shell.dart (Navigation Shell), auth.js (Pinia Auth Store, retired) (+3 more)

### Community 49 - "Web App Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 50 - "Admin Privacy & Retention"
Cohesion: 0.22
Nodes (10): Family Heartbeat Mechanism, Admin Privacy Boundary (Landlord not Housemate), Inactivity Notice → Retention Sweep Process, adminService.js, retentionService.js, admin_audit_log table, families table, family_members table (+2 more)

### Community 51 - "Push Notification Backend"
Cohesion: 0.22
Nodes (9): notify.js (FCM helpers), fcm_tokens table, notification_preferences table, Family Setup Questionnaire Plan, push_service.dart, useNotifications.js (retired), Internationalization Plan, flutter gen-l10n configuration (+1 more)

### Community 52 - "Avatar Upload"
Cohesion: 0.22
Nodes (8): app, bytes, pickAndUploadAvatar, picked, runAction, package:flutter/widgets.dart, package:image_picker/image_picker.dart, ../state/app_state.dart

### Community 53 - "Deploy Script"
Cohesion: 0.42
Nodes (8): die(), ok(), remote(), remote_read(), deploy.sh script, step(), usage(), warn()

### Community 54 - "Activity RBAC & Locking"
Cohesion: 0.36
Nodes (8): activityService.js, runAutoCompleteSweep(), RBAC Middleware (requireRole / assertMemberRole / requireAdmin), /api/activities Router, /api/dashboard Router, SELECT ... FOR UPDATE Locking Pattern, Middleware / Routes / Services Layering, Lazy Sweep-on-Read Pattern

### Community 55 - "Firebase Options"
Cohesion: 0.25
Nodes (7): android, DefaultFirebaseOptions, ios, web, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

### Community 56 - "Telemetry Client"
Cohesion: 0.29
Nodes (6): api_client.dart, _api, init, log, Telemetry, static ApiClient?

### Community 57 - "Express Middleware Chain"
Cohesion: 0.33
Nodes (7): src/app.js (Express middleware chain), familyHeartbeat Middleware, requireAuth Middleware, /api/admin Router, db/users.js (upsertUserFromAuth, assertActiveMember), admin_screen.dart, Firebase Auth Verification Chain

### Community 58 - "Personal Time Data Model"
Cohesion: 0.38
Nodes (7): personalTimeService.js, activities table, coin_ledger table, personal_time_requests table, migrate-activity-subclasses.sql, Activities as Base Class with Two Subclasses, Personal Time & Coverage Feature

### Community 59 - "Onboarding Help Layers"
Cohesion: 0.29
Nodes (7): Activation = first validated task within 7 days, Layer 1: Always-available help, Layer 2: First-run guided tour, Layer 3: Activation checklist, onboarding_events table, Phase 4: Measurement & iterate, Data collection table (schema-derived)

### Community 60 - "ARB Plural Tests"
Cohesion: 0.33
Nodes (5): dart:convert, dart:io, File, arbs, main

### Community 61 - "P0 Release Blockers"
Cohesion: 0.47
Nodes (6): P0 blockers implemented (commit 4b7412a), Missing INTERNET permission in release Android manifest, Cleartext HTTP blocked on Android 9+/iOS ATS, iOS Firebase never initialises (UnsupportedError), P0 — release blockers, Batch 4: push notifications (was unverified/uncommitted)

### Community 62 - "P1 Mobile UX Issues"
Cohesion: 0.33
Nodes (6): P1 touch-safe drag & drop implemented (commit 887234e), kMobileBreakpoint width-based check misclassifies landscape phones, Draggable breaks touch scrolling; needs LongPressDraggable, P1 — high-impact mobile UX/robustness, Silent catch blocks hide load errors as 'no data', UTC/local inconsistency on the dashboard

### Community 63 - "Task Action Routes"
Cohesion: 0.33
Nodes (6): _buildChecklist, Route complete, Route create_task, Route reward, Route schedule, Route validate

### Community 64 - "JSON Helpers"
Cohesion: 0.33
Nodes (5): fallback, null, toNum, toNumOrNull, return

### Community 65 - "Docker Compose Stack"
Cohesion: 0.50
Nodes (5): backend service, db-init service, frontend service (Flutter web + nginx), postgres service, pool.js — withTransaction()

### Community 66 - "Entitlement Merge"
Cohesion: 0.70
Nodes (5): Entitlement Merge — Most Generous Wins, entitlementService.js, admin_grants table, family_plans table, plans table

### Community 67 - "Service Worker Architecture"
Cohesion: 0.60
Nodes (5): firebase-messaging-sw.js (retired Vue generated SW), generate-firebase-sw Vite Plugin (retired app instance), vite-plugin-pwa (Workbox SW generation), generate-firebase-sw Vite Plugin, Two Service Worker Architecture

### Community 68 - "Running Instructions"
Cohesion: 0.40
Nodes (5): CareCoins running instructions, Development mode run instructions, Docker Compose deployment (4 services), Environment variables (dev vs Docker mode), vue-frontend branch (archived Vue app)

### Community 69 - "Onboarding Telemetry"
Cohesion: 0.50
Nodes (4): onboarding_events table, Activity-Areas Questionnaire Step, onboarding_screen.dart, telemetry.dart

### Community 70 - "Design Principles"
Cohesion: 0.50
Nodes (4): The Family Operations Room (Creative North Star), Flat-by-Default, Ambient-on-State Elevation, The One Job Rule (Semantic Color), Anti-Gamification / Anti-Feed Design Principle

### Community 72 - "Family Row Navigation"
Cohesion: 0.67
Nodes (3): _familyRow, _openDaily, MaterialPageRoute

## Ambiguous Edges - Review These
- `Internationalization Plan` → `notify.js (FCM helpers)`  [AMBIGUOUS]
  docs/i18n-plan.md · relation: conceptually_related_to

## Knowledge Gaps
- **888 isolated node(s):** `name`, `version`, `description`, `main`, `type` (+883 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **38 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Internationalization Plan` and `notify.js (FCM helpers)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Personal Time & Coverage — handoff` connect `Absence & Distribution Services` to `Backend Bootstrap & Scripts`, `Personal Time Dialog`, `Personal Time Service`, `Activity & Ledger Services`, `Personal Time Design Docs`?**
  _High betweenness centrality (0.318) - this node is a cross-community bridge._
- **Why does `AppState` connect `Admin & Profile Screens` to `Daily Screen Internals`, `Daily & Dashboard Data`, `Design System UI Kit`, `App State & Auth Flow`, `Onboarding Wizard`, `Personal Time Dialog`, `Activities Screen`, `Stats Screen`, `Marketplace Screen`, `Admin Screen Tabs`, `Timeline & Card Widgets`, `App Shell & Navigation`, `Family Circle Widget`, `App Entry & Auth Gate`, `Admin Screen State`, `Subscription Card`, `Absence Dialog`, `Tour Service`, `Login Screen`, `Legal Links`, `Avatar Upload`, `Daily Screen State`, `Cover Request Card`, `Dashboard Screen State`, `Onboarding Screen State`, `Stats Screen State`, `Personal Time Sheet`?**
  _High betweenness centrality (0.120) - this node is a cross-community bridge._
- **Why does `Onboarding & In-App Help Plan` connect `Flutter Port Docs` to `Tour Service`, `Telemetry Client`, `Coach Marks Tour`, `Activation Checklist`, `Personal Time Design Docs`?**
  _High betweenness centrality (0.085) - this node is a cross-community bridge._
- **What connects `name`, `version`, `description` to the rest of the system?**
  _888 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Backend Bootstrap & Scripts` be split into smaller, more focused modules?**
  _Cohesion score 0.05358182877111241 - nodes in this community are weakly interconnected._
- **Should `Daily Screen Internals` be split into smaller, more focused modules?**
  _Cohesion score 0.02666666666666667 - nodes in this community are weakly interconnected._