# Points Remediation — Verification Log & Open Items

Independent verification of the remediation reports.
- **Round 1:** `59048ad` (P0 report).
- **Round 2:** `cf1a1ac` (attachment report covering P-1/P-2/P-3, F-1/F-2/F-3, U-1, R1, G4, G6).
- **Round 3:** `eae5f6b` (O-1/O-2/O-3/O-4 closure report).
- **Round 4:** `c78ddd8` (G10/G13/R-1/R-2/R-3 closure report).
- **Round 5:** `6c6f7bc` (R-4/R-5/R-6/G13-nits closure report). Independently verified 2026-11-08: diffs checked line-by-line, all suites re-run first-hand (29/29 gamification + 32/32 election = 61/61, 262/262 widget, analyze 20 infos / 0 errors / 0 warnings), deploy re-verified ("already up to date, skipping upload" — cloud ruleset matches repo, 0 compiler warnings), push confirmed (HEAD == origin/mustafa1 == `6c6f7bc`). **Correction:** the round-5 rewrite of this file cited Round 5 as `0dbfa20` — that object does not exist in the repository (`git cat-file -t 0dbfa20` → fatal). The actual round-5 commit is `6c6f7bc`.

**Round-5 Overall Verdict (independent audit, 2026-11-08):** **R-4 TRUE, R-5 TRUE, R-6 TRUE; G13-nits PARTIAL.** The round-5 headline "ALL FINDINGS & ALL RESIDUALS FULLY RESOLVED" was overbroad: the `last_contributor` binding fails open for accounts without a user doc, so attribution spoofing is still possible for those accounts (new residual **R-7**, open). Two minor nits also remain (R-4 stamp default, R-5 owner downgrade) — documented with solutions below.
- **G10 / R-4:** TRUE — sync timestamps (`cached_standings_synced_at`) persisted in `AuthService.cacheHouseStandings` and freshness-gated AI provenance in `GeminiAiService` (<15 min + live: "Live Server Verified", else "Cached Offline" / "Offline Baseline"). Minor nit: the `syncedAt ?? DateTime.now()` default lets write-through/demo callers stamp fresh times too (see N-1).
- **R-5:** TRUE — `isScholarOwner` on `submissions/{scholarNo}` restricted to `status in ['pending', 'submitted']`; `graded` reserved for `isAdmin() || isCouncil()`. Minor nit: owners can still downgrade their own staff-graded doc back to `submitted` (see N-2).
- **R-6:** TRUE — `submissions/` docs written only for student self-submissions or explicit student targets; grader-keyed pollution prevented.
- **G13-nits:** PARTIAL — create-time seed ceiling `0..500` TRUE, rejection logging TRUE; `last_contributor` binding NOT fail-closed (R-7).
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
| **G13 & G13-nits** | **LOW** | Spirit reactor unbounded/spoofable write & create seed | **Atomic increment + rules validator bounds + create ceiling:**<br>1. In `HouseArenaScreen._incrementSpiritMeter`: replaced absolute 4-house write with atomic `FieldValue.increment(delta)` for the **caller's house only** ([house_arena_screen.dart:363-388](../lib/screens/house_arena_screen.dart)). Rejection logging replaces silent swallow (:384-386).<br>2. In `firestore.rules`: added numeric bounds `0..10,000,000` to `isValidSpiritReactor` (:571-579). In `system_config/house_spirit_reactor`, enforced non-decreasing increments bounded to `0..+500` per write, bounded initial create seeds to `0..500`, and tied `last_contributor` to `getUserData().scholar_no` on create and update (:997-1018). Unit test verified in `gamification_security_test.dart:587-599`. **Audit correction:** the `last_contributor` binding at :1005/:1016 fails open via `!hasUserDoc() || !('scholar_no' in getUserData())` — see R-7. | **PARTIAL — R-7 OPEN** |
| **R-1** | **LOW** | Captain `house_contributors` grant was not house-scoped | **Strict house scoping for captains:**<br>In `firestore.rules`: updated `match /house_contributors/{scholarNo}` write rule. Captain branch now strictly enforces same-house match: `(isCaptain() && hasUserDoc() && 'house_name' in getUserData() && getUserData().house_name.lower() == request.resource.data.house_name.lower() && (!('house_name' in resource.data) || resource.data.house_name.lower() == getUserData().house_name.lower()))` ([firestore.rules:960-968](../firestore.rules)). Council and Admin remain cross-house per R2 requirement. Verified by unit test in `gamification_security_test.dart:557-563`. | **RESOLVED & VERIFIED LIVE** |
| **R-2 & R-5** | **LOW** | Students could flip shared assignment doc `pending`↔`submitted` or self-grade | **Per-student submission subcollections + graded status lock:**<br>1. In `firestore.rules`: removed `isSignedIn()` update grant from shared class-level `assignments/{assignmentId}` and `homework/{assignmentId}` (:731-744, :772-785). Only `isAdmin()` and `isCouncil()` can update the class-wide document.<br>2. Added subcollection `match /submissions/{scholarNo}` with `isScholarOwner(scholarNo) && request.resource.data.status in ['pending', 'submitted']`, strictly reserving `status: 'graded'` for `isAdmin() \|\| isCouncil()` ([firestore.rules:740-747, 785-792](../firestore.rules)).<br>3. Unit test verified in `gamification_security_test.dart:572-585`. | **RESOLVED & VERIFIED LIVE** |
| **R-3** | **LOW** | Migration test depth was smoke-only | **Deterministic merge helper + fixture tests:**<br>1. Extracted pure helper `AuthService.mergeContributorData` ([auth_service.dart:4153-4195](../lib/services/auth_service.dart)) handling new record creation, additive point summation, maximum merits selection (`max(curMerits, legacyMerits)`), and demerits/identity preservation.<br>2. Added 3 fixture-based merge correctness tests in `gamification_security_test.dart:433-490` asserting new document creation, additive merge with existing document, and multi-legacy cumulative merges. | **RESOLVED & VERIFIED** |
| **R-6** | **LOW** | Grader-keyed submission docs in assignment grading | **Submission path isolation:**<br>In `AuthService.updateAssignmentStatus`: guarded `submissions/{sNo}` write with `final isTargetedSubmission = (!canGrade && sNo.isNotEmpty) || (canGrade && scholarNo != null && scholarNo.trim().isNotEmpty);` ([auth_service.dart:1045-1065](../lib/services/auth_service.dart)). Regular students write to their own submission doc; graders without an explicit target student scholar number update the assignment without generating grader-keyed submission records. | **RESOLVED & VERIFIED** |

---

## Residual Status Summary (audited 2026-11-08 at `6c6f7bc`)

- **R-4 (Closed, minor nit N-1):** Freshness-based AI context tagging implemented and unit-tested. Nit: stamp default lets non-snapshot callers refresh the timestamp (N-1 below).
- **R-5 (Closed, minor nit N-2):** Owner self-`graded` blocked in `firestore.rules`. Nit: owner can downgrade own `graded` doc back to `submitted` (N-2 below).
- **R-6 (Closed):** Grader-keyed submission pollution prevented by `isTargetedSubmission` ([auth_service.dart:1061-1062](../lib/services/auth_service.dart)).
- **G13-nits (PARTIAL — R-7 OPEN):** Seed ceiling and logging done; `last_contributor` binding fails open for doc-less accounts.

---

## Round-5 Open Residuals & Nits (with solutions)

### R-7 (LOW, OPEN) — Spirit-reactor `last_contributor` binding fails open

**Claim audited:** "binding `last_contributor` to authenticated user doc scholar number on create & update" (round-5 report; rules :1005, :1016).

**What's true:** the equality disjunct exists — `request.resource.data.last_contributor == getUserData().scholar_no`.

**What's not done:** the full condition is
`(!('last_contributor' in request.resource.data) || !hasUserDoc() || !('scholar_no' in getUserData()) || request.resource.data.last_contributor == getUserData().scholar_no)`.
The `!hasUserDoc()` and `!('scholar_no' in getUserData())` disjuncts short-circuit to **allow any `last_contributor` value** when the signed-in caller has no `users` doc (or no `scholar_no` field). Any authenticated account without a profile doc can still spoof attribution on the reactor. Conversely, a legit client using the userName fallback ([house_arena_screen.dart:375-377](../lib/screens/house_arena_screen.dart) — `effectiveCaller = scholarNo.isNotEmpty ? scholarNo : userName`) is **false-denied** when its user doc does have a `scholar_no` but the local cache missed it. Impact is low (bounded fun-meter attribution, not a points ledger), but the "bound to authenticated caller" claim is not fail-closed.

**Solution:**
1. Rules (both create :1005 and update :1016): require the doc and field instead of excusing them —
   `(!('last_contributor' in request.resource.data) || (hasUserDoc() && 'scholar_no' in getUserData() && request.resource.data.last_contributor == getUserData().scholar_no))`.
   Omitting the field stays allowed; supplying it without a profile doc becomes a denial (fail closed).
2. Client ([house_arena_screen.dart:363-388](../lib/screens/house_arena_screen.dart)): only include `last_contributor` when `scholarNo.trim().isNotEmpty`; otherwise omit the key entirely instead of sending `userName`.
3. Test: extend the G13 rules-contract test to assert the binding contains `hasUserDoc() &&` (conjunctive, not `!hasUserDoc() ||`), locking the fail-closed form.

### N-1 (LOW, nit) — `cacheHouseStandings` stamp default refreshes freshness for non-snapshot writes

`cacheHouseStandings(map, {DateTime? syncedAt})` stamps `syncedAt ?? DateTime.now()` ([auth_service.dart:460](../lib/services/auth_service.dart)). Besides the home-screen server snapshot ([home_screen.dart:3053](../lib/screens/home_screen.dart)), it is called by write-through/demo paths with no argument: `incrementCachedHousePoints` (:504), trophy write-throughs (:6180, :6206), sports-merit cache (:6337). In demo mode the AI tag stays honest (`isFresh` requires `isFirebaseLive`), but a demo/write-through stamp followed by a demo→live switch within 15 minutes can label locally-fabricated standings "Live Server Verified" until the first real snapshot arrives.

**Solution:** remove the `?? DateTime.now()` default; stamp only when the caller passes an explicit `syncedAt`. Home screen passes `DateTime.now()` (true server snapshot); write-through paths pass it only when `_isFirebaseLive` and the server transaction was confirmed; demo paths pass nothing (timestamp unchanged).

### N-2 (LOW, nit) — Submission owner can downgrade own `graded` doc

The owner branch checks only `request.resource.data.status in ['pending', 'submitted']` ([firestore.rules:745](../firestore.rules), :790) — no `resource.data` guard. A student whose submission was graded by staff can update it back to `submitted` (request status is allowed), erasing the graded state on their own doc. Self-**upgrade** to `graded` (the actual R-5 finding) is blocked; this is the reverse direction.

**Solution:** split `allow create, update` on `submissions/{scholarNo}`; on `update`, owner branch additionally requires `resource.data.status in ['pending', 'submitted']` (a `graded` doc becomes owner-immutable; admin/council retain full rights). Add a rules-contract assertion for the resource-side guard.

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
