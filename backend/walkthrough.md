# Deletion Workflows Implemented

The requested deletion workflows are now fully implemented across the stack! 

## 1. User Account Deletion (Soft-Delete)
Users can now delete their account directly from the **Personal Area** via the new `Delete Account` button.

**What happens under the hood:**
- The user's authentication profile (Firebase Auth) is permanently deleted.
- Any future activities scheduled for this user are removed from the calendar.
- In the database, the user's `users` record is anonymized (Name becomes "Deleted User", email is wiped out, and an `is_deleted` flag is set).
- Their `family_members` status is changed from `active` to `inactive`.
- *Result:* Their historical coin balance and completed tasks remain visible to the rest of the family for analytics, but their personal data is fully scrubbed and they can no longer log in.

## 2. Family Deletion & Approval Workflow
Caregivers can now request to delete a family from the **Personal Area** using the new `Delete Family` button.

**What happens under the hood:**
- **Single Caregiver:** If the family only has one caregiver, the family (and all its associated data) is deleted immediately.
- **Multiple Caregivers:** If there are multiple active caregivers, a `Deletion Request` is created.
  - A mock email notification is dispatched to all other caregivers (you will see this in the backend terminal logs).
  - A **Pending Family Deletion Requests** banner appears in the Personal Area for the other caregivers, allowing them to explicitly `Approve` or `Reject` the request.
  - If rejected by anyone, the request is canceled.
  - Once all caregivers approve, the family is permanently deleted.

### How to Verify:
1. **Account Deletion**: Open your Personal Area, scroll to the bottom of the Account Settings block, and click `Delete Account`. You will be logged out and the backend will scrub your profile. (Be careful, you'll need to create a new account afterward!)
2. **Family Deletion (Multiple Caregivers)**: 
   - Invite a second account to your family and accept the invite to make them a Caregiver.
   - Click `Delete Family`.
   - Log into the second account. You should see a red banner asking for your approval.
   - Click `Approve` and verify the family is deleted.
