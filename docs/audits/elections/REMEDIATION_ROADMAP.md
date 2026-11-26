# Remediation Roadmap — Prioritized Fix Plan

Checklist mapped to finding IDs. **Do P0 first** — until rules and the fallback are fixed, every other fix is bypassable.

## P0 — Stop the bleeding (rules + fallback + authority)

- [ ] **C1** Lock rules: all election/roster client writes `false` (callable-only via Admin SDK); restrict reads on `participation`, `election_votes`; deploy + rules unit tests.
- [ ] **C2** Reject privileged `scholar_no` (`admin`, `11209`) at self-create; authority from custom claims / `admin_roster`, never the users doc; audit existing docs.
- [ ] **C3** Remove `signInAdmin` auto-create; provision admin out-of-band; rotate the admin password.
- [ ] **C4** Delete `_callFirestoreFallback`; surface callable errors; timeout ≥10 s; fix Vote button to send the candidate **UUID**.
- [ ] **C5** Never fabricate success: rethrow failures, no receipt/tally on error; receipts only from the server response.
- [ ] **C6** Delete all privileged-tester bypasses (or `DEMO_MODE` compile-time flag, default off).
- [ ] **C7** Strip candidate fields from public docs; salt participation keys server-side; receipts = random UUID; fix the "completely anonymous" copy; migrate existing `election_votes`.

## P1 — Identity & integrity

- [ ] **H1** Atomic account switch: await re-auth before cache swap, revert on failure, prompt when no password, block actions mid-switch; remove fire-and-forget roster write.
- [ ] **S5/S9** Scope all caches per scholar; delete the global receipt mirror; fix `clearCache`; move saved passwords to secure storage or stop storing them.
- [ ] **S8** Exact-match / claim-based authority checks; no email substring matching.
- [ ] **H2** Authoritative roster import; signup reads house/grade; delete grade defaults; normalize scholar keys and house case everywhere.
- [ ] **H3** Migrate legacy polls to v2; single participation lock and single counts key; legacy becomes read-only history.
- [ ] **C8** Server-side certify only: transactional close + tally + gazette + points from the winner's roster house; tie/no-vote statuses; delete client certify/synthesized proclamations/local points.
- [ ] **C9** Lifecycle via callable only; add `deleteDraft`/`removeCandidate` draft-only checks; drop resurrected cached drafts; honor `startMs`.
- [ ] **H4** Management via callable; no auto-provisioning, no typed-name override, no saved-accounts fallback; sequenced lookup.
- [ ] **H5** Chamber votes via callable; ID-only candidate matching; busy guards; await before popping dialogs.
- [ ] **M7** Server-side receipt signing; constant-time compare; UTC timestamps; ≥128-bit receipt codes.

## P2 — Correctness, robustness, UX

- [ ] **H6** Fix TabController lifecycle (`TickerProviderStateMixin` or keyed remount); never recreate controllers in build.
- [ ] **M1** Missing `end_time` = closed, not now+7d; migrate legacy docs.
- [ ] **M2** Per-doc parse error boundaries; safe casts; stream error banners.
- [ ] **M3** Batch participation reads (or one callable); create streams once, not per build/keystroke.
- [ ] **M4** Delete fabricated foundational gazettes and the overwrite button; import real history if needed.
- [ ] **M5** Real server-side audit log; roster-derived eligible counts; server receipt verification that never reveals the candidate; remove fake compliance copy.
- [ ] **M6** No permissive model defaults; null-safe dates; server-authoritative open/closed; one timestamp type.
- [ ] **M8** Add `close`/`cancel`/`deleteDraft`/`audit` actions; enforce App Check; honor schedules; add `viceCaptain`.
- [ ] **M9** Server replaces cache on every snapshot; cache only offline with a banner; deletions propagate.
- [ ] **M10** Candidate house from roster; fix existing ruby-stamped universal polls.
- [ ] **L1** Dynamic year/config; correct timestamp labels; real margins; deterministic tie rendering.
- [ ] **L2** Pure `getSavedAccounts`; explicit save/promotion flows.
- [ ] **L3** Legacy create rethrows errors; success only after server ack (or migrate to v2 create).

## Verification after each phase

1. Rules emulator tests: non-admin direct writes denied; privileged scholar self-create denied.
2. Callable tests: duplicate vote, out-of-window vote, ineligible voter, wrong candidateId, tie, zero votes, early certify, double certify, republish — all rejected or handled correctly.
3. Widget tests: callable failure shows error and writes nothing; double-tap votes once; role flip doesn't crash; switch failure keeps old account.
4. Re-run the S1–S9 scenarios in [ACCOUNT_SWITCHING.md](ACCOUNT_SWITCHING.md) on a shared device with two sibling accounts.