# Gamification / Points Remediation Roadmap

Prioritized plan mapped to finding IDs. Split by the user's standing constraint: **no Blaze plan for now** — server work is deferred exactly like elections.

## P0 — Do now (no Blaze required)

- [x] **G1** Make award failures truthful: remove blanket `catch (_) {}` in `awardVerifiedGamificationPoints`; return failure on live rules denial; move cache writes after server ack; label offline/demo states.
- [x] **G2** Eradicate both hardcoded secrets (gamification + sports): fail-closed `String.fromEnvironment` getters + `@visibleForTesting` injection, copying the election A1/A2 pattern. Live builds require new dart-defines (`GAMIFICATION_HMAC_SECRET`, `SPORTS_CERT_SECRET`).
- [x] **G3** Rules validator for `house_points` (house-name/doc-ID match, int bounds, bounded deltas); clamp client award amounts; deployed to Firestore.
- [x] **G9** Kill fabricated success: `submitHouseClaim` never invents IDs; MVP/accolade return false on live failure; success UI gated on results.

## P1 — Do now (no Blaze required)

- [ ] **G4** Gate `graded` transitions to staff (UI + service); make GPA required and server-sourced or disable student merit claims.
- [x] **G5** Route Blitz through the award service (ceiling + cooldown); stop direct batch writes; treat quiz points as demo until server validation.
- [ ] **G6** Fail closed on negative elapsed time; monotonic high-water mark.
- [x] **G7** One contributor doc scheme (`{scholarNo}`), create-on-award, merge migration; derive `users.points_contributed`.
- [x] **G11** Content-derived award IDs (idempotency); make claim `points`/`house_name` immutable on update (enforced in rules).
- [ ] **G12** Election certify: early return with server result on live success; cache/gazette writes demo-only; unify the demo award constant (+50 vs +100).

## P2 — Polish (no Blaze required)

- [x] **G8** Constant-time compares (`_constantTimeEquals` in gamification & sports security services); drop raw-JSON token fallback; explicit replay stance.
- [ ] **G10** Standings cache written only from server snapshots; label offline states; AI context uses synced data.
- [ ] **G13** Spirit reactor: numeric bounds + cap in rules, atomic `FieldValue.increment` per caller's house, `last_contributor` tied to caller.

## Deferred — requires Blaze (add to the Blaze completion list)

- [ ] **`schoolGamification` callable** — the real fix for G1/G4/G5/G6: server-side activity validation, server cooldowns (Firestore, server timestamps), atomic awards, idempotency keys, consumed-nonce store, append-only audit log. Rules then lock all direct points writes (`write: if false`).
- [ ] **Sports certification server-side** — mint/verify match tokens in a callable; client salt removed entirely.
- [ ] **Live points smoke test** — student earns → server ledger reflects it exactly once; sports lead cannot exceed bounds; replay/clock tricks rejected.

**Closure rule (same as elections):** an item is done only when its "Done when" passes with evidence. No closure claims while student awards are phantom or secrets remain in source. When Blaze arrives, complete the deferred section and re-run the full test suites before declaring the points economy closed.