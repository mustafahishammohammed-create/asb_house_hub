# Gamification / Points Remediation Roadmap

Prioritized plan mapped to finding IDs. Split by the user's standing constraint: **no Blaze plan for now** — server work is deferred exactly like elections.

**Verification update (2026-11-07, round 3 at `eae5f6b`):** O-1/O-2/O-3/O-4 verified TRUE first-hand (code + rules + suites + deploy match + push). G4 and G7 now closed. Still open: **G10** (standings cache/AI context) and **G13** (spirit reactor) — never remediated; plus new residuals **R-1** (captain contributor write unscoped), **R-2** (student shared-doc status flips), **R-3** (migration test depth). Full verdicts: [NOT_DONE_AND_FALSE_CLAIMS.md](NOT_DONE_AND_FALSE_CLAIMS.md). Requirement R1: [COUNCIL_PRIVILEGES.md](COUNCIL_PRIVILEGES.md).

## P0 — Do now (no Blaze required)

- [x] **G1** Make award failures truthful: remove blanket `catch (_) {}` in `awardVerifiedGamificationPoints`; return failure on live rules denial; move cache writes after server ack; label offline/demo states with `isDemo` flag and UI badging.
- [x] **G2** Eradicate both hardcoded secrets (gamification + sports): fail-closed `String.fromEnvironment` getters + `@visibleForTesting` injection, copying the election A1/A2 pattern. Live builds require new dart-defines (`GAMIFICATION_HMAC_SECRET`, `SPORTS_CERT_SECRET`).
- [x] **G3** Rules validator for `house_points` (house-name/doc-ID match, int bounds, bounded deltas, phantom `pearl` deleted); clamp client award amounts; deployed to Firestore.
- [x] **G9** Kill fabricated success: `submitHouseClaim` never invents IDs; MVP/accolade return false on live failure; success UI gated on results.

## P1 — Do now (no Blaze required)

- [x] **G4** Gate `graded` transitions to staff **+ council** (R1); GPA strictly required ✓ (cf1a1ac). O-2 closed at `eae5f6b`: council holds scoped status-only rules grants on assignments/homework; `updateAssignmentStatus` fails truthfully before cache/points on live rejection. Residual R-2: students can flip shared-doc status `pending`↔`submitted` (never `graded`).
- [x] **G5** Route Blitz through the award service (ceiling + cooldown); stop direct batch writes; treat quiz points as demo until server validation.
- [x] **G6** Fail closed on negative elapsed time / clock rollback in daily cooldowns and rapid-fire debounce throttles.
- [x] **G7** One contributor doc scheme (`{scholarNo}`), create-on-award ✓; real name/class ✓; `users.points_contributed` in transaction ✓ (cf1a1ac). O-3 closed at `eae5f6b`: migration wired to AdminClaimsScreen menu + one-time `seedAdminRoster` startup run behind `has_migrated_legacy_contributors_v1`. Residual R-3: merge-correctness test still needed (current test is empty-run smoke only).
- [x] **G11** Make claim `points`/`house_name` immutable on update; content-derived trophy IDs (`trophy_{sport}_{slug}_{winner}_{runnerUp}_{year}`) for award idempotency in transaction and cache.
- [x] **G12** Election certify: early return with server result on live success; cache/gazette writes demo-only; unified award constant to 100 points across client and server.

## P2 — Polish (no Blaze required)

- [x] **G8** Constant-time MAC compares; dropped raw-JSON token decode fallback; nonce consumption tracking (`isNonceConsumed`, `consumeNonce`) with replay rejection.
- [ ] **G10** Standings cache written only from server snapshots; label offline states; AI context uses synced data.
- [ ] **G13** Spirit reactor: numeric bounds + cap in rules, atomic `FieldValue.increment` per caller's house, `last_contributor` tied to caller.

## Deferred — requires Blaze (add to the Blaze completion list)

- [ ] **`schoolGamification` callable** — the real fix for G1/G4/G5/G6: server-side activity validation, server cooldowns (Firestore, server timestamps), atomic awards, idempotency keys, consumed-nonce store, append-only audit log. Rules then lock all direct points writes (`write: if false`).
- [ ] **Sports certification server-side** — mint/verify match tokens in a callable; client salt removed entirely.
- [ ] **Live points smoke test** — student earns → server ledger reflects it exactly once; sports lead cannot exceed bounds; replay/clock tricks rejected.

**Closure rule (same as elections):** an item is done only when its "Done when" passes with evidence. No closure claims while student awards are phantom or secrets remain in source. When Blaze arrives, complete the deferred section and re-run the full test suites before declaring the points economy closed.