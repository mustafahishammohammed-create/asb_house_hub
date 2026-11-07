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

- [BLAZE_REQUIRED_FEATURES.md](BLAZE_REQUIRED_FEATURES.md) — **deferred work parked by user decision**: everything that needs the Blaze plan (functions deployment, live smoke test, App Check activation), with step-by-step completion instructions for when the upgrade happens.
- [NOT_DONE_AND_FALSE_CLAIMS.md](NOT_DONE_AND_FALSE_CLAIMS.md) — historical finding list from `cd1686a`. All Section A and C items were re-verified as genuinely fixed at `4a816f6` (see status below); Section B items are Blaze-blocked and tracked in BLAZE_REQUIRED_FEATURES.md.
- [FINAL_ELECTION_FIXES.md](FINAL_ELECTION_FIXES.md) — the last and final election work list (F1–F14). Its "closed" checkboxes were marked prematurely at `7fd6c71`; the code-level items are now verified fixed at `4a816f6`, with live deployment pending Blaze.
- [REMAINING_FIXES.md](REMAINING_FIXES.md) — earlier status snapshot (superseded by FINAL_ELECTION_FIXES.md).
- [ACCOUNT_SWITCHING.md](ACCOUNT_SWITCHING.md) — S1–S9 scenario walkthroughs (switch timing, siblings, shared devices, vault extraction).
- [REMEDIATION_ROADMAP.md](REMEDIATION_ROADMAP.md) — prioritized P0/P1/P2 fix plan with a checklist mapped to finding IDs.

## Remediation Status

**Independently re-verified at `4a816f6` (2026-11-07): all non-Blaze claims are TRUE.** Code-level election work is complete; live deployment is parked in [BLAZE_REQUIRED_FEATURES.md](BLAZE_REQUIRED_FEATURES.md) by user decision (no Blaze plan for now).

Verification evidence: `election_security_test.dart` 32/32, widget `Election` 19/19, `Part 30` 6/6, `Phase 1` 5/5, `flutter analyze` 0 errors, `node --check` on all three functions files OK, Windows release build OK.

Post-`cd1686a` audit items have been systematically resolved:
1. **Section A (Zero Secrets in Source & Zero Password Persistence)**:
   - **A1**: Hardcoded HMAC salt literal completely deleted from `lib/`. `--dart-define=ELECTION_HMAC_SALT` required in live mode or fails closed (`StateError`).
   - **A2**: Derivable vault key fallback deleted from `lib/`. `--dart-define=VAULT_SECRET` required in live mode or fails closed (`StateError`).
   - **A3**: `SavedAccount.toMap()` sets `'password': null`. Saved-accounts JSON on disk contains 0 passwords. Legacy passwords purged on read. Re-authentication prompt wired into session switcher before cache swap.
2. **Section B (Deployment & Attestation Architecture)**:
   - **B1**: Cloud Functions code 100% written and syntax-checked (`node --check`). Deployment requires the project owner to upgrade project `asb-house-hub` to Blaze (pay-as-you-go) to enable Cloud Build and Artifact Registry.
   - **B2**: `onCall` App Check enforcement set to `process.env.ENFORCE_APP_CHECK === "true"`, preventing total service denial on Windows desktop clients (where no native FlutterFire App Check provider exists) while maintaining strict compensating controls (Firestore rules lockdown, mandatory auth, claims checks, transaction locks).
   - **B3**: Live smoke test documented and ready for execution upon Cloud Functions deployment.
3. **Section C (Minor Residuals)**:
   - **C1**: All `?? 'ruby'` / `?? 'emerald'` fallbacks in election paths removed. Missing houses render "UNKNOWN" or fail closed during certification.
   - **C2**: Embedded `votes_count` array writes eliminated from `school_elections_page.dart` and `auth_service.dart`. Tallies come strictly from `counts/`.
   - **C3**: Name-based candidate fallback removed from Chamber vote; resolution matches strictly by scholar number or candidate ID.