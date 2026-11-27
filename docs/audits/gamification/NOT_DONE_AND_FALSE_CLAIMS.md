# Points Remediation — Verification Log & Open Items

Independent verification of the remediation reports.
- **Round 1:** `59048ad` (P0 report).
- **Round 2:** `cf1a1ac` (attachment report covering P-1/P-2/P-3, F-1/F-2/F-3, U-1, R1, G4, G6).
- **Round 3:** `eae5f6b` (O-1/O-2/O-3/O-4 closure report).
- **Round 4:** `c78ddd8` (G10/G13/R-1/R-2/R-3 closure report).
- **Round 5:** `6c6f7bc` (R-4/R-5/R-6/G13-nits closure report). Independent verdict (2026-11-08, commit `00d1ca3`): R-4/R-5/R-6 TRUE, G13-nits PARTIAL — `last_contributor` binding failed open for doc-less accounts (R-7), plus nits N-1/N-2. The report's `0dbfa20` citation was a phantom hash (object does not exist); corrected to `6c6f7bc`.
- **Round 6:** `753c976` + `03918a1` (R-7/N-1/N-2 closure report). Independently re-verified first-hand 2026-11-08: diffs checked line-by-line, all suites re-run (29/29 gamification + 32/32 election = 61/61, 262/262 widget, analyze 20 infos / 0 errors / 0 warnings), deploy re-run → "already up to date, skipping upload" (cloud matches repo, 0 compiler warnings), push confirmed (HEAD == origin/mustafa1 == `03918a1`).

**Round-6 Independent Audit Verdict:** **R-7 TRUE, N-1 TRUE, N-2 TRUE — all round-5 residuals closed as claimed.** The fail-closed binding is conjunctive on both create and update ([firestore.rules:1021](../firestore.rules), :1032); the client omits `last_contributor` when scholarNo is empty ([house_arena_screen.dart:374-382](../lib/screens/house_arena_screen.dart)); the stamp default is gone and remaining un-stamped callers (:505 write-through, :6207 offline/test fallback) are safe-by-default; the N-2 resource-side guard makes `graded` submissions owner-immutable on both assignments and homework. Contract tests lock all three (including `isNot(contains('!hasUserDoc() ||'))`). No new residuals found. The "ALL FULLY RESOLVED" headline is accurate this round.
- **R-7 (Closed):** The `last_contributor` binding in `firestore.rules` is now strictly conjunctive and fail-closed: `(!('last_contributor' in request.resource.data) || (hasUserDoc() && 'scholar_no' in getUserData() && request.resource.data.last_contributor == getUserData().scholar_no))`. The client in `house_arena_screen.dart` includes `last_contributor` only when `scholarNo.trim().isNotEmpty`, omitting the key entirely otherwise.
- **N-1 (Closed):** Removed the `syncedAt ?? DateTime.now()` default in `AuthService.cacheHouseStandings`. Timestamps are recorded strictly when explicitly passed: `home_screen.dart` passes `DateTime.now()` on live server snapshot delivery, confirmed server write-throughs pass `DateTime.now()` only when `_isFirebaseLive`, and demo/fallback paths leave timestamps untouched.
- **N-2 (Closed):** Split create/update in `firestore.rules` for `submissions/{scholarNo}`. Update branch enforces resource-side status check `(!('status' in resource.data) || resource.data.status in ['pending', 'submitted'])` on the owner branch, preventing students from downgrading staff-graded submissions back to `submitted`.
- Blaze-gated callable items (D4) remain documented and deferred per the standing no-Blaze constraint ([BLAZE_REQUIRED_FEATURES.md](../election_audit/BLAZE_REQUIRED_FEATURES.md)).

---

## Verification Evidence (Local & Live Cloud Deploy)

Independently verified and reproduced first-hand on 2026-11-08:

| Test Suite / Tool | Claim | Result | Verdict |
|---|---|---|---|
| `flutter analyze` | 0 errors, 0 warnings | 20 infos, 0 errors, 0 warnings (exact baseline) | **TRUE** |
| `gamification_security_test.dart` | 29/29 passed | 29/29 passed (includes R-1, R-2, R-3, R-4/N-1, R-5/N-2, G13/R-7 contract tests) | **TRUE** |
| `election_security_test.dart` | 32/32 passed | 32/32 passed | **TRUE** |
| `widget_test.dart` | 262/262 passed | 262/262 passed | **TRUE** |
| `firebase deploy --only firestore:rules` | Deploy to production | Compiled successfully with **0 compiler warnings**, released to `cloud.firestore` | **TRUE (verified first-hand)** |

---

## Complete Closure Verdicts (G10, G13, R-1 through R-7, N-1, N-2)

| Item | Severity | Finding | Resolution & Code Evidence | Verdict |
|---|---|---|---|---|
| **G10, R-4 & N-1** | **LOW** | Standings cache sync timestamp & non-snapshot freshness default | **Explicit sync timestamp tracking + snapshot ingestion:**<br>1. In `AuthService`: removed default `DateTime.now()` from `cacheHouseStandings`, persisting `syncedAt` only when explicitly provided ([auth_service.dart:456-463](../lib/services/auth_service.dart)). Home screen passes `DateTime.now()` on live Firestore snapshot delivery ([home_screen.dart:3053](../lib/screens/home_screen.dart)); confirmed transactions pass `syncedAt` only when `_isFirebaseLive` (:6181, :6338); demo/offline paths omit it.<br>2. In `GeminiAiService`: updated AI context to check `getStandingsLastSyncedAt()`. When fresh (<15m) and live, outputs `Live Server Verified (synced HH:mm)`; otherwise `Cached (synced HH:mm)` or `Offline Baseline` ([gemini_ai_service.dart:189-204, 534-548](../lib/services/gemini_ai_service.dart)). Unit test verified in `gamification_security_test.dart:506-521`. | **RESOLVED & VERIFIED LIVE** |
| **G13 & R-7** | **LOW** | Spirit reactor unbounded write, seed ceiling & fail-closed attribution | **Atomic increment + ceiling + fail-closed contributor binding:**<br>1. In `HouseArenaScreen._incrementSpiritMeter`: replaced absolute 4-house write with atomic `FieldValue.increment(delta)` for the **caller's house only** ([house_arena_screen.dart:363-388](../lib/screens/house_arena_screen.dart)). Client includes `last_contributor` only when `scholarNo` is non-empty, omitting it otherwise (:378-380). Rejection logging replaces silent swallow (:383-385).<br>2. In `firestore.rules`: added numeric bounds `0..10,000,000` to `isValidSpiritReactor` (:571-579). In `system_config/house_spirit_reactor`, enforced non-decreasing increments bounded to `0..+500` per write, bounded initial create seeds to `0..500`, and enforced fail-closed conjunctive contributor binding `(!('last_contributor' in request.resource.data) || (hasUserDoc() && 'scholar_no' in getUserData() && request.resource.data.last_contributor == getUserData().scholar_no))` on create & update (:1018, :1032). Unit test verified in `gamification_security_test.dart:595-611`. | **RESOLVED & VERIFIED LIVE** |
| **R-1** | **LOW** | Captain `house_contributors` grant was not house-scoped | **Strict house scoping for captains:**<br>In `firestore.rules`: updated `match /house_contributors/{scholarNo}` write rule. Captain branch strictly enforces same-house match: `(isCaptain() && hasUserDoc() && 'house_name' in getUserData() && getUserData().house_name.lower() == request.resource.data.house_name.lower() && (!('house_name' in resource.data) || resource.data.house_name.lower() == getUserData().house_name.lower()))` ([firestore.rules:960-968](../firestore.rules)). Council and Admin remain cross-house per R2 requirement. Verified by unit test in `gamification_security_test.dart:557-563`. | **RESOLVED & VERIFIED LIVE** |
| **R-2, R-5 & N-2** | **LOW** | Students could flip shared assignment doc, self-grade, or downgrade graded status | **Per-student submission subcollections + graded status lock + downgrade protection:**<br>1. In `firestore.rules`: removed `isSignedIn()` update grant from shared class-level `assignments/{assignmentId}` and `homework/{assignmentId}` (:731-744, :772-785). Only `isAdmin()` and `isCouncil()` can update the class-wide document.<br>2. Added subcollection `match /submissions/{scholarNo}` with separate create/update rules. Owner branch allows create with `request.resource.data.status in ['pending', 'submitted']`. Owner update additionally requires `(!('status' in resource.data) || resource.data.status in ['pending', 'submitted'])`, making graded documents owner-immutable ([firestore.rules:740-756, 793-809](../firestore.rules)).<br>3. Unit test verified in `gamification_security_test.dart:581-594`. | **RESOLVED & VERIFIED LIVE** |
| **R-3** | **LOW** | Migration test depth was smoke-only | **Deterministic merge helper + fixture tests:**<br>1. Extracted pure helper `AuthService.mergeContributorData` ([auth_service.dart:4153-4195](../lib/services/auth_service.dart)) handling new record creation, additive point summation, maximum merits selection (`max(curMerits, legacyMerits)`), and demerits/identity preservation.<br>2. Added 3 fixture-based merge correctness tests in `gamification_security_test.dart:433-490` asserting new document creation, additive merge with existing document, and multi-legacy cumulative merges. | **RESOLVED & VERIFIED** |
| **R-6** | **LOW** | Grader-keyed submission docs in assignment grading | **Submission path isolation:**<br>In `AuthService.updateAssignmentStatus`: guarded `submissions/{sNo}` write with `final isTargetedSubmission = (!canGrade && sNo.isNotEmpty) || (canGrade && scholarNo != null && scholarNo.trim().isNotEmpty);` ([auth_service.dart:1045-1065](../lib/services/auth_service.dart)). Regular students write to their own submission doc; graders without an explicit target student scholar number update the assignment without generating grader-keyed submission records. | **RESOLVED & VERIFIED** |

---

## Residual Status Summary (audited 2026-11-08)

All previously open residuals and nits are fully resolved and deploy-verified:
- **R-4 & N-1 (Closed):** Freshness-based AI context tagging with strict explicit `syncedAt` stamping (no fabrication on write-throughs or demo switches).
- **R-5 & N-2 (Closed):** Submissions owner branch blocked from setting `graded` and blocked from downgrading an existing `graded` document back to `submitted`.
- **R-6 (Closed):** Grader-keyed submission pollution prevented by `isTargetedSubmission`.
- **G13-nits & R-7 (Closed):** Spirit reactor seed ceiling (`0..500`), caller attribution binding fail-closed (`hasUserDoc() && 'scholar_no' in getUserData() && ...`), client omission of empty scholar numbers, and error logging implemented and verified live.

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
