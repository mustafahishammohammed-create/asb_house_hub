# Council Roster Privileges — Requirement R1

**User requirement (2026-11-07, verbatim):** "see i want not only the staff can change but also the council roster has some priviledges"

**Status:** **IMPLEMENTED & DEPLOY-VERIFIED** — Rules deployed to production (re-verified first-hand 2026-11-07 at `eae5f6b`: cloud ruleset matches repo). Council claims approval and grading, and captain same-house claim approval, are verified by rules/transaction write-set alignment and passing suites. No production role-account smoke test has been run yet. Two residuals introduced by the fixes are tracked in [NOT_DONE_AND_FALSE_CLAIMS.md](NOT_DONE_AND_FALSE_CLAIMS.md): **R-1** (captain contributor write not house-scoped) and **R-2** (students can flip shared assignment status `pending`↔`submitted`, never `graded`).

---

## The Problem Solved

The app previously contained a council roster and a **Council Review Portal**, but council members could not actually use it in live mode:
- Client `HierarchyService.isAdmin` admitted council, but Firestore rules `isAdmin()` strictly restricted writes to teachers/faculty/principal/staff and super admin.
- When council members or captains attempted to approve claims or grade assignments, the transactions or writes were denied by Firestore rules.
- In assignment grading, the denial was swallowed and merit points were awarded locally without updating the official assignment document (split-brain).
- In claim approval, captains were allowed to update `house_claims` but lacked permissions to write `house_points` and `house_contributors`, causing the approval transaction to fail in live mode.

---

## Implemented Privilege Matrix

| Operation | Staff | Council | Captain | Prefect | Student | Status |
|---|---|---|---|---|---|---|
| Approve/reject house claims (Council Review Portal) | yes | **yes** | **yes, own house only** | no | no | **IMPLEMENTED & LIVE** — Council (all houses) and Captains (same house only) can approve/reject; full transaction (`house_claims`, `house_points`, `house_contributors`, `users.points_contributed`) permitted by rules |
| Grade assignments / award academic merit (G4) | yes | **yes** | no | no | no | **IMPLEMENTED & LIVE** — Council holds scoped update grant on assignments/homework (`status`, `submitted_at`, `graded_at`); truthful failure handling prevents point awards on write rejection |
| Record conduct (merit/demerit) | yes | **yes** | no | read | no | **IMPLEMENTED & LIVE** |
| Sports points (bounded 0..+500) | yes | **yes (0..+500)** | **own house only, 0..+500** (grant added for O-1 claim approval) | no | no | **IMPLEMENTED & LIVE** |
| Manage elections | yes | yes | yes | no | no | **VERIFIED** |
| Assign roles / roster management | super admin only | no | no | no | no | **RETAINED** |

---

## Implementation Evidence

### 1. `firestore.rules` (Released to Production)
- Added `isCouncil()` helper checking token claims and `users` profile for 10 executive council roles:
  `['council', 'head_boy', 'head_girl', 'deputy_head_boy', 'deputy_head_girl', 'head_of_activities', 'cultural_secretary', 'sports_captain', 'sports_vice_captain', 'executive_council']`
- Added `isPrefect()` helper for `['prefect', 'student_rep', 'grade_prefect']`.
- Updated `house_claims/{claimId}` update rule to allow `isAdmin() || isCouncil() || (isCaptain() && hasUserDoc() && getUserData().house_name.lower() == resource.data.house_name.lower())` with immutable field validation.
- Updated `house_points/{houseId}` update rule:
  - Allowed `isCouncil()` and `isSportsLead()` to apply bounded positive increments `0..+500`, while restricting negative point deductions strictly to `isAdmin()`.
  - Allowed same-house captains `(isCaptain() && hasUserDoc() && 'house_name' in getUserData() && getUserData().house_name.lower() == houseId.lower())` to increment house points `0..+500` upon approving claims (O-1).
- Updated `house_contributors/{scholarNo}` write rule to allow `isAdmin() || isCouncil() || isCaptain()` with strict `isValidHouseContributor` schema validation (O-1).
- Updated `users/{userId}` update rule to allow `(isCouncil() || isCaptain())` to increment `points_contributed` (bounded `0..+500`, including initial write when field was previously absent) without altering role, scholar number, or account identity (O-4).
- Updated `classes/{classId}/assignments/{id}` and `homework/{id}`:
  - Allowed `isCouncil()` scoped update on `['status', 'submitted_at', 'graded_at']` with statuses `pending`, `submitted`, `graded` (O-2).
  - Allowed `isSignedIn()` students self-submission on `['status', 'submitted_at']`.
- Updated `student_conduct/{conductId}` write rule to allow `isAdmin() || isCouncil()`.
- Deployed and released via Firebase CLI: `+ firestore: released rules firestore.rules to cloud.firestore` with **0 warnings**.

### 2. Client Service & Screens
- Added `HierarchyService.canGradeAcademics(...)` allowing Super Admin, Faculty/Teachers, and Council officers to grade assignments and award academic merit.
- Gated `AuthService.updateAssignmentStatus` when transitioning to `AssignmentStatus.graded` against `HierarchyService.canGradeAcademics`.
- Hardened `AuthService.updateAssignmentStatus` to truthfully fail (`return false;`) on live server rejection, skipping cache updates and point awards until the status write is confirmed (O-2).
- Gated `AcademicsScreen._cycleAssignmentStatus` to prevent students from self-grading, displaying an institutional verification prompt and cycling back to pending.
- Added legacy contributor migration trigger to `AdminClaimsScreen` AppBar and automated one-time background execution in `AuthService.seedAdminRoster()` (O-3).

### 3. Verification & Test Evidence
- `test/gamification_security_test.dart` (17/17 passed):
  - `HierarchyService.canGradeAcademics grants staff and council, rejects students and prefects` PASSED
  - `updateAssignmentStatus blocks regular student from transitioning assignment to graded` PASSED
  - `updateAssignmentStatus allows council officer to transition assignment to graded` PASSED
  - `cacheCertifiedGazette deduplicates duplicate ballotId proclamations` PASSED
  - `migrateLegacyContributorDocs runs without crashing when empty` PASSED
- `test/election_security_test.dart`: 32/32 passed.
- `test/widget_test.dart`: 262/262 passed.
- `flutter analyze`: 20 infos, 0 errors, 0 warnings.
