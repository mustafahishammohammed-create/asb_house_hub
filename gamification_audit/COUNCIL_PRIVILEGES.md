# Council Roster Privileges — Requirement R1

**User requirement (2026-11-07, verbatim):** "see i want not only the staff can change but also the council roster has some priviledges"

**Status:** PARTIALLY IMPLEMENTED — rules deployed (release verified first-hand 2026-11-07), council claims approval works end-to-end. **Two grants are not actually live:** captain claim approval fails in live mode (O-1) and council grading awards points without persisting the official grade (O-2). See [NOT_DONE_AND_FALSE_CLAIMS.md](NOT_DONE_AND_FALSE_CLAIMS.md) for evidence and solutions. Demo-mode unit tests do not prove these paths — rules are not enforced in tests.

## The problem: council privileges were previously phantom

The app already had a council roster and a **Council Review Portal**, but council members could not actually use it in live mode:

| Layer | Who counts as privileged | Evidence |
|---|---|---|
| Client `HierarchyService.isAdmin` | super admin, teachers/faculty, **captains, council, prefects** | [hierarchy_service.dart:100-110](../lib/services/hierarchy_service.dart) |
| Home screen portal gate | same broad check → council **sees** the Council Review Portal | [home_screen.dart:1268,1632-1638](../lib/screens/home_screen.dart) |
| Firestore rules `isAdmin()` | super admin, teacher/faculty/principal/staff **only** | [firestore.rules:248-254](../firestore.rules) |
| `house_claims` update (approve/reject) | rules `isAdmin()` only | firestore.rules:708-710 |

Previously, a council officer tapped Approve, `approveClaim` ran its transaction, rules denied it, and they received an error.

## Implemented Privilege Matrix

| Operation | Staff | Council | Captain | Prefect | Student | Status |
|---|---|---|---|---|---|---|
| Approve/reject house claims (Council Review Portal) | yes | **yes** | **yes, own house only** | no | no | Council LIVE; **captain BROKEN (O-1)** — transaction also writes house_points/house_contributors, which deny captains |
| Grade assignments / award academic merit (G4) | yes | **yes** | no | no | no | Staff LIVE; **council CLIENT-ONLY (O-2)** — classes/assignments rules deny council; status write swallowed, points still awarded |
| Record conduct (merit/demerit) | yes | **yes** | no | read | no | IMPLEMENTED & LIVE |
| Sports points (bounded 0..+500) | yes | **yes (0..+500)** | no | no | no | IMPLEMENTED & LIVE |
| Manage elections | yes | yes | yes | no | no | VERIFIED |
| Assign roles / roster management | super admin only | no | no | no | no | RETAINED |

## Implementation Evidence

### 1. `firestore.rules` (Released to Production)
- Added `isCouncil()` helper checking token claims and `users` profile for 10 executive council roles:
  `['council', 'head_boy', 'head_girl', 'deputy_head_boy', 'deputy_head_girl', 'head_of_activities', 'cultural_secretary', 'sports_captain', 'sports_vice_captain', 'executive_council']`
- Added `isPrefect()` helper for `['prefect', 'student_rep', 'grade_prefect']`.
- Updated `house_claims/{claimId}` update rule to allow `isAdmin() || isCouncil() || (isCaptain() && hasUserDoc() && getUserData().house_name.lower() == resource.data.house_name.lower())` with immutable field validation.
- Updated `house_points/{houseId}` update rule to allow `isCouncil()` and `isSportsLead()` to apply bounded positive increments `0..+500`, while restricting negative point deductions strictly to `isAdmin()`.
- Updated `house_contributors/{scholarNo}` write rule to allow `isAdmin() || isCouncil()` with strict `isValidHouseContributor` schema validation.
- Updated `users/{userId}` update rule to allow `(isCouncil() || isCaptain())` to increment `points_contributed` (0..+500) without altering role, scholar number, or account identity.
- Updated `student_conduct/{conductId}` write rule to allow `isAdmin() || isCouncil()`.
- Deployed and released via Firebase CLI: `+ firestore: released rules firestore.rules to cloud.firestore`.

### 2. Client Service & Screens
- Added `HierarchyService.canGradeAcademics(...)` allowing Super Admin, Faculty/Teachers, and Council officers to grade assignments and award academic merit.
- Gated `AuthService.updateAssignmentStatus` when transitioning to `AssignmentStatus.graded` against `HierarchyService.canGradeAcademics`.
- Gated `AcademicsScreen._cycleAssignmentStatus` to prevent students from self-grading, displaying an institutional verification prompt and cycling back to pending.

### 3. Verification & Test Evidence
- `test/gamification_security_test.dart`:
  - `HierarchyService.canGradeAcademics grants staff and council, rejects students and prefects` PASSED
  - `updateAssignmentStatus blocks regular student from transitioning assignment to graded` PASSED
  - `updateAssignmentStatus allows council officer to transition assignment to graded` PASSED
- Full test pass: 15/15 gamification security tests passed, 32/32 election tests passed, 262/262 widget tests passed.
- `flutter analyze`: 0 errors, 0 warnings.