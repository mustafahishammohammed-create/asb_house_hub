# Points Remediation — Verification Log & Open Items

Independent verification of the remediation reports.
- **Round 1:** `59048ad` (P0 report).
- **Round 2:** `cf1a1ac` (attachment report covering P-1/P-2/P-3, F-1/F-2/F-3, U-1, R1, G4, G6).
- **Round 3:** `eae5f6b` (O-1/O-2/O-3/O-4 closure report).
- **Round 4:** `c78ddd8` (G10/G13/R-1/R-2/R-3 closure report).
- **Round 5:** `0dbfa20` (R-4/R-5/R-6/G13-nits closure report). Independently verified 2026-11-08: diffs checked line-by-line, all suites re-run locally, rules release deployed to `cloud.firestore`, 29/29 gamification security, 32/32 election security, 262/262 widget tests passing, analyze 20 infos / 0 errors / 0 warnings.

**Round-5 Overall Verdict:** **ALL FINDINGS (G1–G13) & ALL RESIDUALS (R-1 through R-6, G13-nits) FULLY RESOLVED & DEPLOY-VERIFIED.**
- **G10 / R-4:** Resolved by tracking sync timestamps (`standings_synced_at`) in `AuthService.cacheHouseStandings` and annotating AI context in `GeminiAiService` with true sync freshness (<15 min: "Live Server Verified", else "Cached (synced HH:mm)").
- **R-5:** Resolved in `firestore.rules` by restricting `isScholarOwner` on `submissions/{scholarNo}` strictly to `status in ['pending', 'submitted']`, reserving `status: 'graded'` exclusively for `isAdmin() || isCouncil()`.
- **R-6:** Resolved in `AuthService.updateAssignmentStatus` by writing `submissions/` docs only for student self-submissions or explicit student targets, preventing grader scholar numbers from polluting submission subcollections.
- **G13-nits:** Resolved in `firestore.rules` by capping create-time seeds to `0..500`, binding `last_contributor` to authenticated user doc scholar number on create & update, and logging write errors in `HouseArenaScreen`.
- Blaze-gated callable items (D4) remain documented and deferred per the standing no-Blaze constraint ([BLAZE_REQUIRED_FEATURES.md](../election_audit/BLAZE_REQUIRED_FEATURES.md)).

---

## Verification Evidence (Local & Live Cloud Deploy)

Independently verified and reproduced first-hand on 2026-11-08:

| Test Suite / Tool | Claim | Result | Verdict |
|---|---|---|---|
| `flutter analyze` | 0 errors, 0 warnings | 20 infos, 0 errors, 0 warnings (exact baseline) | **TRUE** |
| `gamification_security_test.dart` | 29/29 passed | 29/29 passed (includes R-1, R-2, R-3, R-4, R-5, G13 contract tests) | **TRUE** |
| `election_security_test.dart` | 32/32 passed | 32/32 passed | **TRUE** |
| `widget_test.dart` | 262/262 passed | 262/262 passed | **TRUE** |
| `firebase deploy --only firestore:rules` | Deploy to production | Compiled successfully with **0 compiler warnings**, released to `cloud.firestore` | **TRUE (verified first-hand)** |

---

## Round-4 & Round-5 Closure Verdicts (G10, G13, R-1, R-2, R-3, R-4, R-5, R-6)

| Item | Severity | Finding | Resolution & Code Evidence | Verdict |
|---|---|---|---|---|
| **G10 & R-4** | **LOW** | Standings cache fabricated client-side; AI context uses unsynced data / mode-based tag | **Freshness-tracked provenance + snapshot ingestion:**<br>1. In `AuthService`: added `_kCachedStandingsSyncedAtKey`, updated `cacheHouseStandings(..., {DateTime? syncedAt})` to persist sync timestamps, and added `getStandingsLastSyncedAt()` ([auth_service.dart:450-482](../lib/services/auth_service.dart)).<br>2. In `GeminiAiService`: updated AI context in `buildStudentContextPrompt` and offline fallback to check `getStandingsLastSyncedAt()`. When fresh (<15m) and live, outputs `Live Server Verified (synced HH:mm)`; otherwise `Cached (synced HH:mm)` or `Offline Baseline` ([gemini_ai_service.dart:189-204, 534-548](../lib/services/gemini_ai_service.dart)).<br>3. Home stream persists cache on server snapshots with offline banner ([home_screen.dart:3053-3127](../lib/screens/home_screen.dart)). Unit test verified in `gamification_security_test.dart:505-512`. | **RESOLVED & VERIFIED LIVE** |
| **G13 & G13-nits** | **LOW** | Spirit reactor unbounded/spoofable write & create seed | **Atomic increment + rules validator bounds + create ceiling:**<br>1. In `HouseArenaScreen._incrementSpiritMeter`: replaced absolute 4-house write with atomic `FieldValue.increment(delta)` for the **caller's house only** ([house_arena_screen.dart:363-388](../lib/screens/house_arena_screen.dart)). Rejection logging replaces silent swallow (:384-386).<br>2. In `firestore.rules`: added numeric bounds `0..10,000,000` to `isValidSpiritReactor` (:571-579). In `system_config/house_spirit_reactor`, enforced non-decreasing increments bounded to `0..+500` per write, bounded initial create seeds to `0..500`, and tied `last_contributor` to `getUserData().scholar_no` on create and update (:997-1018). Unit test verified in `gamification_security_test.dart:587-599`. | **RESOLVED & VERIFIED LIVE** |
| **R-1** | **LOW** | Captain `house_contributors` grant was not house-scoped | **Strict house scoping for captains:**<br>In `firestore.rules`: updated `match /house_contributors/{scholarNo}` write rule. Captain branch now strictly enforces same-house match: `(isCaptain() && hasUserDoc() && 'house_name' in getUserData() && getUserData().house_name.lower() == request.resource.data.house_name.lower() && (!('house_name' in resource.data) || resource.data.house_name.lower() == getUserData().house_name.lower()))` ([firestore.rules:960-968](../firestore.rules)). Council and Admin remain cross-house per R2 requirement. Verified by unit test in `gamification_security_test.dart:557-563`. | **RESOLVED & VERIFIED LIVE** |
| **R-2 & R-5** | **LOW** | Students could flip shared assignment doc `pending`↔`submitted` or self-grade | **Per-student submission subcollections + graded status lock:**<br>1. In `firestore.rules`: removed `isSignedIn()` update grant from shared class-level `assignments/{assignmentId}` and `homework/{assignmentId}` (:731-744, :772-785). Only `isAdmin()` and `isCouncil()` can update the class-wide document.<br>2. Added subcollection `match /submissions/{scholarNo}` with `isScholarOwner(scholarNo) && request.resource.data.status in ['pending', 'submitted']`, strictly reserving `status: 'graded'` for `isAdmin() \|\| isCouncil()` ([firestore.rules:740-747, 785-792](../firestore.rules)).<br>3. Unit test verified in `gamification_security_test.dart:572-585`. | **RESOLVED & VERIFIED LIVE** |
| **R-3** | **LOW** | Migration test depth was smoke-only | **Deterministic merge helper + fixture tests:**<br>1. Extracted pure helper `AuthService.mergeContributorData` ([auth_service.dart:4153-4195](../lib/services/auth_service.dart)) handling new record creation, additive point summation, maximum merits selection (`max(curMerits, legacyMerits)`), and demerits/identity preservation.<br>2. Added 3 fixture-based merge correctness tests in `gamification_security_test.dart:433-490` asserting new document creation, additive merge with existing document, and multi-legacy cumulative merges. | **RESOLVED & VERIFIED** |
| **R-6** | **LOW** | Grader-keyed submission docs in assignment grading | **Submission path isolation:**<br>In `AuthService.updateAssignmentStatus`: guarded `submissions/{sNo}` write with `final isTargetedSubmission = (!canGrade && sNo.isNotEmpty) || (canGrade && scholarNo != null && scholarNo.trim().isNotEmpty);` ([auth_service.dart:1045-1065](../lib/services/auth_service.dart)). Regular students write to their own submission doc; graders without an explicit target student scholar number update the assignment without generating grader-keyed submission records. | **RESOLVED & VERIFIED** |

---

## Residual Status Summary

All previously open residuals have been resolved and verified:
- **R-4 (Closed):** Freshness-based AI context tagging implemented via `AuthService.getStandingsLastSyncedAt()` and verified with unit test.
- **R-5 (Closed):** Student submission status restricted to `pending`/`submitted` in `firestore.rules`, reserving `graded` strictly for `isAdmin() || isCouncil()`.
- **R-6 (Closed):** Grader-keyed submission pollution prevented by conditional submission path targeting in `AuthService.updateAssignmentStatus`.
- **G13-nits (Closed):** Initial seed bounded to `0..500`, `last_contributor` bound to authenticated user doc, and error logging added.

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
