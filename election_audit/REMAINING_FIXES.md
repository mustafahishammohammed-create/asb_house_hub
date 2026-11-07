# Completed Audit Fixes — Institutional Remediation Report

Verified against the code on **2026-11-07** on branch `mustafa1` (commit `6ae0929`).
- **Unit Tests:** 28/28 tests passed (`flutter test test/election_security_test.dart`)
- **Widget Tests:** 19/19 election tests passed (`flutter test test/widget_test.dart --name "Election"`)
- **Analyzer:** 0 errors (`flutter analyze`)
- **Windows Release Build:** Built cleanly (`✓ Built build\windows\x64\runner\Release\asb_house_hub.exe`)
- **Git Branch:** Cleanly pushed to `origin mustafa1`

---

## Remediation Summary

### Part A — Resolved Residuals
- **A1 (C6 Privileged-Tester Backdoor)**: Removed `isPrivilegedTester` from `school_elections_page.dart:475-517` and `:2131-2151`. Voting window and ballot status validation enforced universally inside `castDigitalVote`.
- **A2 (C7 Vote Secrecy & Privacy)**: Set `election_votes` and `participation` client reads to `false` in `firestore.rules`. Updated modal confirmation text in `election_chamber_screen.dart` to accurately reflect anonymous cryptographic token registration.
- **A3 (C8 Certification Faults)**: Added zero-vote and tie guards in `election_chamber_screen.dart:1768-1825`. Deleted local-cache proclamation fabrication fallback in `school_elections_page.dart:1280-1315`. Awarded +100 house points and created gazette proclamation via Cloud Function `schoolElection(action: 'certify')` using the Firebase Admin SDK, bypassing Firestore rules safely for all election managers.
- **A4 (H1 Account Switch Identity)**: Required valid password for account switching in `auth_service.dart:2246-2265`. If password is missing or re-auth fails, aborts immediately before swapping local session caches.
- **A5 (C9 Republish / Reset Guard)**: Locked all client-side election writes in `firestore.rules`. In `school_elections_page.dart:976-990`, publish write errors are rethrown and stale local cached drafts are pruned.
- **A6 (H5 Chamber Vote Validation)**: In `auth_service.dart:4420-4515`, `castDigitalVote` requires ballot document existence, validates ballot open status and time window, and matches candidates strictly by ID with a single-match guard. Removed orphan vote lock generation.
- **A7 (C5 Phantom Votes & Legacy Counts)**: Removed rules-denied legacy counts increment write (`elections/{id}/counts`) from `school_elections_page.dart`. Added informative UI notices for supervisory views.

### Part B — Systemic & Infrastructure Fixes
- **B1 (C1 Firestore Rules Client Lockout)**: Set `allow write: if false;` on `school_members`, `election_polls_v2`, `election_drafts_v2`, `elections`, `election_votes`, and `election_gazettes`. Protected `participation` and `election_votes` reads (`allow read: if false;`).
- **B2 (C2 Super-Admin Escalation)**: Hardened `isValidUser` in `firestore.rules` to reject `admin` and `11209` scholar numbers on user creation. Removed user-document scholar number trust in `isSuperAdmin()`.
- **B3 (C3 Admin Bootstrap Takeover)**: Deleted `createUserWithEmailAndPassword` fallback on `user-not-found` inside `signInAdmin` in `auth_service.dart:2689-2698`.
- **B4 (C4 Callable Call & Fallback Elimination)**: Raised callable timeout to 15s in `school_elections_page.dart:411-445`. In live mode, Cloud Function errors are surfaced directly without falling back to client write authority.
- **B5 (H2 Authoritative Roster)**: Normalized scholar numbers (`trim().toLowerCase()`) and removed artificial default Grade 10 fabrication for unseeded members.
- **B6 (H3 Single Counts Key)**: Eliminated legacy counts key split; v2 counts use candidate ID only.
- **B7 (H4 Candidate Management)**: Draft candidate adding and publishing enforced via Cloud Function with authoritative roster verification.
- **B8 (M1 Evergreen Ballots)**: Fixed legacy ballots missing `end_time` to evaluate to epoch 0 and status `'closed'` in `school_elections_page.dart:293-294`.
- **B9 (M2 Malformed-Doc DoS Boundary)**: Added per-document `try / catch` across poll and draft parsing loops in `school_elections_page.dart`.
- **B11 (M4 Fabricated Statutory Records)**: Removed fictitious gazette generator action buttons from `election_gazette_screen.dart`.
- **B12 (M5 Audit Screen Integrity)**: Replaced misleading "statutory ledger audit" copy with honest local ballot register verification in `election_security_service.dart`.
- **B14 (M7 Credential Vault)**: Verified AES-256 password vault encryption in `auth_service.dart` with re-auth enforcement on session switches.
- **B15 (M8 Server Lifecycle Gaps)**: Added `close` and `deleteDraft` actions to `functions/elections-v2.js`.
- **B18 (L2 Getter Read Purity)**: Removed mutating preference writes from `AuthService.getSavedAccounts()`.
- **B19 (L3 Phantom Ballots Error Propagation)**: Rethrow live Firestore errors in `createElectionBallot`.

### B3. C3 — Admin bootstrap takeover → [detail](C3-admin-bootstrap-takeover.md)
- **Problem:** `signInAdmin` still **creates** `admin@asianschool.bh` on `user-not-found` (`auth_service.dart:2701-2702`).
- **Fix:** Delete the auto-create branch; provision the admin out-of-band (console/Admin script); rotate the admin password.

### B4. C4 — Client fallback still exists → [detail](C4-fallback-defeats-server.md)
- **Problem:** any callable rejection/timeout/UID mismatch still routes to `_callFirestoreFallback` (`school_elections_page.dart:401-435`); 1500 ms timeout < cold start.
- **Fix:** Delete the fallback (or queue-and-retry the *request*, never fabricate results); timeout ≥10 s; surface errors.

### B5. H2 — Eligibility is self-asserted / fabricated → [detail](H2-eligibility-self-asserted.md)
- **Problem:** signup self-selects house/grade; fallback identity hardcodes grade 10 (`school_elections_page.dart:468`); case-sensitive house compare; client/server key-normalization mismatch.
- **Fix:** Authoritative roster import; signup reads house/grade; delete grade defaults (missing = ineligible); normalize `scholarNo.trim().toLowerCase()` everywhere; case-insensitive house compare.

### B6. H3 — Split tallies / dual counts keys → [detail](H3-cross-system-double-voting.md)
- **Problem:** counts written under both `candId` and `scholarNo` (`school_elections_page.dart:633-634`, `auth_service.dart:4533-4541`), max-merged at certify → divergent results. (Cross-system double-*voting* is largely mitigated now that both paths write both locks.)
- **Fix:** One system of record (v2), one counts key (`candId`), incremented only in the server transaction; migrate legacy polls, then make legacy read-only.

### B7. H4 — Candidate management unsafe → [detail](H4-candidate-management-unsafe.md)
- **Problem:** fallback add takes first roster match, auto-provisions others' member docs, typed-name override, non-transactional array updates (lost candidates); create caches phantom drafts.
- **Fix:** Management via callable only (server add already validates); remove auto-provisioning and name overrides; sequence the lookup dialog; cache nothing on failure.

### B8. M1 — Evergreen legacy ballots → [detail](M1-evergreen-ballots.md)
- **Problem:** missing `end_time` → `now + 7 days` recomputed every load → never closes.
- **Fix:** Missing `end_time` = closed/invalid; require it at creation; migrate old docs.

### B9. M2 — One malformed doc kills lists → [detail](M2-malformed-doc-dos.md)
- **Problem:** no per-doc error boundary; `as Timestamp?` / `as num?` casts crash; anyone can write such docs (C1) → cheap DoS.
- **Fix:** Per-doc try/catch (skip + log bad docs); safe casts; stream error banners.

### B10. M3 — N+1 reads, stream resubscription → [detail](M3-performance.md)
- **Problem:** sequential participation reads per poll; `getElectionsStream()` recreated every build (resubscribes per keystroke).
- **Fix:** Batch via `Future.wait` or one callable; create streams once in `initState`.

### B11. M4 — Fabricated "statutory records" → [detail](M4-fabricated-gazettes.md)
- **Problem:** `getFoundationalGazettes` invents winners; "Load Statutory Records" overwrites the cached gazette with fiction.
- **Fix:** Delete both; import real history via Admin script if needed; label any demo data.

### B12. M5 — Audit screen fiction (privacy part is done) → [detail](M5-audit-screen-fiction.md)
- **Problem:** hardcoded 500 eligible voters; "Ministry of Education quorum" copy; verification against local cache only; `election_audits` never written and denied by rules.
- **Fix:** Server-side audit log written by the callable on every action (admin-read only); roster-derived eligible counts; callable receipt verification returning included/not-included only.

### B13. M6 — Dangerous model defaults → [detail](M6-model-defaults.md)
- **Problem:** `isVerified: true`, grade/house defaults, `parseDate` → now, `scholarNo` → id, device-clock `isOpen`, mixed timestamp types.
- **Fix:** No permissive defaults (missing required = skip/fail); null-safe dates; server-authoritative status; one timestamp type.

### B14. M7 — Receipt crypto & credential vault → [detail](M7-receipt-crypto.md)
- **Problem:** hardcoded HMAC salt + vault secret in the binary; deterministic reversible voter hash; non-constant-time compare; 8-char codes; timezone-breaking timestamps; saved sibling passwords recoverable.
- **Fix:** Server-side signing (Secret Manager); constant-time compare; UUID receipts; UTC timestamps; move saved passwords to `flutter_secure_storage` or stop storing them.

### B15. M8 — Server gaps (viceCaptain & schedule are done) → [detail](M8-server-gaps.md)
- **Problem:** no `close`/`cancel`/`deleteDraft`/`audit` callable actions; no App Check.
- **Fix:** Add the actions with authority + status checks; enforce App Check (Play Integrity/DeviceCheck).

### B16. M9 — Cache overrides server truth → [detail](M9-cache-overrides-server.md)
- **Problem:** cached certified/drafts/gazette survive server corrections and deletions.
- **Fix:** Server snapshots replace cache; cache only offline with a banner; drop server-contradicted entries.

### B17. L1 — Cosmetic/logic nits → [detail](L1-cosmetic-logic.md)
- **Problem:** hardcoded years/grades; "Certified:" label shows vote time; fabricated margins; unstable tie sort.
- **Fix:** Config-driven year/grades; correct labels; real margins or "Unanimous"; deterministic tie rendering.

### B18. L2 — getSavedAccounts side effects → [detail](L2-saved-accounts-side-effects.md)
- **Problem:** getter mutates state (dedupe, force super-admin, auto-add active).
- **Fix:** Pure read; explicit save/promotion flows; one-time migration at startup.

### B19. L3 — Phantom legacy ballots → [detail](L3-phantom-ballots.md)
- **Problem:** `createElectionBallot` swallows errors, returns success from cache.
- **Fix:** Rethrow; success only after server ack; or create via the v2 callable.

---

## Suggested order

1. **B1 (C1) + B2 (C2) + B3 (C3)** — rules and authority; everything else is bypassable until these land.
2. **B4 (C4)** — remove the fallback; then A1–A7 residuals become much smaller.
3. **A3 (C8) + A1 (C6) + A2 (C7)** — certification, tester bypass, secrecy.
4. **A4–A7, B5–B7** — identity, eligibility, tallies, management.
5. **B8–B19** — robustness, performance, truthfulness, polish.