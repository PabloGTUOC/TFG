# Goal Description

Implement two critical deletion workflows:
1. **User Account Deletion**: Allow users to delete their account while preserving their historical data (coin status, activities) within their families. They will be anonymized and marked as "inactive" rather than being hard-deleted, which would wipe out all their family history.
2. **Family Deletion**: Allow a caregiver to delete a family. If there are multiple caregivers, it requires approval from all other caregivers before the deletion is executed.

## User Review Required

> [!IMPORTANT]
> **Account Soft-Deletion vs Hard-Deletion**: Because PostgreSQL uses `ON DELETE CASCADE` extensively in the schema, hard-deleting a user row would delete all their activities, coin ledger entries, and family member records. To keep them visible as "absent/deleted" with their past coins, we must use a **Soft-Delete / Anonymization** approach. Their personal data (email, name, Firebase Auth account) will be destroyed, but a "ghost" record will remain to preserve family history.

> [!IMPORTANT]
> **Family Deletion Workflow**: The plan proposes creating two new tables (`family_deletion_requests` and `family_deletion_approvals`) to manage the asynchronous approval process when multiple caregivers are present. If any caregiver rejects the request, the deletion is canceled.

## Decisions from Open Questions

> [!NOTE]
> 1. **Future Activities**: When a user deletes their account, any activities scheduled for future dates assigned to them will be deleted. Past activities remain.
> 2. **Family Deletion Notifications**: When a family deletion is requested, other caregivers will receive both an in-app notification/banner in their personal area and an email notification.

## Proposed Changes

---

### Database Schema Updates

Modifications to the PostgreSQL schema to support new statuses and the approval workflow.

#### [MODIFY] `backend/src/db/schema.sql`
- **`users` table**: Add `is_deleted BOOLEAN NOT NULL DEFAULT false`.
- **`family_members` table**: Update the status constraint to allow 'inactive' users. `CHECK (status IN ('active', 'pending', 'inactive'))`.
- **[NEW TABLES]**: Add `family_deletion_requests` and `family_deletion_approvals` to track multi-caregiver deletion requests.

---

### Backend Routes

New endpoints for account deletion and family deletion management.

#### [MODIFY] `backend/src/routes/me.js`
- **`DELETE /api/me`**: 
  - Delete the user from Firebase Auth using the Admin SDK.
  - Delete all future activities (`starts_at > NOW()`) where `assigned_to` is the deleting user.
  - Update `users` table: set `email = NULL`, `display_name = 'Deleted User'`, `firebase_uid = 'deleted_' || id`, `is_deleted = true`.
  - Update `family_members` table: set `status = 'inactive'` for all families this user belongs to.
  - Return success.

#### [MODIFY] `backend/src/routes/families.js`
- **`DELETE /api/families/:id`**: 
  - Check the number of active caregivers.
  - If 1 caregiver: Execute `DELETE FROM families WHERE id = $1`.
  - If >1 caregiver: Create a `family_deletion_requests` record and pending `family_deletion_approvals` for other caregivers. 
  - Send an email notification to all other caregivers via a mailer utility (e.g., SendGrid/SMTP/Resend). Return a status indicating approval is required.
- **`GET /api/families/:id/deletion-requests`**: Fetch active deletion requests to show in the UI.
- **`POST /api/families/:id/deletion-requests/:requestId/approve`**: 
  - Mark approval. If all caregivers have approved, delete the family.
- **`POST /api/families/:id/deletion-requests/:requestId/reject`**: 
  - Mark rejection and cancel the deletion request.

---

### Frontend Components

Updates to the settings and family management views to expose these actions.

#### [MODIFY] `frontend/src/views/SettingsView.vue` (or similar user profile view)
- Add a "Delete Account" button in the "Danger Zone".
- Wire it to `DELETE /api/me`.
- Force logout and redirect to login page upon success.

#### [MODIFY] `frontend/src/views/FamilySettingsView.vue` (or Family Admin Hub)
- Add a "Delete Family" button.
- If multiple caregivers exist, show a warning: "This will send a deletion request to other caregivers."
- Add a banner/section to display pending family deletion requests to other caregivers, allowing them to Approve or Reject.

## Verification Plan

### Automated Tests
- Test user soft-deletion and verify the Firebase Auth user is destroyed while the Postgres record is anonymized.
- Test single-caregiver family deletion (immediate delete).
- Test multi-caregiver family deletion (requires 2nd caregiver approval).

### Manual Verification
- Log in as Caregiver A, invite Caregiver B. Caregiver A tries to delete family -> Request created. Log in as Caregiver B -> See request, click Approve -> Family is deleted.
- Verify that a deleted user appears as "Deleted User" with their past coin balance in the family leaderboard.
