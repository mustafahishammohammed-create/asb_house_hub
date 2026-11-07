# Blaze Plan Required Features — Deferred Until Upgrade

**Status:** DEFERRED by explicit user decision (2026-11-06): the project stays on the Spark (free) plan for now. Nothing in this file is broken or forgotten — it is parked until the Firebase project `asb-house-hub` is upgraded to Blaze (pay-as-you-go).

**Why these are blocked:** `firebase deploy --only functions` fails on Spark because Cloud Functions v2 requires Cloud Build and Artifact Registry, and those APIs cannot be enabled without a billing account. Confirmed deploy error: *"Your project asb-house-hub must be on the Blaze (pay-as-you-go) plan… artifactregistry.googleapis.com can't be enabled until the upgrade is complete."*

**What already works without Blaze:** Firestore security rules and Storage rules are deployed (rule deployment is free). All client-side election code, models, screens, secret handling, and tests are complete and verified. The app runs elections in demo/offline mode today.

---

## D1. Deploy Cloud Functions (the master switch)

**Command (after upgrade):**
```bash
cd functions
npm install
firebase deploy --only functions
```

Three authored, syntax-checked functions are waiting in `functions/`. None of them are live until this deploy succeeds:

### D1a. `schoolElection` callable (`functions/elections-v2.js`)
The entire live election backend. Until deployed, every live election action fails closed (Firestore rules lock direct writes with `write: if false`, and the callable URL returns 404). Features that activate on deploy:
- Live vote casting with server-side transaction locks (one scholar, one vote)
- Server-issued receipts and receipt lookup
- `getMyParticipation` batch lookup (up to 50 polls per call)
- Draft lifecycle: `create`, `add`, `remove`, `publish`, `deleteDraft` (server-side candidate management, no phantom ballots)
- Result lifecycle: `certify`, `close`, `cancel`
- Append-only audit log (`audit/{uuid}`) on all privileged actions
- Strict roster-derived winner house (no fallback house bias)
- Normalized participation keys (`scholarNo.trim().toLowerCase()` before hashing)
- App Check flag support (see D3)

### D1b. `schoolLibrary` callable (`functions/library-v2.js`)
Live library circulation: `checkout`, `return`, `renew` with server-side loan state checks.

### D1c. `verifyCertificateSignature` (`functions/index.js`)
Storage trigger on `house_claims/` uploads: Cloud Vision logo detection + OCR fallback to AI-scan competition certificates and write `ai_status`/`ai_confidence` for the staff moderation queue. **Also requires the Cloud Vision API**, which itself needs billing enabled.

**Done when:** `firebase functions:list` shows all three functions deployed, and a test call to `schoolElection` returns a proper auth error (not 404).

---

## D2. Live end-to-end smoke test (audit item B3)

Cannot run until D1 is deployed. After deploy, on a live signed-in build:
1. Staff: create draft → add candidate (roster lookup) → publish.
2. Student: vote → receive receipt → confirm second vote attempt is rejected.
3. Student: confirm participation badge shows via `getMyParticipation`.
4. Staff: close → certify → confirm gazette publishes with correct winner house and real margin.
5. Staff: cancel a test poll → confirm audit entries exist and are append-only.
6. Confirm direct Firestore client writes to `election_polls_v2` are denied by rules.

**Done when:** all six steps pass on the live project with no client-side fallback used.

---

## D3. App Check enforcement activation (mobile/web only)

The server already supports it: `functions/elections-v2.js:100` reads `ENFORCE_APP_CHECK === "true"` (currently defaults off so Windows desktop — which has no official FlutterFire App Check provider — is not locked out).

After D1, when shipping Android/iOS/web clients:
1. Register apps in Firebase App Check with Play Integrity (Android), DeviceCheck/App Attest (iOS), reCAPTCHA Enterprise (web).
2. Add client attestation activation in `lib/` before `Firebase.initializeApp` usage.
3. Set the function environment flag `ENFORCE_APP_CHECK=true` and redeploy.
4. Keep Windows desktop builds on the compensating controls (Firebase Auth + claims-based roles + locked rules + server transactions).

**Done when:** calls without a valid App Check token are rejected on mobile/web, and desktop continues to work.

---

## Go-live build reminder (not Blaze-blocked, but required for live use)

Release builds now fail closed without secrets. Any live build must supply:
```bash
flutter build windows --release --dart-define=ELECTION_HMAC_SALT=<value> --dart-define=VAULT_SECRET=<value> --dart-define=GAMIFICATION_HMAC_SECRET=<value> --dart-define=SPORTS_CERT_SECRET=<value>
```
Without these, election hashing and vault operations throw `StateError` by design (audit items A1/A2), and gamification/sports token minting fails closed (G2). Test harnesses inject ephemeral values via `setTestSalt`/`setTestSecret` and never ship them.

---

## D4. Gamification / points server authority (from gamification_audit)

The points audit (`gamification_audit/README.md`, 2026-11-07) found the student points economy was phantom without a server (G1). **All interim no-Blaze hardening is now complete and independently verified** (round 6, `753c976`): truthful failures, secret eradication, rules validators/bounds, council/captain privileges, per-student submissions, cache provenance — G1–G13 and R-1..R-7/N-1/N-2 all closed in `gamification_audit/REMEDIATION_ROADMAP.md` P0–P2. Student live awards remain intentionally fail-closed until the server authority below ships. The real fix needs:

1. **`schoolGamification` callable** (new, to be authored): server-side activity validation, Firestore-backed cooldowns with server timestamps, atomic awards, idempotency keys, consumed-nonce store, append-only audit log. Then lock `house_points`/`house_contributors` direct writes in rules.
2. **Sports certification callable**: mint/verify match tokens server-side; remove the client salt.
3. **Live points smoke test**: student earns → ledger reflects it exactly once; sports lead cannot exceed bounds; replay/clock tricks rejected; election certify leaves the local cache equal to the server ledger (G12 in `gamification_audit/FINAL_POINTS_REPORT.md`).

Interim no-Blaze hardening (truthful failures, secret eradication, rules validators) is **done** — tracked and closed in `gamification_audit/REMEDIATION_ROADMAP.md` P0–P2 (verified 2026-11-08).

**Done when:** the callable is deployed, direct points writes are locked, and the live points smoke test passes.

---

## Completion order when Blaze is available

1. Upgrade project to Blaze in Firebase Console (billing).
2. D1: deploy functions (enable Cloud Build, Artifact Registry, Cloud Vision APIs if prompted).
3. D2: run the live smoke test checklist.
4. D3: activate App Check when mobile/web clients ship.
5. D4: author + deploy `schoolGamification`, then run the live points smoke test.
6. Check the boxes above and update `election_audit/README.md` — only then are B1/B3 from `NOT_DONE_AND_FALSE_CLAIMS.md` closed.