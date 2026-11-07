# Points Remediation — Verification Log & Open Items

Independent verification of the remediation reports. **Round 1:** `59048ad` (P0 report). **Round 2:** `cf1a1ac` (attachment report covering P-1/P-2/P-3, F-1/F-2/F-3, U-1, R1, G4, G6). Verified 2026-11-07. Every claim checked against code; all suites re-run locally; rules release verified first-hand.

**Round-2 overall:** most claims TRUE (see verdict table below). Three items remain open: **O-1 captain approval broken (false "LIVE" claim), O-2 council grading split-brain, O-3 migration helper never called.** The blanket "all RESOLVED" closure below was premature and is superseded by this log.

## Re-run evidence (local, this verification)

| Claim | Result | Verdict |
|---|---|---|
| `flutter analyze` 0 errors, 0 warnings | 20 infos, 0 errors, 0 warnings (same infos as baseline) | TRUE |
| `gamification_security_test.dart` 7/7 | 7/7 passed | TRUE |
| `election_security_test.dart` 32/32 | 32/32 passed | TRUE |
| `widget_test.dart` 262/262 | 262/262 passed | TRUE |

## TRUE — verified done

- **G1 (core):** `awardVerifiedGamificationPoints` ([auth_service.dart:3986-4049](../lib/services/auth_service.dart)) — live-mode transaction failure returns `success: false, pointsAwarded: 0`; cache writes moved after the live attempt (:4041-4043). Student awards now **truthfully fail** in live mode (rules still deny students — the real fix remains the Blaze callable, D4).
- **G2:** both hardcoded literals gone (grep confirms zero occurrences in `lib/` + `test/`); fail-closed getters `GAMIFICATION_HMAC_SECRET` / `SPORTS_CERT_SECRET` with `@visibleForTesting` injection match the election A1/A2 pattern.
- **G3 (core):** `isValidHousePoints` ([firestore.rules:523-534](../firestore.rules)) — doc-ID/house match, int 0..1,000,000, field whitelist; sports-leader updates bounded to −100..+500 per write (:835-843); trophy clamps 100/50 (auth_service:5842-5843), accolade clamp 50 (:5974).
- **G5:** Blitz routes through `awardVerifiedGamificationPoints` with a score-proof token, score clamped to ceiling 50, confetti gated on confirmed success ([house_arena_screen.dart:494-521](../lib/screens/house_arena_screen.dart)); direct batch writes deleted.
- **G9:** `submitHouseClaim` rethrows in live mode (auth_service:3382-3384); `awardMatchMvp` returns false on live failure (:5720-5723); `awardPlayerAccoladeCustom` returns false on live failure (:6005-6010); accolade snackbar gated on `success` ([sports_tournament_screen.dart:1257-1271](../lib/screens/sports_tournament_screen.dart)); merit announcement gated on `success` ([academics_screen.dart:4261-4269](../lib/screens/academics_screen.dart)).
- **G11 (claims half):** `points` + `house_name` added to immutable claim fields (firestore.rules:710).

## Round-2 re-run evidence (this verification, at `cf1a1ac`)

| Claim | Result | Verdict |
|---|---|---|
| `flutter analyze` 0 errors, 0 warnings | 20 infos, 0 errors, 0 warnings | TRUE |
| `gamification_security_test.dart` 15/15 | 15/15 passed | TRUE |
| `election_security_test.dart` 32/32 | 32/32 passed | TRUE |
| `widget_test.dart` 262/262 | 262/262 passed | TRUE |
| Rules deployed (U-1) | Re-ran `firebase deploy --only firestore:rules`: **"latest version of firestore.rules already up to date, skipping upload… released rules… Deploy complete!"** — cloud ruleset matches the repo file, so the round-2 deploy was real | **TRUE (verified first-hand)** |

## Round-2 verdicts

| Claim | Verdict | Evidence / remainder |
|---|---|---|
| F-3 pearl removed | **TRUE** | firestore.rules:554 — four houses only |
| P-3 drain griefing + contributor validator | **TRUE** | Positive-only 0..+500 for sports lead/council, negatives admin-only (:900-912); `isValidHouseContributor` (:565-585) |
| F-1 / G8 nonce + raw-JSON | **TRUE** | Fallback deleted; nonce required, consumed in award path (auth_service:3991-3994), replay rejected. Residual: nonce store is client-side prefs — wiping app data resets it; server-side store is Blaze D4 |
| F-2 / G11 trophy idempotency | **TRUE** | Content-derived ID (auth_service:5970-5980), cache pre-check (:5983-5990), transaction exists-check (:6016-6020) |
| G6 clock rollback | **TRUE** | Both `canParticipateDaily` and `checkRapidFireThrottle` fail closed on negative elapsed |
| P-2 / G1 demo labeling | **TRUE** | `isDemo` on every return; amber arena badge (house_arena_screen:1178-1196) |
| P-1 / G7 migration + identity + derivation | **PARTIAL** | Real name/class ✓, `users.points_contributed` in transaction ✓ — but migration helper is **dead code** (O-3) |
| G4 grading gate | **PARTIAL** | Student gate ✓ (client + service), GPA strictly required ✓ (auth_service:1517) — but council grading is **split-brain** (O-2) |
| R1 council privileges | **PARTIAL** | Council claims approval works end-to-end ✓ — but captain approval is **broken** (O-1) |
| G12 (roadmap, unclaimed in report) | **TRUE (substance)** | Early return on live success (auth_service:5202-5206); unified 100 matches server award (elections-v2.js:231). Nits: gazette cache insert doesn't dedup; cached ballot status not refreshed on the live path; roadmap wording "cache/gazette writes demo-only" is inaccurate — they run as mirroring on live too |

## OPEN — not done / false claims (round 2)

### O-1. Captain claim approval is broken — "IMPLEMENTED & LIVE" is FALSE (HIGH)
Rules allow a same-house captain to update `house_claims` (:769-774), but `approveClaim` is a **single transaction** that also writes `house_points` (captain **not** in the grant — :900-912) and `house_contributors` (captain **not** in the grant — :919-920). Any denied write fails the whole transaction → captain approval **always errors in live mode**. The unit tests pass only because they run in demo mode where rules aren't enforced.
**Solution (pick one):** (a) grant captains the full approval path — `house_points` bounded 0..+500 **own house only** (`getUserData().house_name == houseId`) and `house_contributors` write for the claim's scholar; or (b) remove `isCaptain()` from the claims update rule and make the matrix council-only. Until then, the captain row in [COUNCIL_PRIVILEGES.md](COUNCIL_PRIVILEGES.md) is not live.

### O-2. Council grading is split-brain — points land, official record doesn't (HIGH)
`canGradeAcademics` admits council client-side, but `classes/{classId}/assignments/{id}` writes are `isAdmin()`-only ([firestore.rules:728](../firestore.rules)). In `updateAssignmentStatus` the status write is **denied and swallowed** (`catch (_) {}`, [auth_service.dart:1026-1033](../lib/services/auth_service.dart)), the local cache is marked graded, and merit points **are awarded** (council holds all points grants). Result: points without a server grading record, and the method returns `true` regardless — the exact phantom pattern G1/G9 eradicated elsewhere. The "allows council officer" unit test is demo-green for the same reason as O-1.
**Solution:** grant council a **scoped** write on class assignments/homework (diff limited to `status`, `submitted_at`, `graded_at` — not full `isValidHomework` create rights), and make the status write truthful: on live failure return `false`, skip cache + point award. Award points only after the status write is confirmed.

### O-3. Contributor migration is dead code (MEDIUM)
`migrateLegacyContributorDocs()` ([auth_service.dart:4114](../lib/services/auth_service.dart)) has **zero callers** — no admin button, no startup hook, no script (grep verified). Legacy `{house}_{scholarNo}` docs stay orphaned until someone invokes it. Under the new rules only admin/council could execute it client-side.
**Solution:** wire it to an admin action (e.g. Claims portal overflow menu) or a one-time admin-startup call with a completion flag in prefs; or run it once via an admin script and record the migrated count as evidence.

### O-4. Minor residuals (LOW)
- `users.points_contributed` council/captain branch: when the field is **absent**, the delta bound is skipped — first write can set any value ≤1,000,000 (firestore.rules:683-685). Bound the first write too (≤500).
- Sports-lead/council positive writes are per-write bounded but **cumulatively unlimited** and not house-scoped — a rogue officer can pump any house +500 repeatedly. Accepted interim until the Blaze callable makes awards server-atomic; noted for D4.
- Rules compile warning: unused function `isValidElection` (cosmetic).
- G12 nits listed above (gazette dedup, cached ballot refresh).

---

## Closure rule

An item is done only when its "Done when" passes with evidence **in live semantics** (rules enforced), not demo-mode unit tests. O-1 and O-2 block R1 closure; O-3 blocks G7 closure. When Blaze arrives, D4 (server-authoritative awards) supersedes the interim client grants.