# Election System Audit — Findings & Fixes

Deep read-only audit of both election systems (legacy `elections`/`election_votes`/`election_gazettes` and v2 `election_polls_v2`/`election_drafts_v2`/`school_members`), all four election screens, auth/account-switching, models, Firestore rules, and the `schoolElection` callable.

**Method:** full static read of every file involved, scenario tracing, `node --check` on both functions files (passed). Flutter analyze/tests were not run during the audit to keep the repo untouched. Secrets (HMAC salt, vault secret, API keys) are referenced by existence only — values are never reproduced.

**Verdict:** the server callable is mostly well-written, but three design decisions nullify it: (1) rules let any signed-in user write everything directly (C1), (2) the client falls back to a weaker client-side implementation whenever the server rejects or times out (C4), and (3) failure paths fabricate success (C5). Fix the P0 items in the [roadmap](REMEDIATION_ROADMAP.md) first — until then, every other fix is bypassable.

Each finding below follows the format: **Problem → What breaks → Solution**.

## Critical (9)

| ID | Finding | File |
|----|---------|------|
| C1 | Every election collection is public-read / any-user-write | [C1](C1-firestore-rules-public-writes.md) |
| C2 | Self-service super-admin escalation via users doc | [C2](C2-super-admin-escalation.md) |
| C3 | Admin bootstrap takeover in signInAdmin | [C3](C3-admin-bootstrap-takeover.md) |
| C4 | Client fallback defeats the server (+ vote button sends wrong candidateId) | [C4](C4-fallback-defeats-server.md) |
| C5 | Phantom votes — failure reported as success | [C5](C5-phantom-votes.md) |
| C6 | Privileged-tester voting backdoor | [C6](C6-privileged-tester-backdoor.md) |
| C7 | Vote secrecy broken (choice, turnout, receipts leak) | [C7](C7-vote-secrecy-broken.md) |
| C8 | Certification wrong in every client path (ties, zero votes, early, wrong house, double points) | [C8](C8-certification-faults.md) |
| C9 | Republish/reset attack on live and certified polls | [C9](C9-republish-reset-attack.md) |

## High (6)

| ID | Finding | File |
|----|---------|------|
| H1 | Account switching breaks identity (cache swaps before auth) | [H1](H1-account-switch-identity.md) |
| H2 | Eligibility rests on self-asserted/fabricated data; key-normalization mismatch | [H2](H2-eligibility-self-asserted.md) |
| H3 | Cross-system double voting and split tallies | [H3](H3-cross-system-double-voting.md) |
| H4 | Candidate management unsafe and phantom | [H4](H4-candidate-management-unsafe.md) |
| H5 | Chamber vote path has almost no validation; UI races | [H5](H5-chamber-vote-no-validation.md) |
| H6 | Role flip during account switch crashes the v2 page (TabController) | [H6](H6-tabcontroller-crash.md) |

## Medium (10)

| ID | Finding | File |
|----|---------|------|
| M1 | Evergreen legacy ballots (missing end_time never closes) | [M1](M1-evergreen-ballots.md) |
| M2 | One malformed doc kills whole lists (cheap DoS) | [M2](M2-malformed-doc-dos.md) |
| M3 | N+1 reads; stream resubscription per keystroke | [M3](M3-performance.md) |
| M4 | Fabricated "statutory records" presented as real history | [M4](M4-fabricated-gazettes.md) |
| M5 | Audit screen is fiction and leaks the voter's choice | [M5](M5-audit-screen-fiction.md) |
| M6 | Dangerous model defaults (isVerified true, grade/house defaults, device clock) | [M6](M6-model-defaults.md) |
| M7 | Receipt crypto weaknesses (hardcoded salt, deterministic hash, TZ break) | [M7](M7-receipt-crypto.md) |
| M8 | Server gaps: no close/cancel/deleteDraft/audit, no App Check, schedule ignored | [M8](M8-server-gaps.md) |
| M9 | Cache overrides server truth | [M9](M9-cache-overrides-server.md) |
| M10 | Universal polls label every candidate Ruby (points bias) | [M10](M10-universal-poll-ruby.md) |

## Low (3)

| ID | Finding | File |
|----|---------|------|
| L1 | Cosmetic/minor logic (labels, margins, hardcoded years, unstable ties) | [L1](L1-cosmetic-logic.md) |
| L2 | getSavedAccounts has side effects | [L2](L2-saved-accounts-side-effects.md) |
| L3 | Phantom ballots in legacy create path | [L3](L3-phantom-ballots.md) |

## Companion documents

- [REMAINING_FIXES.md](REMAINING_FIXES.md) — **current status**: what is partially done (with residuals) and not done, each with its fix. Verified 2026-11-07 after commits `b66fc47`/`efa671d`.
- [ACCOUNT_SWITCHING.md](ACCOUNT_SWITCHING.md) — S1–S9 scenario walkthroughs (switch timing, siblings, shared devices, vault extraction).
- [REMEDIATION_ROADMAP.md](REMEDIATION_ROADMAP.md) — prioritized P0/P1/P2 fix plan with a checklist mapped to finding IDs.

## Coverage note

Existing tests (`test/election_security_test.dart`) cover per-scholar receipt isolation and role gating only. None of the 28 findings above are covered by tests; each finding's Solution section includes the test(s) to add.