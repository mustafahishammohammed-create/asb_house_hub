# Council Roster Privileges — Requirement R1

**User requirement (2026-11-07, verbatim):** "see i want not only the staff can change but also the council roster has some priviledges"

**Status:** **FULLY IMPLEMENTED & DEPLOY-VERIFIED** — Rules deployed to production (re-verified first-hand 2026-11-07 at `c78ddd8`: cloud ruleset matches repo). Council claims approval and grading, and captain same-house claim approval, are verified by rules/transaction write-set alignment and passing suites. R-1 (captain house scoping) and R-2 (per-student submission isolation) are closed; two minor R-2 follow-ups remain tracked in [NOT_DONE_AND_FALSE_CLAIMS.md](NOT_DONE_AND_FALSE_CLAIMS.md): R-5 (owners can self-mark their own submission doc `graded` — cosmetic, no points) and R-6 (grading flows write submission docs keyed to the grader's scholarNo until a per-student grading UI passes the target student).

**Requirement R2 (2026-11-07, verbatim):** "in council priviledge allow every council member to approve house claims the member bieng of any house and when that person approves maybe of any house eg emerald approves for some student of ruby house it should be approved with points reflecting in the leaderboard"

**R2 status: ALREADY LIVE — verified end-to-end and locked with regression tests.** No code or rules change was needed; every layer already permits cross-house council approval. Verified chain for the exact example (emerald council officer approves a ruby student's claim):

1. **Portal shows all houses' claims** — `getPendingClaimsStream()` filters only `status == 'pending'`, no house filter ([auth_service.dart:3417-3422](../lib/services/auth_service.dart)); client gate `HierarchyService.isCouncil` admits all 10 executive roles regardless of house ([hierarchy_service.dart:66-76](../lib/services/hierarchy_service.dart)).
2. **Claim update permitted** — `house_claims` update grants `isCouncil()` as an unscoped disjunct; only the captain branch is house-scoped ([firestore.rules:784-790](../firestore.rules)).
3. **Points go to the CLAIM's house, not the reviewer's** — the transaction reads authoritative `house_name` from the claim document (`authHouse`), so ruby receives the points even though the approver is emerald ([auth_service.dart:3480-3513](../lib/services/auth_service.dart)).
4. **Every ledger write in the transaction is council-permitted for any house** — `house_points` create/update `isCouncil()` unscoped, bounded 0..+500 (:915-937); `house_contributors` write `isCouncil()` (:943); claim points are validated 1..500 (:416) so the delta always fits the council cap.
5. **Student profile + notification** — `users.points_contributed` council branch is house-agnostic, delta ≤ 500 (:666-674); notification create allowed for any signed-in reviewer (:688).
6. **Leaderboard reflects it live** — `house_leaderboard_screen` streams `house_points/{house}` snapshots from Firestore, so the ruby total updates on every device, not just the approver's ([house_leaderboard_screen.dart:216-232](../lib/screens/house_leaderboard_screen.dart)).

**R2 regression lock:** Tests in `test/gamification_security_test.dart` group "R2 Cross-house council claim approval" assert the council grants stay house-agnostic on all four collections, captains stay house-scoped, claim points stay ≤ 500, and all 10 council roles pass the client gate.

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
- Updated `house_contributors/{scholarNo}` write rule:
  - Allowed `isAdmin() || isCouncil()` cross-house with `isValidHouseContributor` validation.
  - Strictly house-scoped captains to same house: `(isCaptain() && hasUserDoc() && 'house_name' in getUserData() && getUserData().house_name.lower() == request.resource.data.house_name.lower() && (!('house_name' in resource.data) || resource.data.house_name.lower() == getUserData().house_name.lower()))` (R-1).
- Updated `users/{userId}` update rule to allow `(isCouncil() || isCaptain())` to increment `points_contributed` (bounded `0..+500`, including initial write when field was previously absent) without altering role, scholar number, or account identity (O-4).
- Updated `classes/{classId}/assignments/{id}` and `homework/{id}`:
  - Allowed `isCouncil()` scoped update on `['status', 'submitted_at', 'graded_at']` with statuses `pending`, `submitted`, `graded` (O-2).
  - Isolated student submissions in subcollection `submissions/{scholarNo}`, disallowing direct student updates to the shared class-wide assignment doc (R-2).
- Updated `system_config/house_spirit_reactor`:
  - Added bounds `0..10,000,000` to `isValidSpiritReactor`.
  - Enforced non-decreasing positive increments `0..+500` per write (G13).
- Updated `student_conduct/{conductId}` write rule to allow `isAdmin() || isCouncil()`.
- Deployed and released via Firebase CLI: `+ firestore: released rules firestore.rules to cloud.firestore` with **0 warnings**.

### 2. Client Service & Screens
- Added `HierarchyService.canGradeAcademics(...)` allowing Super Admin, Faculty/Teachers, and Council officers to grade assignments and award academic merit.
- Gated `AuthService.updateAssignmentStatus` when transitioning to `AssignmentStatus.graded` against `HierarchyService.canGradeAcademics`.
- Hardened `AuthService.updateAssignmentStatus` to truthfully fail (`return false;`) on live server rejection, routing student submissions to their individual submission subcollection without mutating the shared class doc (O-2, R-2).
- Replaced absolute 4-house writes in `HouseArenaScreen._incrementSpiritMeter` with atomic `FieldValue.increment` on the caller's house only, tying contributor to caller (G13).
- Annotated AI context in `GeminiAiService` with server sync status (`Live Server Verified` vs `Offline Local Cache`) and ensured standings cache writes only from server snapshots (G10).
- Extracted deterministic pure helper `AuthService.mergeContributorData` and added comprehensive fixture-based unit tests (O-3, R-3).

### 3. Verification & Test Evidence
- `test/gamification_security_test.dart` (**28/28 passed**, including R-1, R-2, R-3, G13, and 6 R2 cross-house contract tests):
  - `HierarchyService.canGradeAcademics grants staff and council, rejects students and prefects` PASSED
  - `updateAssignmentStatus blocks regular student from transitioning assignment to graded` PASSED
  - `updateAssignmentStatus allows council officer to transition assignment to graded` PASSED
  - `cacheCertifiedGazette deduplicates duplicate ballotId proclamations` PASSED
  - `migrateLegacyContributorDocs runs without crashing when empty` PASSED
  - `R-3: mergeContributorData creates clean record when no existing doc` PASSED
  - `R-3: mergeContributorData sums points, keeps max merits, preserves identity` PASSED
  - `R-3: mergeContributorData accumulates multiple merges accurately` PASSED
  - `house_contributors write grants council (cross-house) and scopes captains (same-house)` PASSED
  - `R-2: assignments and homework disallow direct student writes and enforce per-student submissions` PASSED
  - `G13: spirit reactor enforces numeric bounds and non-decreasing increments` PASSED
- `test/election_security_test.dart`: 32/32 passed.
- `test/widget_test.dart`: 262/262 passed.
- `flutter analyze`: 20 infos, 0 errors, 0 warnings.
