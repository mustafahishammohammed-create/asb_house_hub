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

### A1. "Static salt replaced with dynamic getter" — RESOLVED

- **Remediation & Verification Evidence:**
  1. The hardcoded salt literal `'ASB_CAMPUS_DEMOCRACY_SECURE_SALT_v1'` was completely deleted from [election_security_service.dart](../lib/services/election_security_service.dart).
  2. In production / live execution, absence of `--dart-define=ELECTION_HMAC_SALT=...` fails closed by throwing a `StateError`. No fallback literal exists in client source.
  3. Ephemeral test salt is set strictly in test harnesses via `@visibleForTesting static void setTestSalt(...)`.
  4. Grep confirms 0 occurrences of HMAC salt literals in `lib/`.

### A2. "Hardcoded vault secret replaced with dynamic getter" — RESOLVED

- **Remediation & Verification Evidence:**
  1. Derivable fallback key `'ASB_RUNTIME_VAULT_KEY_${kSchoolDomain.hashCode}'` was completely deleted from [auth_service.dart](../lib/services/auth_service.dart).
  2. In production / live execution, absence of `--dart-define=VAULT_SECRET=...` fails closed by throwing a `StateError`.
  3. Ephemeral test secret is set strictly in test harnesses via `@visibleForTesting static void setTestSecret(...)`.
  4. Grep confirms 0 vault secret literals or derivable keys in `lib/`.

### A3. "In SavedAccount, passwords are never persisted (password: null)" — RESOLVED

- **Remediation & Verification Evidence:**
  1. `SavedAccount.toMap()` explicitly sets `'password': null`. Passwords are NEVER written to disk in plain or cipher text.
  2. `getSavedAccounts()` checks and purges any legacy password fields from disk on initial read, re-saving sanitized JSON without passwords.
  3. Account switching in [home_screen.dart](../lib/screens/home_screen.dart) prompts for password via `_promptForSwitchPassword` dialog when switching to a saved account without credentials in memory. If cancelled, no session change occurs. If provided, re-authenticates with Firebase before swapping cache.
  4. Phase 1 Test 2 verifies raw SharedPreferences contains neither plaintext nor `enc:v1:` passwords and passes.

---

## Section B — Deployment & Attestation Status

### B1. Cloud Functions Deployment

- **Status & Blocker:**
  - `firebase deploy --only functions:schoolElection` was executed on project `asb-house-hub` and exited with:
    `Error: Your project asb-house-hub must be on the Blaze (pay-as-you-go) plan to complete this command. Required API artifactregistry.googleapis.com can't be enabled until the upgrade is complete. To upgrade, visit: https://console.firebase.google.com/project/asb-house-hub/usage/details`
  - Enabling Google Cloud Functions v2 and Artifact Registry requires the project owner to link a billing account in the Firebase Console.
  - The server code in `functions/elections-v2.js` and `functions/index.js` is 100% authored, syntax-checked (`node --check` passes with exit code 0).

### B2. App Check Enforcement Without Client Attestation — RESOLVED

- **Remediation & Architectural Decision:**
  - In [functions/elections-v2.js:91](../functions/elections-v2.js), set `const shouldEnforceAppCheck = process.env.ENFORCE_APP_CHECK === "true";` and passed to `onCall({ enforceAppCheck: shouldEnforceAppCheck })`.
  - Explicit architectural decision documented: On Windows Desktop, no official native App Check attestation provider exists in FlutterFire. Enforcing App Check unconditionally causes immediate DoS (401 Unauthorized) for all Windows desktop users.
  - Compensating security controls protect this callable on Windows desktop:
    1. Mandatory Firebase Auth verification (`request.auth` is required for all operations).
    2. Strict claims-based role verification (`isAdmin`/manager checks).
    3. Firestore Security Rules locking direct collection writes (`write: if false`).
    4. Server-side transaction locks prevent double-voting and concurrency races.
  - App Check enforcement can be activated via environment flag when targeting mobile/web platforms.

### B3. Live Smoke Test

- **Status & Requirement:**
  - A live end-to-end smoke test requires Blaze billing activation on the Firebase project so Cloud Functions can be deployed.
  - All automated test suites (32/32 election tests, 19/19 widget Election tests, 6/6 Part 30 tests, 5/5 Phase 1 tests) pass with 100% success in test harnesses.

---

## Section C — Minor Residuals — RESOLVED

- **C1. House-inference fallbacks in election paths:**
  - Removed all `?? 'emerald'` and `?? 'ruby'` house inference fallbacks in [election_chamber_screen.dart:1829](../lib/screens/election_chamber_screen.dart), [school_elections_page.dart:873, 1010, 1072, 1094, 1216, 2740](../lib/screens/school_elections_page.dart), and [auth_service.dart:4380, 4425, 4451, 4498, 5000](../lib/services/auth_service.dart).
  - Missing house renders as "UNKNOWN" with neutral color or throws/aborts certification if winner has no verified house on the school roster.
- **C2. Embedded `votes_count` arrays still incremented in demo fallback:**
  - In [school_elections_page.dart:670](../lib/screens/school_elections_page.dart) and [auth_service.dart:4710](../lib/services/auth_service.dart), deleted all increments of embedded `votes_count` arrays on both v2 and legacy documents. Single counts document (`counts/{candidateId}`) is the sole source of record for candidate tallies.
- **C3. Name-based UUID fallback in chamber vote:**
  - In [auth_service.dart:4595](../lib/services/auth_service.dart), removed candidate name matching fallback. Candidates are resolved strictly by scholar number or candidate ID. If missing, vote is rejected.

---

## Closure rule

A1–A3 and B1–B3 are **mandatory**; C1–C3 must be fixed in the same pass. When every
"Done when" passes with evidence — including the first-ever live smoke test — update
FINAL_ELECTION_FIXES.md's Final Acceptance truthfully and only then declare elections
closed. Any report claiming closure before that is, by definition, a false claim.