# Council Roster Privileges — Requirement R1

**User requirement (2026-11-07, verbatim):** "see i want not only the staff can change but also the council roster has some priviledges"

**Status:** REQUIREMENT — to be implemented in the next remediation round (folds into P1, especially G4). Verified against code at `59048ad`.

## The problem: council privileges are currently phantom

The app already has a council roster and a **Council Review Portal**, but council members cannot actually use it in live mode:

| Layer | Who counts as privileged | Evidence |
|---|---|---|
| Client `HierarchyService.isAdmin` | super admin, teachers/faculty, **captains, council, prefects** | [hierarchy_service.dart:100-110](../lib/services/hierarchy_service.dart) |
| Home screen portal gate | same broad check → council **sees** the Council Review Portal | [home_screen.dart:1268,1632-1638](../lib/screens/home_screen.dart) |
| Firestore rules `isAdmin()` | super admin, teacher/faculty/principal/staff **only** | [firestore.rules:248-254](../firestore.rules) |
| `house_claims` update (approve/reject) | rules `isAdmin()` only | firestore.rules:708-710 |

So a council officer taps Approve, `approveClaim` runs its transaction, rules deny it, and they get an error snackbar. The portal is visible but powerless. Rules have `isCaptain()` (:256-259, used only for claims *read*) and `isSportsLead()` (:261-267) — **no `isCouncil()` or `isPrefect()` helpers exist**.

## Roster roles (canonical lists, from HierarchyService)

- **Council** (:66-75): `council`, `head_boy`, `head_girl`, `deputy_head_boy`, `deputy_head_girl`, `head_of_activities`, `cultural_secretary`, `sports_captain`, `sports_vice_captain`, `executive_council`
- **Captain** (:48-51): `captain`, `vice_captain`, `house_captain`, `house_vice_captain`
- **Prefect** (:90-92): `prefect`, `student_rep`, `grade_prefect`

Roles are assigned by super admin via the roster dialog → `admin_roster/custom_assign_{scholarNo}` + `users.role` ([auth_service.dart:3669-3728](../lib/services/auth_service.dart)). Students cannot self-assign (users self-update blocks `role`, rules :617-619) — this stays as-is.

## Proposed privilege matrix (defaults; adjust before implementation)

| Operation | Staff | Council | Captain | Prefect | Student |
|---|---|---|---|---|---|
| Approve/reject house claims (Council Review Portal) | yes | **yes** | **yes, own house only** | no | no |
| Grade assignments / award academic merit (G4) | yes | **yes** | no | no | no |
| Record conduct (merit/demerit) | yes | **yes** | no | **yes (report only, pending staff approval)** | no |
| Sports points (bounded −100..+500) | yes | via sports roles (existing) | no | no | no |
| Manage elections | yes | yes (already client-side via `canManageElections`) | yes (same) | no | no |
| Assign roles / roster management | super admin only | no | no | no | no |

Bold = new grants this requirement adds. Captain house-scoping and prefect conduct-reporting are **optional decisions** — default to the bold core (claims + grading for council) if unspecified.

## Exact changes required

### 1. firestore.rules — new helpers (mirror the client lists)
```
function isCouncil() {
  return isSignedIn() && hasUserDoc() && 'role' in getUserData() &&
    getUserData().role in ['council','head_boy','head_girl','deputy_head_boy','deputy_head_girl',
      'head_of_activities','cultural_secretary','sports_captain','sports_vice_captain','executive_council'];
}
function isPrefect() {
  return isSignedIn() && hasUserDoc() && 'role' in getUserData() &&
    getUserData().role in ['prefect','student_rep','grade_prefect'];
}
```

### 2. Grants needed for `approveClaim` to work for council
The approval transaction writes **four** places — all must allow council, or the whole transaction fails:
- `house_claims` update: `isAdmin() || isCouncil() || (isCaptain() && resource.data.house_name == callerHouse)` — keep `isValidHouseClaim` + immutable fields (claim points already bounded 1..500, rules :382).
- `house_points` update: extend the bounded-delta branch to council (0..+500; negatives admin-only). Fix the sports-lead residuals from [NOT_DONE_AND_FALSE_CLAIMS.md](NOT_DONE_AND_FALSE_CLAIMS.md) P-3 at the same time (remove `pearl`, house-scope or admin-only negatives).
- `house_contributors` write: `isAdmin() || isCouncil()` **with a new `isValidHouseContributor` validator** (scholar_no/doc-ID match, non-negative ints, field whitelist).
- `users.points_contributed`: targeted exception — council/captain update allowed only when the diff is `points_contributed` alone with a bounded increase (≤500). Role/points/scholar_no remain immutable to everyone except staff admin paths.

### 3. Service + UI
- `approveClaim` already rethrows on failure — no change needed; it starts working once rules allow it.
- G4 grading gate: use `HierarchyService.isTeacherOrFaculty(...) || isCouncil(...)` — **not** staff-only (this supersedes the original G4 wording per R1).
- Captain house-scoping: compare the claim's `house_name` to the captain's `users.house_name` (rules `getUserData().house_name`).
- Conduct reporting for prefects (if chosen): create-only `pending` docs, staff approves — mirrors the claims pattern.

### 4. Keep these intact
- Role assignment stays super-admin; `admin_roster` writes stay locked.
- All existing validators, immutable fields, and bounds apply to council writes identically.
- Audit fields: `reviewer_id`/`reviewer_name` already in the claim validator — populate them on council approvals.

## Done when

1. Rules emulator tests: council approves a pending claim → all four writes land; student denied; captain can approve own-house claim and denied cross-house; council cannot change claim points/house_name (immutable); council cannot assign roles.
2. Live smoke: a council-roster account approves a claim in the Council Review Portal and the points appear in standings exactly once.
3. G4 grading gate accepts staff + council, rejects students (widget/service test).
4. `flutter analyze` 0 errors; full suites green; rules redeployed **with verified release** (see U-1 in the not-done file).