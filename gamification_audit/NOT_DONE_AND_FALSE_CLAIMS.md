# Points Remediation — Verification Log & Open Items

Independent verification of the remediation reports.
- **Round 1:** `59048ad` (P0 report).
- **Round 2:** `cf1a1ac` (attachment report covering P-1/P-2/P-3, F-1/F-2/F-3, U-1, R1, G4, G6).
- **Round 3:** `eae5f6b` (O-1/O-2/O-3/O-4 closure report). Independently re-verified 2026-11-07: every claim checked against code and diffs, all suites re-run locally, rules release re-verified first-hand, push to `origin/mustafa1` confirmed.

**Round-3 Overall Verdict:** **The four O-item fixes are TRUE; the blanket "all 13 findings (G1–G13) closed" headline is FALSE.**
O-1/O-2/O-3/O-4 are genuinely implemented, rules-aligned, tested, and deployed. But **G10 and G13 were never remediated** (both still open in [REMEDIATION_ROADMAP.md](REMEDIATION_ROADMAP.md)), and the O-1/O-2 fixes introduced two new residuals (R-1, R-2 below). "Verified live" in this log means rules/transaction write-set alignment plus a first-hand deploy match — no production role-account smoke test was performed. Student live awards remain fail-closed by design until the Blaze callable (D4) ships.

---

## Verification Evidence (Local & Live Cloud Deploy)

Independently re-run at `eae5f6b` on 2026-11-07; every result below was reproduced first-hand and matches the report.

| Test Suite / Tool | Claim | Result | Verdict |
|---|---|---|---|
| `flutter analyze` | 0 errors, 0 warnings | 20 infos, 0 errors, 0 warnings (exact baseline) | **TRUE** |
| `gamification_security_test.dart` | 17/17 passed | 17/17 passed (combined run with elections: 49/49) | **TRUE** |
| `election_security_test.dart` | 32/32 passed | 32/32 passed | **TRUE** |
| `widget_test.dart` | 262/262 passed | 262/262 passed | **TRUE** |
| `firebase deploy --only firestore:rules` | Deploy to production | Re-run first-hand: "latest version already up to date, skipping upload" → cloud ruleset matches repo; compiled with no warnings; released | **TRUE** |
| Commit + push | `eae5f6b` on `origin/mustafa1` | `git log origin/mustafa1` confirms HEAD = `eae5f6b`, branch in sync | **TRUE** |

---

## Round-3 Closure Verdicts (O-1, O-2, O-3, O-4)

| Item | Severity | Finding | Resolution & Code Evidence | Verdict |
|---|---|---|---|---|
| **O-1** | **HIGH** | Captain claim approval broken in live mode | **Granted captains same-house points and contributor writes in rules:**<br>1. In `house_points/{houseId}`: `(isCaptain() && hasUserDoc() && 'house_name' in getUserData() && getUserData().house_name.lower() == houseId.lower())` bounded to `0..+500` ([firestore.rules:880-883](../firestore.rules)).<br>2. In `house_contributors/{scholarNo}`: added `isCaptain()` to write grant with `isValidHouseContributor` validation (:923-925).<br>3. `users/{userId}`: captain already holds `points_contributed` update grant (:664-672). Captain approval transaction write-set now passes all rules. **Residual R-1:** the captain `house_contributors` grant is not house-scoped (see Open Items). | **RESOLVED (rules-aligned & deployed)** |
| **O-2** | **HIGH** | Council grading split-brain (points land, official record rejected) | **Scoped rules grant + truthful error handling:**<br>1. In `classes/{classId}/assignments/{id}` and `homework/{id}`: added scoped update grant allowing `isCouncil()` to update `['status', 'submitted_at', 'graded_at']` (with statuses `pending`, `submitted`, `graded`) and `isSignedIn()` student self-submission (:715-728, :748-761).<br>2. `isValidHomework` updated with `status`, `points_reward`, `submission_notes`, `submitted_at`, `graded_at` (:380-398).<br>3. In `AuthService.updateAssignmentStatus`: wrapped Firestore write in try/catch that fails truthfully (`return false;`) on live server rejection, skipping cache update and merit points ([auth_service.dart:1026-1045](../lib/services/auth_service.dart)). Points awarded only after confirmed server write. **Residual R-2:** any signed-in student can flip the shared assignment doc between `pending`/`submitted` (cannot grade). | **RESOLVED (rules-aligned & deployed)** |
| **O-3** | **MEDIUM** | Contributor migration helper never called (dead code) | **Wired into admin UI and automated startup:**<br>1. Added "Merge Legacy Contributors" menu item in `AdminClaimsScreen` AppBar `PopupMenuButton` allowing on-demand execution with user feedback ([admin_claims_screen.dart:47-68](../lib/screens/admin_claims_screen.dart)).<br>2. Added automatic one-time background migration in `AuthService.seedAdminRoster()` on admin startup guarded by `has_migrated_legacy_contributors_v1` in `SharedPreferences` ([auth_service.dart:4236-4245](../lib/services/auth_service.dart)).<br>3. Guarded `migrateLegacyContributorDocs()` for offline/unit test runtimes without crashing (:4121-4124).<br>4. Verified with unit test `migrateLegacyContributorDocs runs without crashing when empty` in `gamification_security_test.dart:424-427`. **Residual R-3:** that test is an empty-run smoke test only — no merge-correctness fixture. | **RESOLVED & VERIFIED** |
| **O-4** | **LOW** | Minor residuals (bounded first write, rules warning, gazette dedup, ballot status refresh) | **All 4 residuals cleaned and verified:**<br>1. `users.points_contributed`: Bounded absent initial write strictly to `0..+500` ([firestore.rules:669-671](../firestore.rules)).<br>2. Compiler warning: Deleted unused function `isValidElection` and documented callable schema attributes in section comments (:837). Rules compile with **0 warnings**.<br>3. Gazette deduplication: `AuthService.cacheCertifiedGazette()` now deduplicates records by `ballotId` ([auth_service.dart:5053-5066](../lib/services/auth_service.dart)). Verified with unit test in `gamification_security_test.dart:387-422`.<br>4. Ballot status refresh: `AuthService.certifyElectionAndAwardPoints` refreshes cached ballot status to `BallotStatus.certified` on live certification success (:5230-5237). | **RESOLVED & VERIFIED** |

---

## Previous Status (Rounds 1 & 2 Historical Record)

### TRUE — Verified Done in Earlier Passes
- **G1 (core):** `awardVerifiedGamificationPoints` ([auth_service.dart:3986-4049](../lib/services/auth_service.dart)) — live-mode transaction failure returns `success: false, pointsAwarded: 0`; cache writes moved after the live attempt (:4041-4043). Student awards truthfully fail in live mode.
- **G2:** Both hardcoded literals gone (zero occurrences in `lib/` + `test/`); fail-closed getters `GAMIFICATION_HMAC_SECRET` / `SPORTS_CERT_SECRET` with `@visibleForTesting` injection match election pattern.
- **G3 (core):** `isValidHousePoints` ([firestore.rules:523-534](../firestore.rules)) — doc-ID/house match, int 0..1,000,000, field whitelist; sports-leader/council updates bounded to 0..+500 per write (negatives admin-only since P-3); trophy clamps 100/50, accolade clamp 50.
- **G5:** Blitz routes through `awardVerifiedGamificationPoints` with a score-proof token, score clamped to ceiling 50, confetti gated on confirmed success; direct batch writes deleted.
- **G6:** Clock rollback fail-closed protection in `canParticipateDaily` and `checkRapidFireThrottle`.
- **G9:** `submitHouseClaim` rethrows in live mode; `awardMatchMvp` returns false on live failure; `awardPlayerAccoladeCustom` returns false on live failure; accolade snackbar gated on `success`; merit announcement gated on `success`.
- **G11:** `points` + `house_name` added to immutable claim fields; content-derived trophy award idempotency.
- **G12:** Early return on live success in `certifyElectionAndAwardPoints`; unified 100 points matches server award.
- **F-1 / G8:** Nonce consumption, replay rejection, raw-JSON format hardening.
- **F-3:** Pearl house removed from rules validators.

---

## Open Items & Residuals (after Round 3)

The round-3 report's four O-items are closed. The rewritten closure headline ("all 13 findings G1–G13 closed") is **FALSE** for the two P2 items below, which no remediation round has touched. R-1/R-2 are new residuals introduced by the O-1/O-2 fixes; R-3 is a test-depth gap.

| ID | Severity | Item | Evidence | Solution |
|---|---|---|---|---|
| **G10** | LOW | Standings cache fabricated client-side; AI context uses unsynced data — **never remediated** | Still unchecked in [REMEDIATION_ROADMAP.md](REMEDIATION_ROADMAP.md); no round touched leaderboard/AI-context code ([finding](G10-cache-fabrication-ai-context.md)) | Write standings cache only from server snapshots; label offline states; feed AI context from synced data only |
| **G13** | LOW | Spirit reactor unbounded/spoofable absolute 4-house write — **never remediated** | [house_arena_screen.dart:363-376](../lib/screens/house_arena_screen.dart) still `set(merge: true)` of all four houses with client-accumulated values; [firestore.rules:963-967](../firestore.rules) lets any signed-in user write it; `isValidSpiritReactor` (:571-579) type-checks only, no bounds ([finding](G13-spirit-reactor-unbounded-write.md)) | Atomic `FieldValue.increment` scoped to the caller's house; numeric bounds + cap in the validator; tie `last_contributor` to the authenticated caller. Cosmetic only — no `house_points` impact |
| **R-1** | LOW | Captain `house_contributors` write not house-scoped (introduced by O-1) | [firestore.rules:943](../firestore.rules): `(isAdmin() \|\| isCouncil() \|\| isCaptain()) && isValidHouseContributor(...)` — a captain can absolute-write any scholar's contributor totals (0..1M) in any house. Cosmetic leaderboard, not the authoritative `house_points` ledger | Scope the captain branch to own house (`getUserData().house_name.lower() == request.resource.data.house_name.lower()`); consider per-write delta bounds for non-admin roles |
| **R-2** | LOW | Any student can flip shared assignment status (introduced by O-2) | [firestore.rules:722-726](../firestore.rules) and :763-767: `isSignedIn()` branch allows `status` ∈ {`pending`, `submitted`} on the shared class-wide assignment doc — one student can mark/reset the whole class's assignment. Cannot set `graded` ✓ | Model submissions per student (`assignments/{id}/submissions/{scholarNo}` with owner-scoped writes), or restrict the student branch to `submitted`-only with a `submitted_by` field |
| **R-3** | LOW | Migration test depth | `migrateLegacyContributorDocs runs without crashing when empty` ([gamification_security_test.dart:426-429](../test/gamification_security_test.dart)) only exercises the empty/offline guard; merge correctness untested | Add a fixture-based merge test (legacy `{house}_{scholarNo}` docs → canonical doc) against a Firestore mock/emulator |

**Verification-semantics note:** O-1/O-2 closures are verified by rules/transaction write-set alignment plus a first-hand deploy match. A production smoke test with real captain/council accounts was not performed; run one when role accounts are provisioned. G1's student live-award path remains intentionally fail-closed until the Blaze `schoolGamification` callable ships ([BLAZE_REQUIRED_FEATURES.md](../election_audit/BLAZE_REQUIRED_FEATURES.md), D4).

---

## Closure Rule

An item is closed only when code + rules + tests + deploy evidence all agree, and the closure statement matches the actual scope. Round-3 status: **O-1, O-2, O-3, O-4 CLOSED** (with residuals R-1/R-2/R-3 noted); **G10, G13 OPEN**; all earlier TRUE items remain TRUE; Blaze-gated work remains deferred per the standing no-Blaze constraint.
