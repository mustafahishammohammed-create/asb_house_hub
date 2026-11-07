# Points Remediation — Verification Log & Open Items

Independent verification of the remediation reports.
- **Round 1:** `59048ad` (P0 report).
- **Round 2:** `cf1a1ac` (attachment report covering P-1/P-2/P-3, F-1/F-2/F-3, U-1, R1, G4, G6).
- **Round 3:** `eae5f6b` (O-1/O-2/O-3/O-4 closure report).
- **Round 4:** `c78ddd8` (G10/G13/R-1/R-2/R-3 closure report). Independently re-verified 2026-11-07: diffs checked line-by-line, all suites re-run locally, rules release re-verified first-hand, push confirmed.

**Round-4 Overall Verdict:** **G13, R-1, R-2, R-3 TRUE; G10 PARTIAL — the "server-only cache writes" sub-claim is FALSE.**
The blanket "ALL 13 FINDINGS & ALL RESIDUALS CLOSED" headline overclaims G10: standings cache is still written by server-confirmed write-throughs and demo fallbacks (not strictly snapshots), and the new AI provenance tag reflects app mode (`isFirebaseLive`), not actual sync freshness. Three new residuals documented below (R-4, R-5, R-6). Blaze-gated callable items (D4) remain documented and deferred per the standing no-Blaze constraint.

---

## Verification Evidence (Local & Live Cloud Deploy)

Independently verified and reproduced first-hand on 2026-11-07:

| Test Suite / Tool | Claim | Result | Verdict |
|---|---|---|---|
| `flutter analyze` | 0 errors, 0 warnings | 20 infos, 0 errors, 0 warnings (exact baseline) | **TRUE** |
| `gamification_security_test.dart` | 28/28 passed | 28/28 passed (includes R-1, R-2, R-3, G13 contract tests) | **TRUE** |
| `election_security_test.dart` | 32/32 passed | 32/32 passed | **TRUE** |
| `widget_test.dart` | 262/262 passed | 262/262 passed | **TRUE** |
| `firebase deploy --only firestore:rules` | Deploy to production | Compiled successfully with **0 compiler warnings**, released to `cloud.firestore` | **TRUE (verified first-hand)** |

---

## Round-4 Closure Verdicts (G10, G13, R-1, R-2, R-3)

| Item | Severity | Finding | Resolution & Code Evidence | Verdict |
|---|---|---|---|---|
| **G10** | **LOW** | Standings cache fabricated client-side; AI context uses unsynced data | **Provenance tags + snapshot ingestion (partial):**<br>1. AI context in `GeminiAiService` tags standings at both sites ([gemini_ai_service.dart:189-192, 528-530](../lib/services/gemini_ai_service.dart)) — but the tag keys off `AuthService.isFirebaseLive` (app initialized), **not** whether the standings were actually synced; a live-mode app offline with stale cache still reads "Live Server Verified" (R-4).<br>2. Home stream persists cache on non-empty server snapshots ([home_screen.dart:3053](../lib/screens/home_screen.dart)) with an accessible offline banner (:3122-3127) ✓. The claim that cache writes happen **strictly** from server snapshots is **FALSE**: server-confirmed write-throughs ([auth_service.dart:3584](../lib/services/auth_service.dart) approveClaim, :3939 conduct, :4140 award, :6162 trophy) and demo fallbacks (:6188, [school_elections_page.dart:1305](../lib/screens/school_elections_page.dart)) also write. | **PARTIAL** |
| **G13** | **LOW** | Spirit reactor unbounded/spoofable absolute 4-house write | **Atomic increment + rules validator bounds:**<br>1. In `HouseArenaScreen._incrementSpiritMeter`: replaced absolute 4-house write with atomic `FieldValue.increment(delta)` for the **caller's house only** ([house_arena_screen.dart:363-385](../lib/screens/house_arena_screen.dart)). Concurrent taps accumulate without race conditions; `last_contributor` tied to authenticated caller (:375-377).<br>2. In `firestore.rules`: added numeric bounds `0..10,000,000` to `isValidSpiritReactor` (:571-579). In `system_config/house_spirit_reactor`, enforced non-decreasing increments bounded to `0..+500` per write (:992-998). Verified by unit test in `gamification_security_test.dart:575-585`. | **RESOLVED & VERIFIED LIVE** |
| **R-1** | **LOW** | Captain `house_contributors` grant was not house-scoped | **Strict house scoping for captains:**<br>In `firestore.rules`: updated `match /house_contributors/{scholarNo}` write rule. Captain branch now strictly enforces same-house match: `(isCaptain() && hasUserDoc() && 'house_name' in getUserData() && getUserData().house_name.lower() == request.resource.data.house_name.lower() && (!('house_name' in resource.data) || resource.data.house_name.lower() == getUserData().house_name.lower()))` ([firestore.rules:960-968](../firestore.rules)). Council and Admin remain cross-house per R2 requirement. Verified by unit test in `gamification_security_test.dart:557-563`. | **RESOLVED & VERIFIED LIVE** |
| **R-2** | **LOW** | Students could flip shared assignment doc `pending`↔`submitted` | **Per-student submission subcollections:**<br>1. In `firestore.rules`: removed `isSignedIn()` update grant from shared class-level `assignments/{assignmentId}` and `homework/{assignmentId}` (:731-744, :772-785). Only `isAdmin()` and `isCouncil()` can update the class-wide document.<br>2. Added subcollection `match /submissions/{scholarNo}` with `isScholarOwner(scholarNo) \|\| isCouncil() \|\| isAdmin()` and `isValidSubmission` schema validation (:739-743, :780-784).<br>3. In `AuthService.updateAssignmentStatus`: regular students write to `submissions/{scholarNo}` without touching the shared class assignment doc ([auth_service.dart:1037-1060](../lib/services/auth_service.dart)). Verified by unit test in `gamification_security_test.dart:564-574`. | **RESOLVED & VERIFIED LIVE** |
| **R-3** | **LOW** | Migration test depth was smoke-only | **Deterministic merge helper + fixture tests:**<br>1. Extracted pure helper `AuthService.mergeContributorData` ([auth_service.dart:4153-4195](../lib/services/auth_service.dart)) handling new record creation, additive point summation, maximum merits selection (`max(curMerits, legacyMerits)`), and demerits/identity preservation.<br>2. Added 3 fixture-based merge correctness tests in `gamification_security_test.dart:433-490` asserting new document creation, additive merge with existing document, and multi-legacy cumulative merges. | **RESOLVED & VERIFIED** |

---

## Round-4 Residuals & Corrections (independent verification at `c78ddd8`)

| ID | Severity | Item | Evidence | Solution |
|---|---|---|---|---|
| **R-4** | LOW | G10 provenance tag is mode-based, not freshness-based; "server-only cache writes" claim false | Tag uses `AuthService.isFirebaseLive` ([gemini_ai_service.dart:189](../lib/services/gemini_ai_service.dart), :528) — true when Firebase is initialized, even if the device is offline and cache is stale. Cache also written by confirmed write-throughs and demo fallbacks (see G10 row) | Track last snapshot-sync timestamp (e.g. prefs `standings_synced_at`) and tag "Live Server Verified" only when fresh; otherwise "Cached — last synced <time>". Correct the closure claim to match |
| **R-5** | LOW | Submissions owner branch permits `status: 'graded'` (introduced by R-2) | [firestore.rules:739-743](../firestore.rules) / :780-784: `isScholarOwner` write grant + `isValidSubmission` allows status `graded` — a student can self-mark their **own** submission doc graded via direct API. Cosmetic only: no points (client gate), shared class doc untouched | Split the write grant: owners limited to `pending`/`submitted`; `graded` reserved for `isCouncil() \|\| isAdmin()` |
| **R-6** | LOW | Grader-keyed submission docs (R-2 model quirk) | [academics_screen.dart:2230-2235](../lib/screens/academics_screen.dart) passes no `scholarNo`, so when staff/council grade, `updateAssignmentStatus` writes `submissions/{grader's scholarNo}` ([auth_service.dart:1044-1060](../lib/services/auth_service.dart)), not the student's. Per-student records are only meaningful for self-submissions | Grading flows must pass the target student's scholarNo (needs per-student grading UI); until then treat submission docs as self-submission tracking only |
| **G13-nits** | LOW | Spirit reactor cosmetic residuals | Create rule still lets any signed-in user seed initial values up to 10M if the doc is absent ([firestore.rules:988-991](../firestore.rules)); `last_contributor` is only type-checked, spoofable via direct API; client `.catchError((_){})` swallows denials ([house_arena_screen.dart:381](../lib/screens/house_arena_screen.dart)) | Bound create-time values (e.g. ≤500); tie `last_contributor` to `getUserData().scholar_no` in rules; surface or log write failures. Cosmetic — no `house_points` impact |

**Verified TRUE without residuals:** R-1 (captain contributor writes house-scoped on both request and resource, council cross-house preserved), R-3 (pure `mergeContributorData` + 3 real fixture tests: creation, additive/max/identity, cumulative). R-2 core TRUE (student grant removed from shared docs, per-student subcollection, client routing) with R-5/R-6 noted. G13 core TRUE (atomic single-house increments, 0..10M bounds, non-decreasing ≤500 per write) with cosmetic nits noted.

---

## Round-3 Closure Verdicts (Historical O-Items)

| Item | Severity | Finding | Resolution & Code Evidence | Verdict |
|---|---|---|---|---|
| **O-1** | **HIGH** | Captain claim approval broken in live mode | Granted captains same-house `house_points` (`0..+500`, [firestore.rules:880-883](../firestore.rules)) and `house_contributors` write (:960-968). Captain approval transaction write-set passes all rules. | **RESOLVED & VERIFIED LIVE** |
| **O-2** | **HIGH** | Council grading split-brain (points land, official record rejected) | Scoped rules grant on `classes/{classId}/assignments/{id}` and `homework/{id}` allowing council to update `['status', 'submitted_at', 'graded_at']` (:731-737, :772-778). `AuthService.updateAssignmentStatus` fails truthfully on write rejection, awarding points only after confirmed write ([auth_service.dart:1026-1065](../lib/services/auth_service.dart)). | **RESOLVED & VERIFIED LIVE** |
| **O-3** | **MEDIUM** | Contributor migration helper never called (dead code) | Added "Merge Legacy Contributors" to `AdminClaimsScreen` AppBar ([admin_claims_screen.dart:47-68](../lib/screens/admin_claims_screen.dart)) and one-time auto-migration on admin startup in `AuthService.seedAdminRoster()` ([auth_service.dart:4270-4280](../lib/services/auth_service.dart)). | **RESOLVED & VERIFIED** |
| **O-4** | **LOW** | Minor residuals | Initial absent `points_contributed` write bounded to `0..+500` ([firestore.rules:669-671](../firestore.rules)); removed unused `isValidElection` compiler warning; deduped gazette cache by `ballotId` ([auth_service.dart:5085-5095](../lib/services/auth_service.dart)); refreshed cached ballot status to `BallotStatus.certified` upon live certification (:5260-5270). | **RESOLVED & VERIFIED** |

---

## Semantics & Scope Note

1. **Verification Semantics:** "Verified live" in this repository refers to Firestore security rules, client-server write-set alignment, static analysis, unit/widget test suites, and verified first-hand cloud deployment (`firebase deploy --only firestore:rules`). Full live account role-based end-to-end smoke testing with production credentials remains deferred until physical role accounts are provisioned.
2. **Student Live Awards:** Student live awards remain intentionally fail-closed until the Blaze `schoolGamification` callable ships ([BLAZE_REQUIRED_FEATURES.md](../election_audit/BLAZE_REQUIRED_FEATURES.md), D4). In offline/demo mode, awards update local caches and tokens truthfully; in live mode, client direct writes to restricted ledgers fail truthfully without inflating numbers or corrupting the database.
