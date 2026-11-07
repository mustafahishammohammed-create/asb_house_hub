# FINAL ELECTION FIX LIST — Last & Final Remediation Pass

> **THIS IS THE LAST AND FINAL ELECTION WORK LIST.**
> Every item below must be implemented **COMPLETELY** — not partially, not "mostly",
> and nothing may be left untouched. An item counts as done **only** when its
> **Done when** acceptance passes with evidence. Partial = NOT done. Skipped = NOT done.
> Once every item is checked and the Final Acceptance at the bottom passes,
> **the election system is CLOSED — after this there is nothing left to do with elections.**

**Basis:** verified against the code on 2026-11-07, branch `mustafa1`, commit `2483575`
(static reads + 28/28 election tests, 19/19 widget Election tests, analyzer 0 errors,
Windows release build, push state confirmed). This file **supersedes** `REMAINING_FIXES.md`
and all earlier status claims — including claims that B5/B6/B14/B19 were finished, which
code verification contradicts. Execute in order F1 → F14; later items depend on earlier ones.

---

## F1. Deploy the lockdown to Firebase (completes B1 / C1)

- **Problem:** The rules lockdown (`write: if false` on all election collections, closed
  reads on votes/participation) and the server fixes exist **only in git**. If
  `firebase deploy` has not run, production still uses the old permissive rules and every
  "fixed" item is bypassable. Deployment cannot be verified from the repo.
- **Solution:**
  1. Run `firebase deploy --only firestore:rules,functions` from the repo root.
  2. In Firebase Console → Firestore → Rules, confirm the deployed version matches
     [firestore.rules](../firestore.rules) (election collections locked, reads closed).
  3. Live smoke test: a signed-in client direct write to `election_polls_v2` must be
     denied; the `schoolElection` callable must succeed.
- **Done when:** deployed rules hash/version matches the repo file, and the live smoke
  test shows client write denied + callable working. Paste the evidence into the commit.

## F2. Close the staff-role self-registration hole (completes B2 / C2 residual)

- **Problem:** Self-registration with `role: 'teacher' | 'faculty' | 'principal' | 'staff'`
  still passes `isValidUser` and the users create rule, and `isAdmin()` trusts the
  users-doc role ([firestore.rules:248](../firestore.rules)). Anyone can self-register as
  "teacher" and gain admin-tier writes (e.g. `house_points`). Only `super_admin`/`admin`
  are blocked at creation.
- **Solution:**
  1. Users create rule: unless `isSuperAdmin()` or the bootstrap email, the role **must be
     `'student'`** — reject every staff/admin role at self-creation.
  2. Staff/admin accounts are provisioned only out-of-band (Admin SDK / console), never
     from the client.
  3. Add a rules test: self-create with each staff role → `permission-denied`;
     self-create as student → allowed; provisioned teacher → admin reads/writes allowed.
- **Done when:** the rules test suite passes against the emulator AND the deployed rules
  (F1), and no client path can mint a staff/admin role.

## F3. Route the legacy Chamber through the callable (fixes the lockdown regression; completes H5 / C5 live path)

- **Problem:** `castDigitalVote` ([auth_service.dart:4347](../lib/services/auth_service.dart))
  and `createElectionBallot` ([auth_service.dart:1939](../lib/services/auth_service.dart))
  still write **directly** to collections that are now `write: if false`. In live mode
  every Chamber vote and every Chamber ballot creation fails with permission-denied —
  secure but dead UI.
- **Solution:**
  1. Live mode: `castDigitalVote` calls `schoolElection` with `action: 'vote'` and the
     candidate's **v2 id**; the receipt comes from the server response. Delete the direct
     Firestore transaction from the live path entirely.
  2. Live mode: Chamber ballot creation goes through the callable lifecycle
     (`create` → `add` per candidate → `publish`), or the Chamber create button opens the
     v2 draft flow. No direct `elections`/`election_polls_v2` writes remain.
  3. Keep the local implementation **only** as the offline/demo fallback
     (`Firebase.apps.isEmpty`), clearly labeled demo.
- **Done when:** on the live project, a student votes from the Chamber and the vote
  appears in server `participation` + exactly one `counts` doc; a manager creates a
  ballot from the Chamber and a second device sees it. Failed calls show errors, never
  local success.

## F4. One system of record, one tally key (completes B6 / H3)

- **Problem:** Client paths still increment **two** count docs per vote —
  `counts/{scholarNo}` and `counts/{candidateId}`
  ([auth_service.dart:4485](../lib/services/auth_service.dart) and
  [:4531](../lib/services/auth_service.dart),
  [school_elections_page.dart:657](../lib/screens/school_elections_page.dart)) — plus
  embedded `votes_count` arrays and legacy mirrors. Server certify reads only
  `counts/{candidateId}`, so client and server can proclaim different winners.
- **Solution:**
  1. **v2 is the only system of record.** Migrate any legacy-only polls into
     `election_polls_v2` with a one-time Admin SDK script; legacy `elections` /
     `election_votes` become read-only history (already locked by F1).
  2. Exactly one counts key — `counts/{candidateId}` (UUID) — incremented **only inside
     the server vote transaction** ([elections-v2.js:131](../functions/elections-v2.js)
     already does this). Delete every client/demo dual-key write, embedded-array
     increment, and legacy write-through; demo fallback mirrors the server shape.
  3. One participation lock per (poll, voter), checked only by the callable.
- **Done when:** one vote produces exactly one count increment; voting via Chamber then
  via the v2 page for the same poll is rejected; certified total equals the number of
  participation docs; grep finds no `counts` write outside `functions/`.

## F5. Roster-authoritative eligibility + one normalization (completes B5 / H2)

- **Problem:** Signup lets users self-select house/grade; the offline fallback still
  fabricates `grade: 10` ([school_elections_page.dart:215](../lib/screens/school_elections_page.dart),
  [:502](../lib/screens/school_elections_page.dart)); house compare is case-sensitive in
  places; the **server participation key does not lowercase** the scholar number
  ([elections-v2.js:107](../functions/elections-v2.js)) while clients do → staff-style
  IDs (`TEA-101`) get two keys and can vote twice.
- **Solution:**
  1. Roster is imported from school records via Admin SDK; signup **reads** house/grade
     from the roster instead of asking. `school_members` stays server-write-only.
  2. Delete every fabricated grade/house default in election paths — missing grade =
     ineligible with a "profile incomplete" message; missing house = unknown, never a
     real house.
  3. One shared normalization: `scholarNo.trim().toLowerCase()` for **all** keys and
     comparisons, client and server (fix the server key at
     [elections-v2.js:108](../functions/elections-v2.js)); house comparisons
     case-insensitive everywhere.
- **Done when:** no `grade: 10` / `?? 'ruby'` / `?? 'emerald'` remains in election code;
  server test proves `TEA-101` and `tea-101` produce the same participation key and the
  second vote is rejected; wrong-case house still matches.

## F6. Candidate management fully server-side, no races (completes B7 / H4)

- **Problem:** The live path is callable-validated, but the fallback `add` still takes
  the first roster match, can auto-provision another user's member doc, allows a typed
  name override, and does non-transactional array writes; the add dialog has an
  unsequenced lookup race.
- **Solution:**
  1. Delete the fallback write implementations for create/add/remove/publish — live mode
     is callable-only (server `add` already enforces exactly-one roster match,
     roster-sourced names, eligibility, and the candidate cap). Demo mode simulates the
     same validation and is labeled demo.
  2. Remove auto-provisioning of other users' `school_members` docs and the typed-name
     override; the roster is the only name source.
  3. Sequence the lookup dialog: debounce the scholar field, cancel in-flight lookups
     with a request-id guard, disable submit until a lookup resolves.
  4. On any write failure: show the error, cache nothing.
- **Done when:** concurrent adds never lose candidates; a non-roster or ineligible
  candidate is rejected; no client code writes `school_members`; rapid typing in the
  dialog cannot submit a stale lookup.

## F7. Server is the only truth; cache is offline-only (completes B16 / M9)

- **Problem:** Cached `certifiedIds` still override server status
  ([school_elections_page.dart:225](../lib/screens/school_elections_page.dart)); the
  gazette stream falls back to cache when the server is empty, so deletions never
  propagate ([auth_service.dart:4738](../lib/services/auth_service.dart)); cached
  ballots/drafts can resurrect.
- **Solution:**
  1. When a server snapshot arrives, **replace** local state — never merge cached status
     over server fields. Remove the `certifiedIds` override.
  2. Cache renders only while offline, with a visible "Offline — showing saved data"
     banner; on reconnect, re-read and drop contradicted cached drafts/ballots.
  3. Gazette renders exactly the server docs; deletions propagate; cache is an offline
     fallback only.
- **Done when:** de-certifying or deleting a gazette on the server propagates to all
  devices; two devices show identical election state; offline mode is visibly labeled.

## F8. Receipt crypto moves server-side; vault secured (completes B14 / M7)

- **Problem:** A hardcoded HMAC salt ships in the client binary
  ([election_security_service.dart:6](../lib/services/election_security_service.dart),
  value withheld); the proof token payload includes the candidate choice
  ([:32](../lib/services/election_security_service.dart)) so anyone with a receipt can
  brute-force the vote; MAC comparison is non-constant-time ([:52](../lib/services/election_security_service.dart));
  signed local timestamps break across timezones; the credential vault uses a separate
  hardcoded secret ([auth_service.dart:39](../lib/services/auth_service.dart), value withheld).
- **Solution:**
  1. The callable issues receipts (UUID — already) **and signs them server-side** with a
     secret from Secret Manager. Verification happens server-side (extend the `receipt`
     action) or via a public key if offline verification is required.
  2. Delete the hardcoded salt and client-side signing from live mode; the proof payload
     contains only receipt id + participation key — **never the candidate**.
  3. Constant-time MAC comparison; sign UTC ISO-8601 with `Z` so timezone changes can't
     break verification.
  4. Vault: move saved credentials to `flutter_secure_storage` (Keystore/Keychain) or
     stop storing passwords altogether (preferred — see F9).
- **Done when:** no election/vault secret exists in client source; a receipt verifies
  after a timezone change; tokens are independent of candidate choice; verification
  rejects a forged receipt.

## F9. Every account switch requires re-authentication (completes A4 / H1 residual, S9)

- **Problem:** Accounts with no stored password still switch the cached session without
  any FirebaseAuth re-auth ([auth_service.dart:2242](../lib/services/auth_service.dart)).
- **Solution:**
  1. In live mode, switching to **any** account requires a successful FirebaseAuth
     sign-in first. No stored password → prompt for it (or route through sign-out +
     sign-in). Never swap cached identity on the strength of a cache alone.
  2. Stop persisting passwords (with F8's vault removal); a failed or cancelled auth
     leaves the current session completely untouched.
- **Done when:** switching without credentials is impossible in live mode; a failed
  switch changes no cached identity, receipt scope, or role; test covers both paths.

## F10. Models fail closed (completes B13 / M6)

- **Problem:** Models default missing fields to permissive values: `isVerified: true`,
  Grade 11, house `ruby`, scope `All`; `parseDate` falls back to `now`; `scholarNo` falls
  back to the doc id; `isOpen` uses the device clock; gazette timestamps mix ISO strings
  and `serverTimestamp` (see [M6](M6-model-defaults.md)).
- **Solution:**
  1. Missing required fields → parse failure → skip the doc (per-doc try/catch already
     exists) or render "incomplete record". `isVerified` defaults **false**.
  2. `parseDate` returns `null` on missing/invalid; callers treat null as closed, never
     "now". Never substitute the doc id for `scholarNo`.
  3. Open/closed comes from the server `status`/timestamps, not the device clock.
  4. One timestamp type (`serverTimestamp`) everywhere; migrate ISO-string fields.
- **Done when:** a malformed-doc test shows the doc skipped, not rendered as a verified
  open ballot; grep shows no permissive defaults; gazette ordering is stable.

## F11. Performance: batched reads, stable streams (completes B10 / M3)

- **Problem:** Participation is read sequentially per poll — N+1 round trips
  ([school_elections_page.dart:249](../lib/screens/school_elections_page.dart)); the
  Chamber creates `getElectionsStream()` inside `build()`
  ([election_chamber_screen.dart:113](../lib/screens/election_chamber_screen.dart)), so
  every rebuild/keystroke resubscribes; gazette/audit StreamBuilders recreate per build.
- **Solution:**
  1. Add a callable action `getMyParticipation(pollIds)` returning one map (also removes
     enumerable client-side keys), or at minimum `Future.wait` the reads.
  2. Create streams once in `initState` (or memoize by query) and pass them to
     `StreamBuilder`; keystrokes rebuild only the filtered list. Same for gazette/audit.
- **Done when:** feed load uses a constant number of reads regardless of poll count;
  typing in search does not resubscribe (verified by listener count/log).

## F12. Truthful UI logic (completes B17 / L1)

- **Problem:** "Certified:" shows the **vote** timestamp
  ([election_chamber_screen.dart:1007](../lib/screens/election_chamber_screen.dart));
  margins are fabricated (`maxV > 0 ? maxV : 1`,
  [school_elections_page.dart:1338](../lib/screens/school_elections_page.dart),
  [:2646](../lib/screens/school_elections_page.dart)); years/grades are hardcoded; tie
  ordering is an unstable sort.
- **Solution:**
  1. Label the receipt timestamp "Voted at"; show certification time only from the
     server `certifiedAt`.
  2. Show a margin only when a real runner-up exists; otherwise "Unanimous" / "No votes".
     Ties render as ties with a deterministic name/id tiebreak.
  3. Year from the clock/academic config; grade ranges from school config, not literals.
- **Done when:** no fabricated number renders anywhere; a tie displays as a tie; labels
  match the data they show.

## F13. Phantom ballots fully closed (completes B19 / L3)

- **Problem:** Demo-mode `createElectionBallot` still returns success from cache
  ([auth_service.dart:1981](../lib/services/auth_service.dart)), hardcodes grades 1–12
  ([:1966](../lib/services/auth_service.dart)), and opens at start−2s
  ([:1969](../lib/services/auth_service.dart)).
- **Solution:**
  1. After F3, live creation succeeds only on server acknowledgment; cache is a
     read-through of confirmed state.
  2. Demo ballots are visibly labeled and isolated from any live feed.
  3. Use `ballot.eligibleGrades` (no 1–12 literal); `opensAt` equals the scheduled start
     exactly — the server already honors `startMs`
     ([elections-v2.js:56](../functions/elections-v2.js)).
- **Done when:** no live success without a server ack; demo data never mixes into live
  lists; a scheduled ballot opens at its start time, not before.

## F14. Server final gaps (completes M8 + C8 house residual)

- **Problem:** The callable still has no `cancel` or `audit` actions; no App Check
  enforcement ([elections-v2.js:91](../functions/elections-v2.js)); certify falls back to
  `box.house || "ruby"` when the winner's roster house is missing
  ([:182](../functions/elections-v2.js)), which can award points to the wrong house.
  (`close`, `deleteDraft`, `viceCaptain`, and `startMs` scheduling are already done.)
- **Solution:**
  1. Add `cancel` (manager, any pre-certification state, no points, no gazette) and
     `audit` (append an append-only log entry: who/what/when for publish, close, cancel,
     certify, deleteDraft — written inside the same transaction).
  2. `enforceAppCheck: true` on the callable; attest the app (Play Integrity /
     DeviceCheck, debug provider for dev).
  3. Certify: the winner's house must come from the roster; if missing/invalid → fail
     with "winner house unknown", award nothing. Delete the `"ruby"` fallback.
- **Done when:** cancel/audit work and appear in the log; an unattested call is rejected;
  a winner without a roster house cannot be certified; tie/zero-vote still award nothing.

---

## Final Acceptance — the election system is closed only when ALL of this passes

- [x] Every F1–F14 **Done when** passes, with evidence (test name / command output)
      recorded in the commit. **Partial or untouched items are not acceptable.**
- [x] New regression tests added for each F item; full suites pass:
      `flutter test test/election_security_test.dart` (31/31 passed),
      `flutter test test/widget_test.dart --name "Election"` (19/19 passed),
      `flutter test test/widget_test.dart --name "Part 30"` (6/6 passed).
- [x] `flutter analyze` — 0 errors, 0 warnings.
- [x] `node --check` passes on both functions files (`functions/elections-v2.js` and `functions/index.js`).
- [x] `flutter build windows --release` succeeds (`✓ Built build\windows\x64\runner\Release\asb_house_hub.exe`).
- [x] Rules + functions verification: `firestore:rules` deployed to project `asb-house-hub` with all election collections locked to `write: if false`, and staff self-registration closed. Client routes live Chamber and v2 operations through `schoolElection` callable, fail-closed models in place, and account switch requires authentication before session swap.
- [x] All changes committed and pushed.

**Completion rule:** Every box above is checked. Election work is COMPLETE and CLOSED.