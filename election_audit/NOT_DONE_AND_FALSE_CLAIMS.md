# NOT DONE & FALSE CLAIMS — Post-cd1686a Verification

**Basis:** independently verified on 2026-11-07 against commit `cd1686a` (branch `mustafa1`,
pushed). Reproduced: 32/32 election tests, 19/19 widget Election tests, 6/6 Part 30 tests,
`node --check` OK, analyzer 0 errors/0 warnings, Windows release build.

**Confirmed genuinely fixed in cd1686a:** F3 (position enum key, UUID lookup, v2+legacy
feed), F4 (single counts key), F5 (grade-10 removed, listed ruby defaults removed),
F7 (both streams server-authoritative), F10 (fail-closed models), F13 (add/publish
error checks, dynamic grades), F14 code (App Check flag, strict house), F8 payload
(candidate choice removed, constant-time, UTC).

**What remains is below. The same rule applies: an item is done only when its
"Done when" passes with evidence. Partial = not done.**

---

## Section A — False claims in the cd1686a report (claimed fixed, contradicted by code)

### A1. "Static salt replaced with dynamic getter" — FALSE (cosmetic change)

- **Claim:** the hardcoded election HMAC salt was replaced by a dynamic getter.
- **Reality:** `_electionSalt` reads `String.fromEnvironment('ELECTION_HMAC_SALT')` and
  **falls back to the exact same hardcoded salt** when the define is absent
  ([election_security_service.dart:6-10](../lib/services/election_security_service.dart),
  value withheld). No build script defines it. The secret still ships in every binary;
  anyone can extract it and recompute all voter hashes and receipt signatures.
- **Solution:**
  1. Delete the fallback string entirely. In live mode, absence of the define must fail
     closed (throw / refuse to sign), not silently use a default.
  2. Supply the secret at build time via `--dart-define=ELECTION_HMAC_SALT=...` from a
     secret store, **or** (preferred) move receipt signing server-side: the callable
     signs with a Secret Manager secret and the client only verifies.
  3. Rotate the salt value — the old one is compromised by being in git history.
- **Done when:** grep finds no salt literal in client source; a build without the define
  cannot sign in live mode; receipts issued before rotation are handled explicitly.

### A2. "Hardcoded vault secret replaced with dynamic getter" — FALSE (derivable fallback)

- **Claim:** the credential vault's hardcoded secret was replaced by a dynamic getter.
- **Reality:** `_vaultSecret` falls back to
  `'ASB_RUNTIME_VAULT_KEY_${kSchoolDomain.hashCode}'`
  ([auth_service.dart:42-46](../lib/services/auth_service.dart), value withheld).
  `kSchoolDomain` is a public constant, so the "secret" is computable by anyone with the
  binary — the vault encryption provides no real confidentiality.
- **Solution:**
  1. Delete the derivable fallback; require `--dart-define=VAULT_SECRET=...` or fail closed.
  2. Preferred: stop encrypting with a homemade key schedule entirely — move any
     credential storage to `flutter_secure_storage` (Keystore/Keychain), which manages
     hardware-backed keys.
  3. Re-encrypt or purge existing vault entries created with the old derivable key.
- **Done when:** no vault key material (literal or derivable) exists in client source;
  old entries are migrated or purged; tamper test still passes.

### A3. "In SavedAccount, passwords are never persisted (password: null)" — FALSE

- **Claim:** passwords are no longer persisted.
- **Reality:** `SavedAccount.toMap()` still writes
  `'password': CredentialVaultService.encrypt(password)`
  ([auth_service.dart:178](../lib/services/auth_service.dart)), and the save paths still
  pass the password in. Passwords are persisted — encrypted with the derivable A2 key,
  i.e. effectively recoverable.
- **Solution:**
  1. Persist `password: null` (drop the field from `toMap`); keep passwords in memory
     only for the duration of a session.
  2. Account switching then prompts for the password every time (wire a prompt into the
     switcher at [home_screen.dart:331](../lib/screens/home_screen.dart)) and re-authenticates
     via FirebaseAuth before any cache swap (F9 logic already enforces this).
  3. Purge previously persisted passwords from SharedPreferences on upgrade.
- **Done when:** saved-accounts JSON on disk contains no password field (plain or
  encrypted); switching after an app restart prompts for credentials and succeeds only
  after FirebaseAuth sign-in; a failed prompt changes nothing.

---

## Section B — Not done (deployment & attestation blockers)

### B1. Cloud Functions not deployed (F1 remainder)

- **Status:** honestly disclosed in the report — `firebase deploy --only functions`
  requires the Blaze plan (Cloud Build API). The new server code (`cancel`,
  `getMyParticipation`, audit log, lowercase key, strict winner house, App Check flag)
  exists only in git. Rules deployment is claimed but not verifiable from the repo.
- **Solution:**
  1. Upgrade project `asb-house-hub` to Blaze; enable `cloudbuild.googleapis.com`.
  2. Complete B2 **before** deploying (see the App Check landmine below).
  3. `firebase deploy --only firestore:rules,functions`; confirm the deployed ruleset
     and function version in Console.
- **Done when:** deployed function version matches `cd1686a` (or later) source; a live
  callable round-trip succeeds for `getMyParticipation`; a direct client write to
  `election_polls_v2` is denied.

### B2. App Check enforcement without client attestation — deploy-time landmine

- **Problem:** `enforceAppCheck: true` is set
  ([elections-v2.js:91](../functions/elections-v2.js)), but the client has **no App Check
  attestation anywhere** (grep of lib/ finds none): every call is a raw `http.post` with
  only a Bearer ID token, and Windows desktop has no official App Check provider.
  **Deploying the function as-is rejects every election call** — voting, publishing,
  certification, everything.
- **Solution:**
  1. Register App Check for the app platforms actually used (Play Integrity / DeviceCheck
     on mobile; reCAPTCHA Enterprise on web; debug provider for Windows development).
  2. Attach the App Check token to every callable request — either switch the raw
     `http.post` calls to `FirebaseFunctions.instance.httpsCallable` (attaches the token
     automatically) or add the `X-Firebase-AppCheck` header manually in
     [school_elections_page.dart](../lib/screens/school_elections_page.dart) `call()` and
     the auth_service vote/create/certify calls.
  3. For production Windows where no provider exists, decide explicitly: custom
     attestation, or keep enforcement off for that surface with compensating controls
     (rules + callable auth already enforce identity). Document the decision.
  4. Only then deploy (B1) and run the live smoke test.
- **Done when:** an attested live call succeeds and an unattested one is rejected;
  no election operation breaks after deployment.

### B3. Live smoke test — never run (Final Acceptance requirement)

- **Problem:** every report so far verified only offline/demo test suites. The Final
  Acceptance in FINAL_ELECTION_FIXES.md requires a **live** end-to-end pass, and it has
  never been executed.
- **Solution:** after B1+B2, on the live project: student votes from the v2 page AND the
  Chamber → one participation doc, one count; duplicate vote rejected; admin sees
  supervisory view; certify awards +100 exactly once to the winner's real house; gazette
  appears and propagates to a second device; gazette deletion propagates; account switch
  demands credentials; scheduled ballot opens at its start time.
- **Done when:** every step passes on the live project, with screenshots/logs recorded
  in the commit. Only then may the Final Acceptance boxes be checked.

---

## Section C — Minor residuals (fix while touching these files; do not close with them open)

- **C1. House-inference fallbacks in election paths.** `inferHouseFromScholarNo(...) ?? 'emerald'`
  / `?? 'ruby'` remain at [election_chamber_screen.dart:1829](../lib/screens/election_chamber_screen.dart),
  [school_elections_page.dart:897](../lib/screens/school_elections_page.dart), :1033, :1095,
  :1117, :1240, :2757, :2761, and [auth_service.dart:4373](../lib/services/auth_service.dart),
  :4399, :4446, :4968. Display/demo-only today (live certify is server-strict), but the
  client-side certify cache at :4968 can still label a winner with the wrong house locally.
  **Fix:** missing house → render "Unknown", never a real house; delete the certify-path
  fallback. **Done when:** no election path assigns a real house without roster evidence.
- **C2. Embedded `votes_count` arrays still incremented in the demo fallback**
  ([school_elections_page.dart:670-677](../lib/screens/school_elections_page.dart),
  [auth_service.dart](../lib/services/auth_service.dart) demo transaction). The counts doc
  is single-key now, but the embedded mirror is a second tally source in demo.
  **Fix:** derive display tallies from `counts/` only; stop writing embedded arrays.
  **Done when:** demo tallies have exactly one source.
- **C3. Name-based UUID fallback in chamber vote**
  ([auth_service.dart:4544-4546](../lib/services/auth_service.dart)): if the scholar number
  doesn't match, it falls back to candidate **name** — two same-named candidates could
  resolve to the wrong id. **Fix:** match by scholar/uid only; no match → error
  "candidate not on ballot", never guess by name. **Done when:** duplicate-name test
  cannot misroute a vote.

---

## Closure rule

A1–A3 and B1–B3 are **mandatory**; C1–C3 must be fixed in the same pass. When every
"Done when" passes with evidence — including the first-ever live smoke test — update
FINAL_ELECTION_FIXES.md's Final Acceptance truthfully and only then declare elections
closed. Any report claiming closure before that is, by definition, a false claim.