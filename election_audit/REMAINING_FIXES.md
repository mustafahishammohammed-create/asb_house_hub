# Remaining Fixes — Partially Done & Not Done

Verified against the code on **2026-11-07** after commits `b66fc47` and `efa671d` (tests re-run: 28/28 pass; analyzer: 0 errors; Windows release: builds; branch pushed). Items below are what is **still open**. Each entry: what remains broken (with evidence) → the fix. Full detail per finding lives in the linked audit docs.

---

## A. PARTIALLY DONE — claimed fixed, residuals remain

### A1. C6 — Privileged-tester backdoor → [detail](C6-privileged-tester-backdoor.md)
- **Done:** `isStaffTester` removed from `castDigitalVote`; duplicate checks universal there.
- **Still broken:** `isPrivilegedTester` remains in `school_elections_page.dart:475-517` (skips the duplicate-vote check) and `:2131-2151` (skips window/house/grade). `castDigitalVote` has **no election-window validation** despite the claim.
- **Fix:** Delete both `isPrivilegedTester` blocks in the page. Add status + opensAt/closesAt validation inside the `castDigitalVote` transaction (or route chamber voting through the callable). If a demo bypass is needed, gate it behind `bool.fromEnvironment('DEMO_MODE')` (default false) so release builds cannot contain it.

### A2. C7 — Vote secrecy → [detail](C7-vote-secrecy-broken.md)
- **Done:** `candidate_scholar_no` / `candidate_name` stripped from `election_votes` in both write paths.
- **Still broken:** the publicly readable `proof_token` is `HMAC(hash::ballotId::candidateScholarNo::timestamp)` with the **hardcoded salt still in the binary** (`election_security_service.dart:6,24-36`) → anyone can brute-force the public candidate list and recover each vote's choice. `election_votes` is still `read: if true`; participation keys are still unsalted SHA-256 (turnout enumerable); "completely anonymous" copy remains (`election_chamber_screen.dart:904`).
- **Fix:** Move receipt signing server-side (secret in Secret Manager, never the binary); do not store choice-derived tokens in public docs; set `election_votes` and `participation` reads to `false` (server returns "you voted"); salt participation keys server-side; correct the UI copy to match reality.

### A3. C8 — Certification (Issue 2 / Part 6) → [detail](C8-certification-faults.md)
- **Done:** v2 page computes `no_votes`/`tie` outcomes, awards 0 points on ties, derives winner house from the candidate, writes Firestore points, persists certified state.
- **Still broken:**
  - Chamber `_certifyBallotWinner` still proclaims the first sorted candidate on **ties and zero votes** (`election_chamber_screen.dart:1771-1773`), margin can be 0, always 100 points.
  - v2 local-cache fallback still **fabricates a zero-vote winner, margin 1, and 100 points** when the transaction fails (`school_elections_page.dart:1280-1315`).
  - Transaction failure still **marks certified unconditionally** (`school_elections_page.dart:1257-1277`).
  - Council managers' `house_points` Firestore write is **silently denied by rules** (admin/sports-lead only) → cache-only points for them (`school_elections_page.dart:1320-1328`).
  - Certify still allowed **while voting is open**; tally still max-merges three client-writable sources.
- **Fix:** Add tie/zero-vote guards to the chamber (abort with a message, no points, no gazette). Delete the local-cache proclamation fallback. On transaction failure, return the error — no certified marks. Award points **inside the callable** (Admin SDK bypasses rules) so all managers work. Disable Certify until `closesAt` passes. Read tallies from the single `counts/{candId}` source.

### A4. H1 — Account switching (Part 1) → [detail](H1-account-switch-identity.md)
- **Done:** re-auth runs before the cache swap (10 s timeout, rethrows in live mode); roster write now UID-guarded (`auth_service.dart:2230`).
- **Still broken:** accounts with **no saved password** still swap the cache with no re-auth at all (`auth_service.dart:2247`); demo/NoApp auth failures are still swallowed; roster provisioning is still client-side fire-and-forget.
- **Fix:** No password → prompt for it and abort the switch until auth succeeds. Block election/sensitive actions while a switch is in flight. Provision `school_members` server-side on sign-in, from authoritative data.

### A5. C9 — Republish / reset protection (Part 4) → [detail](C9-republish-reset-attack.md)
- **Done:** client-side status pre-check (`school_elections_page.dart:986-998`); scheduled `startMs` honored (`:1028-1033`).
- **Still broken:** the guard is **client-side only** — rules still allow anyone to `set`/delete polls directly (C1); publish still swallows write errors (`:1049-1051` → phantom publish); cached drafts still resurrect when the server draft is missing (`:970-978`).
- **Fix:** Lock poll/draft writes to the callable (rules `write: if false`); rethrow publish failures; drop cached drafts the server contradicts; add server `deleteDraft`/`close`/`cancel` actions with status checks.

### A6. H5 — Chamber vote validation (Part 5) → [detail](H5-chamber-vote-no-validation.md)
- **Done:** busy guard + pop-after-await (`election_chamber_screen.dart:827-951`); universal duplicate checks; live-mode failures return errors.
- **Still broken:** `castDigitalVote` performs **no status/window/eligibility checks**; name-based matching can increment **multiple same-name candidates** (`auth_service.dart:4458-4459, 4518-4519`); the else-branch still **writes vote locks for ballots that exist nowhere** (`:4490-4506`).
- **Fix:** Inside the transaction, require the ballot doc to exist and be open/in-window, else abort. Match candidates by **ID only**. Never write locks when the ballot is missing. Long-term: route chamber votes through the v2 callable.

### A7. C5 — Phantom votes (Part 5) → [detail](C5-phantom-votes.md)
- **Done:** live-mode failures rethrow / return errors; no fabricated receipts in live mode.
- **Still broken:** demo/offline mode still returns local success with a receipt; the fallback transaction still writes the **rules-denied** `elections/{id}/counts` (`school_elections_page.dart:672-673`) → votes on fallback-mirrored polls always fail (now honestly, but still broken).
- **Fix:** Remove the legacy counts write from the fallback transaction. In live mode, return success only after a server ack. Label demo/offline mode visibly in the UI so local-only votes are never mistaken for recorded ones.

---

## B. NOT DONE — audit items outside the fix claims

### B1. C1 — Rules: any signed-in user can write everything → [detail](C1-firestore-rules-public-writes.md)
- **Problem:** `firestore.rules:741-763, 890-916` — elections, votes, gazettes, polls, counts, participation, drafts, roster all public-read / any-user-write (incl. delete). Rig counts, re-vote, block others, rewrite history.
- **Fix:** All client writes `false` on election collections + `school_members` (callable uses Admin SDK, unaffected); `participation`/`election_votes` reads `false`; deploy + rules unit tests. **Highest priority — until this is done, every client-side guard above is bypassable.**

### B2. C2 — Self-service super-admin escalation → [detail](C2-super-admin-escalation.md)
- **Problem:** `isValidUser` allows `scholar_no: '11209'/'admin'` on self-create; `isSuperAdmin()` trusts the users doc (`firestore.rules:236-245, 293-318`).
- **Fix:** Reject privileged scholar numbers at create; derive authority from custom claims / `admin_roster` only; audit existing users docs.

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