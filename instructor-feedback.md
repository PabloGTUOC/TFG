# Instructor Feedback — CAT3 Response Plan

> Feedback received from professor after CAT3 evaluation.
> This document tracks the three issues raised and the concrete plan to address each before CAT4.

---

## 1. Monolithic Vue components — refactor into sub-components

**Feedback:** Several Vue components have grown too large (`ProfileView.vue` ~1,455 lines, `DailyView.vue` ~1,994 lines). Refactor into smaller, more modular sub-components to improve maintainability and readability.

### DailyView.vue (1,994 lines → target ~400 lines)

Extract logic into composables and UI into dedicated components:

| Extract | Destination | Content |
|---|---|---|
| Swipe-to-delete | `composables/useCardSwipe.js` | `swipingId`, `swipeDeltaX`, `dismissingIds`, all touch handlers |
| Day-navigation swipe | `composables/useDaySwipe.js` | `touchStartX/Y`, `onTouchStart/End` |
| Timeline positioning | `composables/useTimeline.js` | `scheduledToday` overlap/positioning, `nowLineTop`, `nowIndex`, `scrollToNow` |
| Desktop timeline | `components/daily/DesktopTimeline.vue` | Hour lines, positioned chips, drag-drop |
| Mobile timeline list | `components/daily/MobileTimeline.vue` | `tl-list`, now-divider, gap indicators |
| Task library sidebar | `components/daily/TaskLibrary.vue` | Search, filters, draggable template rows |
| Task bottom sheet | `components/daily/TaskSheet.vue` | Mobile task picker sheet |
| All modals | `components/daily/DailyModals.vue` | Schedule, Recurrence, Delete, Bounty, Absence (×2) |

`DailyView.vue` becomes the coordinator: loads data, owns top-level refs, passes props, handles emits.

### ProfileView.vue (1,455 lines → target ~300 lines)

Each tab maps to one component:

| Extract | Destination |
|---|---|
| Notification preferences | `components/profile/NotificationPrefs.vue` |
| Avatar upload (user + actors) | `components/profile/AvatarUpload.vue` |
| Care dependents CRUD | `components/profile/CareActors.vue` |
| Family members + invitations | `components/profile/FamilyMembers.vue` |
| Invite link + QR code | `components/profile/InviteLink.vue` |
| Family deletion request flow | `components/profile/FamilyDeletion.vue` |
| Profile form (name/alias) | `components/profile/ProfileForm.vue` |
| Coin ledger | `components/profile/CoinLedger.vue` |

`ProfileView.vue` keeps only the tab container and `onMounted` data-loading calls.

---

## 2. Monolithic backend route files — extract service/controller layer

**Feedback:** Route files (`families.js` ~825 lines, `activities.js` ~738 lines) are too large. Abstract business logic from routing into dedicated service modules to keep code clean and testable.

### Current problem
Route handlers embed `withTransaction`, all SQL queries, and all business rules in one place. This makes logic impossible to unit-test without spinning up HTTP.

### Target structure

```
backend/src/
  routes/
    activities.js        ← HTTP only: parse params, call service, send res  (~150 lines)
    families.js          ← HTTP only: routing + multer + call service        (~150 lines)
    me.js                ← HTTP only (next candidate after the above)
  services/
    activityService.js   ← listActivities(), createActivity(), scheduleActivity(),
                            completeActivity(), validateActivity(),
                            offerBounty(), acceptBounty(), deleteActivity(),
                            createRecurrence(), revertActivity()
    familyService.js     ← createFamily(), getFamily(), deleteFamily(),
                            handleDeletionRequest(), insertDefaultActivities()
    memberService.js     ← listMembers(), approveMember(), removeMember(),
                            updateMemberAlias(), uploadAvatar()
```

`me.js` (402 lines) follows the same pattern into `services/userService.js` once the above are done.

---

## 3. Automated tests — prioritize early in CAT4

**Feedback:** Automated tests have been deferred to CAT4. Ensure they are prioritized early in the next phase to guarantee stability before final delivery.

### Stack (no new dependencies beyond what Vite already provides)
- **Backend unit + integration:** Vitest + Supertest (ESM-native, matches the project setup)
- **Frontend component:** Vitest + `@vue/test-utils`
- **E2E:** Playwright (covers desktop and mobile viewports)

### Test coverage priorities

| Priority | Area | Scenarios |
|---|---|---|
| 1 | Activity lifecycle | create → approve → schedule → complete → validate → coins awarded |
| 2 | Bounty flow | offer bounty → accept → coin transfer from offerer to taker |
| 3 | Family membership | create family, invite member, approve, remove |
| 4 | Coin integrity | balance never goes negative; correct delta on validate and revert |
| 5 | Auth/RBAC middleware | unauthenticated → 401; wrong family → 403; wrong role → 403 |
| 6 | Frontend composables | `useTimeline` positioning output; `getCardStyle` per status/category |
| 7 | E2E happy paths | Login → schedule task → complete → validate → see on dashboard |

> **Note:** The service-layer extraction in point 2 is a prerequisite for clean unit tests. Testing pure functions in `activityService.js` is far easier than wrapping HTTP calls around SQL-embedded route handlers. Do point 2 before point 3.

---

## Execution order

```
Step 1  Extract activityService.js           ← unblocks activity unit tests
Step 2  Activity unit tests                  ← highest risk area for CAT4
Step 3  Extract familyService + memberService
Step 4  Family + member unit tests
Step 5  Refactor DailyView.vue               ← biggest frontend maintainability win
Step 6  Refactor ProfileView.vue
Step 7  Frontend composable tests
Step 8  E2E happy paths (Playwright)
```
