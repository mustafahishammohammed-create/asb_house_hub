# Gamification / Points Remediation Roadmap

Prioritized plan mapped to finding IDs. Split by the user's standing constraint: **no Blaze plan for now** — server work is deferred exactly like elections.

**Verification update (2026-11-07, round 2 at `cf1a1ac`):** G8/G11/G6/G12 and most round-1 open items verified TRUE; rules release verified first-hand. Still open: **O-1** captain approval broken, **O-2** council grading split-brain (both block R1), **O-3** migration helper never called (blocks G7). Full verdicts: [NOT_DONE_AND_FALSE_CLAIMS.md](NOT_DONE_AND_FALSE_CLAIMS.md). Requirement R1: [COUNCIL_PRIVILEGES.md](COUNCIL_PRIVILEGES.md).

## P0 — Do now (no Blaze required)

- [x] **G1** Make award failures truthful: remove blanket `catch (_) {}` in `awardVerifiedGamificationPoints`; return failure on live rules denial; move cache writes after server ack; label offline/demo states with `isDemo` flag and UI badging.
- [x] **G2** Eradicate both hardcoded secrets (gamification + sports): fail-closed `String.fromEnvironment` getters + `@visibleForTesting` injection, copying the election A1/A2 pattern. Live builds require new dart-defines (`GAMIFICATION_HMAC_SECRET`, `SPORTS_CERT_SECRET`).
- [x] **G3** Rules validator for `house_points` (house-name/doc-ID match, int bounds, bounded deltas, phantom `pearl` deleted); clamp client award amounts; deployed to Firestore.
- [x] **G9** Kill fabricated success: `submitHouseClaim` never invents IDs; MVP/accolade return false on live failure; success UI gated on results.

## P1 — Do now (no Blaze required)

- [ ] **G4** Gate `graded` transitions to staff **+ council** (R1); GPA strictly required ✓ (cf1a1ac). **Remaining (O-2):** council grading is client-only — rules grant council scoped status writes on class assignments, and the swallowed status-write failure must become truthful before points are awarded.
- [x] **G5** Route Blitz through the award service (ceiling + cooldown); stop direct batch writes; treat quiz points as demo until server validation.
- [x] **G6** Fail closed on negative elapsed time / clock rollback in daily cooldowns and rapid-fire debounce throttles.
- [ ] **G7** One contributor doc scheme (`{scholarNo}`), create-on-award ✓; real name/class ✓; `users.points_contributed` in transaction ✓ (cf1a1ac). **Remaining (O-3):** `migrateLegacyContributorDocs()` has zero callers — wire it to an admin action or run it once with evidence.
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