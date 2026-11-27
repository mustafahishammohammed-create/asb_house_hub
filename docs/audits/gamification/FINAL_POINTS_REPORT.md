# FINAL POINTS SYSTEM REPORT — Cross-Module Audit

> **Update (2026-11-08, round 6 at `753c976`/`03918a1`):** R-7 (fail-closed attribution binding), N-1 (explicit-only sync stamps), N-2 (graded downgrade guard) verified TRUE first-hand — all round-5 residuals closed as claimed, no new findings. Suites 29/29 + 32/32 + 262/262, analyze 20 infos / 0 errors / 0 warnings, deploy match + push re-verified. All G1–G13 and R-1..R-7/N-1/N-2 closed; Blaze-gated D4 remains deferred. Claim-by-claim verdicts: [NOT_DONE_AND_FALSE_CLAIMS.md](NOT_DONE_AND_FALSE_CLAIMS.md). Council requirement status: [COUNCIL_PRIVILEGES.md](COUNCIL_PRIVILEGES.md). The register below is the original `f20c7f7` snapshot.

**Date:** 2026-11-07 · **Verified at HEAD:** `f20c7f7` · **Scope:** every module that touches the points economy.
**Method:** full static re-read of every points write/read site across all modules, rules-vs-client cross-check, attack-scenario tracing. Read-only — no code files modified. Secrets referenced by existence only; values never reproduced.

**Verification evidence at HEAD:** `flutter analyze` — 20 infos, **0 errors**; `flutter test test/election_security_test.dart` — **32/32 passed**. Widget suites unchanged since `4a816f6` (Election 19/19, Part 30 6/6, Phase 1 5/5). No code changes between the G1–G11 audit and this report, so all finding line references remain valid.

---

## 1. Executive verdict

**The points system is not one system — it is three ledgers with different trust levels, and the student-facing one is phantom.**

1. **Admin ledger (SOLID):** `approveClaim` and `recordStudentConduct` write `house_points` + `house_contributors` + `users.points_contributed` in a single transaction, server-authoritative values, failures rethrown. This is the correct pattern and already exists in the codebase.
2. **Student ledger (PHANTOM — G1):** every student-facing award (Blitz quiz, assignment grading, honours merit, gamification API) writes to collections whose rules deny student writes, the denial is swallowed by `catch (_) {}`, the local cache is inflated first, and the UI reports success. **Students earn nothing real; they only see their own device agree with them.** The wallet screen proves it: it streams `house_contributors/{scholarNo}`, finds no doc (student awards never create one — G7), and falls back to the phantom cache.
3. **Sports-leader ledger (UNVALIDATED — G3):** the one server write path students can reach (sports_captain / sports_vice_captain / sports_lead roles pass `isSportsLead()`) has **no content validator** on `house_points` — arbitrary amounts, any house, repeatable.

Two more hardcoded HMAC secrets ship in the binary (G2), and the client mints and verifies its own "tamper-proof" tokens. Elections are the only module with a real server-authoritative design — and it is **code-complete but not live** (callable undeployed, Blaze-gated), with a newly found cache double-count on its live path (G12).

**Bottom line:** until P0 fixes land, treat all student-visible points as demo numbers. The economy becomes real only when awards are server-validated (Blaze callable) or, interim, honestly reported as failures/demo.

---

## 2. Module-by-module points map

Every module in the app, its points touchpoints, and the verdict. Line numbers verified at `f20c7f7`.

| Module | Points touchpoint | Server-authoritative? | Verdict |
|---|---|---|---|
| **Elections (live)** | `certifyElectionAndAwardPoints` → `schoolElection` callable (auth_service:5037-5066) | Yes, once deployed | Code correct; **not live** (Blaze D1/D2). Cache double-count on success fall-through — **G12** |
| **Elections (demo)** | Demo tx auth_service:5073-5124; page fallback +100 (school_elections_page:1297-1305, inside `_callFirestoreFallback` :490 — offline/test only) | n/a | Demo-only; phantom cache pattern; +100 vs +50 inconsistency — G12 |
| **Election gazette** | election_gazette_screen:142 displays `housePointsAwarded` | Display only | Clean |
| **Sports — match certify** | `certifyMatchResult` :5432-5572; live fails truthfully :5527-5533; offline mints client token :5537 | No — client-side token | **G2, G8**; server callable deferred (Blaze) |
| **Sports — MVP** | `awardMatchMvp` :5639-5716 → house_points + contributors; fallback returns true :5698-5716 | Rules: admin/sports-lead only | **G9** phantom fallback; **G3** unbounded for student sports leads |
| **Sports — trophy** | `awardChampionshipTrophyAndPoints` :5788-5886 → winner + runner-up house_points; caller-supplied `pointsAwarded` :5793-5794; timestamp doc ID :5816 | Rules backstop only | **G3** unbounded; **G11** replayable ID |
| **Sports — accolade** | `awardPlayerAccoladeCustom` :5924-6003 → house_points; **no client role check**; `catch (_)` :5965 | Rules backstop only | **G3 / G9** |
| **Sports UI** | sports_tournament_screen:1257-1262 unconditional success snackbar | n/a | **G9** |
| **Academics — assignments** | `updateAssignmentStatus` :983-1058; `graded` mints `pointsReward` :1041-1053; status cycle pending→submitted→graded→pending (academic_assignment:58-67); academics_screen:2204-2218 | No — self-grading | **G4** + **G1** phantom |
| **Academics — honours merit** | `claimReportCardHonoursMerit` :1497-1564; GPA null skips the 3.80 check :1506; announcement before success (academics_screen:4261-4268) | No | **G4** + **G1** + **G9** |
| **House claims** | `submitHouseClaim` :3323-3388 (invented ID :3380-3387); `approveClaim` :3420-3551 admin tx | **Yes, on approval** | Approval **SOLID**; submit **G9**; mutable points/house_name **G11** |
| **Conduct** | `recordStudentConduct` :3802-3919 admin tx → all three ledgers | **Yes** | **SOLID** — transaction throws, no phantom |
| **Arena — Blitz quiz** | house_arena_screen:500-535 direct batch → house_points / users.points_contributed / house_contributors; answers hardcoded :190-228; score :465-472; catchError :535 | No — all three writes denied for students by rules | **G5** + **G1** (100% phantom) |
| **Arena — spirit reactor** | house_arena_screen:361-374 absolute 4-house write; rules :844-853 any signed-in user; validator :523-531 no bounds | Cosmetic only — no house_points | **G13** (new) |
| **Digital wallet** | digital_wallet_screen:462-501 streams `house_contributors/{scholarNo}`, falls back to phantom `cachedStats` when doc absent; cache write :494 | Display | Manifestation of **G1 + G7** — shows inflated local points |
| **Leaderboard** | house_leaderboard_screen:220/:327 reads house_points; :561-564/:641/:830 reads contributors | Display of server truth | Clean once writes are fixed |
| **Home** | home_screen:2448/:3713 contributor reads; :3039-3053 cache fabrication | Display + cache | **G10** |
| **Chat / AI** | gemini_ai_service:183/:520; house_ai_chat_screen:578 — AI context built from cached points | Display | **G10** — AI confidently reports phantom numbers |
| **Event wall / ticker** | No points fields; event_wall owner+pending create, likes-only student update (rules :862-872); ticker admin-only (:858) | n/a | **Verified clean — not points vectors** |
| **Merch store** | Orders created with `totalPts: 0` (merch_store_tab:568/:865/:2208); cart/orders only | n/a | **No points spending wired** — store cannot deduct points yet (feature gap, not a hole) |
| **Profile / users** | users rules: create forces student + zero points (:594-603); self-update cannot touch role/points/points_contributed/scholar_no (:617-619) | **Yes** | **SOLID** |

---

## 3. Findings register (13)

All OPEN, all re-verified at `f20c7f7`. Full detail in the linked docs.

| ID | Severity | Finding | Doc |
|----|----------|---------|-----|
| G1 | CRITICAL | Student points economy is phantom — denied writes reported as success | [G1](G1-phantom-student-points.md) |
| G2 | CRITICAL | Hardcoded HMAC secrets; client mints + verifies its own proofs | [G2](G2-hardcoded-secrets-client-proofs.md) |
| G3 | CRITICAL | house_points unbounded writes from student sports leaders | [G3](G3-unbounded-house-points-writes.md) |
| G4 | HIGH | Self-grading assignments + self-claimed merits (GPA null bypass) | [G4](G4-self-grading-merit-claims.md) |
| G5 | HIGH | Blitz quiz client-authoritative, answers in binary, unlimited replays | [G5](G5-blitz-quiz-client-authority.md) |
| G6 | HIGH | Local cooldowns; clock rollback bypass (`!elapsed.isNegative`) | [G6](G6-local-cooldowns-clock-trust.md) |
| G7 | HIGH | Contributor split-brain: `{house}_{scholar}` vs `{scholar}`; scheme A never creates | [G7](G7-contributor-ledger-split-brain.md) |
| G8 | MEDIUM | Token replay (nonce never consumed), non-constant-time compares | [G8](G8-token-replay-timing.md) |
| G9 | MEDIUM | Phantom success + fabricated IDs (claims, MVP, snackbars, merit announcement) | [G9](G9-phantom-success-fabricated-ids.md) |
| G10 | MEDIUM | Cache-first standings; AI context fed fabricated numbers | [G10](G10-cache-fabrication-ai-context.md) |
| G11 | MEDIUM | No award idempotency; claim points/house_name mutable on update | [G11](G11-idempotency-mutable-claims.md) |
| G12 | MEDIUM | **New:** election certify live path double-counts local cache; demo +100/+50 drift | [G12](G12-election-certify-cache-double-count.md) |
| G13 | LOW | **New:** spirit reactor unbounded/spoofable/LWW (cosmetic, no house_points) | [G13](G13-spirit-reactor-unbounded-write.md) |

---

## 4. What is already solid (do not break)

- `approveClaim` — server-authoritative values, duplicate-approval guard, single transaction, rethrow on failure (auth_service:3438-3520).
- `recordStudentConduct` — admin-only, transactional, no phantom (auth_service:3802-3919).
- `users` rules — immutable points/role on self-update; forced student+zero on create (firestore.rules:588-621).
- `house_claims` create — owner + pending only; `student_conduct` admin-only.
- Election live path — fail-closed winner-house validation, truthful server-error returns, demo tx properly gated (auth_service:5007-5073).
- `certifyMatchResult` live path fails truthfully (auth_service:5527-5533).
- Event wall / ticker rules — no points exposure.
- `defaultSeedStandings` — clean zero baseline.

---

## 5. Complete fix list

Prioritized; mirrors [REMEDIATION_ROADMAP.md](REMEDIATION_ROADMAP.md). Each item closes only when its doc's "Done when" passes with evidence.

### P0 — integrity, no Blaze required
1. **G1** Truthful award failures: no cache-before-write, no swallowed denials, success only after server ack.
2. **G2** Fail-closed secrets (election A1/A2 pattern: `String.fromEnvironment` → test override → `StateError`) for gamification + sports services.
3. **G3** Rules validators on `house_points` / `house_contributors`: doc-ID/house match, int bounds, bounded deltas; constrain or remove student sports-lead writes.
4. **G9** No fabricated IDs or success UI anywhere (claims, MVP, accolade, snackbars, merit announcement).

### P1 — correctness, no Blaze required
5. **G4** Staff-only `graded` transitions; GPA required or merit claims disabled; remove graded→pending cycle.
6. **G5** Blitz through the award service with ceiling + cooldown, or demo-labeled; no direct batch writes.
7. **G6** Fail closed on negative elapsed; monotonic high-water mark.
8. **G7** One contributor scheme (`{scholarNo}`), create-on-award, migration; wallet fallback reads truth.
9. **G11** Content-derived award IDs; immutable claim points/house_name.
10. **G12** Election certify: early return with server result on live success; cache writes demo-only; one award constant.

### P2 — hardening polish, no Blaze required
11. **G8** Constant-time compares; drop raw-JSON token fallback; explicit replay stance.
12. **G10** Cache written only from server snapshots; offline labeled; AI context from synced data.
13. **G13** Spirit reactor: bounds + cap in rules, atomic increments, contributor tied to caller.

### Deferred — requires Blaze (tracked in [../election_audit/BLAZE_REQUIRED_FEATURES.md](../election_audit/BLAZE_REQUIRED_FEATURES.md), item D4)
14. **`schoolGamification` callable** — the real fix for G1/G4/G5/G6: server validation, server-timestamp cooldowns, atomic awards, idempotency keys, consumed-nonce store, audit log; then rules lock direct points writes (`write: if false`).
15. **Sports certification callable** — server-side mint/verify; client salt removed entirely.
16. **Live points smoke test** — student earns → ledger reflects it exactly once; sports lead cannot exceed bounds; replay/clock tricks rejected. Includes the G12 live-path cache check.

---

## 6. Final acceptance gate

The points system is DONE only when **all** of these hold with evidence:

1. `flutter analyze` 0 errors; full test suite green (security + widget + new points regression tests).
2. Rules emulator tests: student direct writes to `house_points`, `house_contributors`, `users.points*` **denied**; admin/sports-lead writes **bounded**; spirit reactor bounds enforced.
3. Every award API returns success **only** after a confirmed server write; zero `catch (_) {}` around points writes; zero fabricated IDs.
4. `grep` proof: no secret literals in `lib/` (gamification, sports, election, vault all fail-closed).
5. One contributor doc per scholar; wallet, leaderboard, home, and AI all show the same server-derived number.
6. **Blaze stage:** D4 smoke test passes — real student award lands exactly once, replay/clock/bounds attacks rejected, election certify cache equals server.

Until then: **student-visible points are demo numbers.** That is the honest current state, and P0 makes the app at least tell the truth about it.