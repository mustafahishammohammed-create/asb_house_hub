# Blaze requirements and backend readiness

Updated: **26 November 2026**. Project: `asb-house-hub`.

This replaces the earlier contradictory completion claims. The last recorded project decision is to remain on Spark. This audit did not change billing or deploy anything. A read-only `firebase functions:list --project asb-house-hub --json` check returned `{"status":"success","result":[]}`: **no Cloud Functions are currently deployed**. Billing linkage and Storage initialization were not independently rechecked.

See the [deep audit](../ASB_HOUSE_HUB_DEEP_AUDIT_2026-11-26.md) for confirmed defects, fixes, evidence, and the remaining release blockers. Upgrading billing does not implement missing code, repair authorization, connect the UI, or establish production readiness.

## What actually requires Blaze

| Capability | Firebase billing requirement | Repository state |
|---|---|---|
| Deploy Firebase Cloud Functions | Blaze | Three exports authored; none deployed; production prerequisites remain |
| Cloud Storage uploads/downloads | Blaze | SDK/REST upload paths and rules exist; owner binding and trigger safety need work |
| Cloud Vision certificate analysis via the Storage trigger | Billing-enabled Vision plus Functions and Storage | Authored heuristic; not signature authentication; unsafe to deploy as-is |
| Firestore rules, schema fixes, transactions, client bug fixes | No Blaze requirement within Spark limits | Must be fixed now; do not defer them to billing |
| Trusted server services hosted elsewhere | Depends on that hosting provider | Blaze is required for the proposed Firebase Functions implementation, not for every possible backend |
| Native Apple/Google Wallet signing | Issuer credentials and a trusted signer | Not authored; a Firebase-hosted signer would require Blaze |
| Gemini Developer API | Its own model/account quotas and billing | Firebase Blaze does not repair deprecated model IDs or provision Gemini credentials |

Firebase documents the Storage Blaze requirement as effective starting **3 February 2026**, including continued access to legacy default buckets. The old wording “Blaze may be required for new projects” is obsolete. [Firebase Storage billing changes](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)

## D1. Cloud Functions deployment — authored, not release-ready

Exports in `functions/index.js`:

1. `schoolElection` from `functions/elections-v2.js`: lifecycle, voting, receipt lookup, participation, certification, and audit writes.
2. `schoolLibrary` from `functions/library-v2.js`: transactional checkout, return, and one renewal.
3. `verifyCertificateSignature`: Storage finalization trigger using Vision logo/text detection.

The audit fixed cancelled-poll certification, incorrect winner scholar numbers, and missing candidate mutation audit entries. Emulator tests cover those paths and duplicate voting. That is local behavioral verification, not an HTTP/Auth/App Check or deployed service smoke test.

Prerequisites before deployment:

- Use the pinned Node.js **22** runtime. The former `>=18` declaration did not select a safe deployment target. Node 18 and Node 20 are past their published decommission dates; Node 22 is supported on the audit date. [Cloud Run functions runtime schedule](https://docs.cloud.google.com/functions/docs/runtime-support)
- Resolve the remaining dependency advisories and validate upgrades. Compatible updates removed the high/critical production advisories; moderate advisories remain. Do not blindly use `npm audit fix --force`.
- Provision trustworthy school membership and capability records. The client still maps teachers to `role: admin` and swallows failed provisioning; the hardened rules now require a super admin to grant roster roles/capabilities.
- Remove live privileged election fallbacks and lock published poll/draft/gazette mutations to the intended server lifecycle. Only counts and participation are presently client-write-disabled.
- Repair the certificate pipeline in D9. Do not deploy the trigger with its current overwrite/race behavior.
- Choose function/bucket regions, service identities, secrets, timeouts, instance limits, and monitoring deliberately; verify bucket-trigger compatibility.

Local validation from the repository root:

```powershell
npm --prefix functions ci
npm --prefix functions run check
firebase emulators:exec --project demo-asb-audit --config firebase.audit.json --only firestore "node --test functions/test/security.test.js"
```

Only after implementation, verification, and the chosen billing upgrade:

```powershell
firebase deploy --only firestore:rules --project asb-house-hub
firebase deploy --only storage --project asb-house-hub
firebase deploy --only functions --project asb-house-hub
firebase functions:list --project asb-house-hub
```

**Done when:** required functions are deployed, real signed-in requests pass end-to-end tests, unauthorized requests fail, errors are surfaced truthfully, and monitoring is working. A 404 disappearing is insufficient.

## D2. Election end-to-end acceptance — pending

- Staff: provision an authorized manager; create a draft; add/remove candidates; publish.
- Student: eligibility derives from a verified roster, not self-entered signup data.
- Vote twice, concurrently, from two devices: exactly one count and one receipt.
- Reload/reinstall/switch accounts: participation remains correct. Batch participation is capped at 50 in the backend; the client must chunk larger sets instead of silently losing badges.
- Close and certify: a real scholar number appears in the gazette; house points are awarded once. A cancelled ballot never certifies.
- Ensure legacy election screens use the same backend and candidate identity mapping.
- Implement readable manager audit history: the function writes `election_polls_v2/{id}/audit`, while the current audit UI reads `election_audits`.
- Reject direct client tampering with all authoritative lifecycle documents, not only tallies.

**Done when:** these pass in staging and then on the intended live clients, including timeouts and permission failures.

## D3. App Check — client integration and rollout design missing

Only the election callable has an `ENFORCE_APP_CHECK` switch. `firebase_app_check` is absent from `pubspec.yaml`; raw HTTP calls do not send an App Check header. The library callable does not share the enforcement option.

Activate App Check **after** `Firebase.initializeApp()` and before using protected services. The previous instruction to activate it before Firebase initialization was incorrect. [Flutter App Check setup](https://firebase.google.com/docs/app-check/flutter/default-providers)

Enforcement is applied to an endpoint, not selectively waived for desktop. Enabling it on the existing shared election endpoint will also reject Windows callers without a valid token. Define and test a supported desktop/custom-provider strategy before switching it on; an unprotected duplicate endpoint would undermine the protection. Claims, ownership checks, verified roster identity, rate controls, and transactions remain necessary regardless of App Check.

**Done when:** supported clients supply attestation, missing/invalid tokens fail, desktop behavior is explicitly supported, and real error responses cannot trigger a privileged Firestore fallback.

## D4. Gamification and sports authority — not authored

No `schoolGamification` or sports certification callable is exported.

Required backend behavior:

- Authoritative challenge/quiz grading, eligibility, bounded awards, server time, durable cooldowns, and consumed nonces.
- Atomic house/contributor/user ledger updates with stable operation IDs and audit records.
- Server-controlled match scoring, certification, MVP/trophy awards, and replay-safe corrections.
- A restricted transition from current staff/council direct writes; per-write +500 limits do not stop repeated inflation.
- Migration/reconciliation for existing conflicting balances and legacy awards.

Spark-compatible defects to fix before or alongside this work: the gamification transaction reads after writing; cooldown/nonces are consumed before persistence; sports model payloads do not match rules; failed live score writes can return success; client secrets remain embedded. These are not billing restrictions.

**Done when:** legitimate awards persist exactly once across retries/devices, rejected writes do not consume rewards, signed client input cannot mint points, and all ledgers reconcile.

## D5. Academic merit claims — not authored

Build an atomic honours claim that reads the server report card, verifies the owner's trusted identity and document GPA, checks the claim marker, writes the award and marker together, and survives retry/reinstall.

The current method trusts a caller GPA and cannot complete its student-owned flag update under the rules. Repair identity ownership first: merely narrowing report-card reads does not stop a profile that impersonates the target scholar.

**Preserved project policy:** submitted or approved medical leave does **not** excuse attendance. Do not add leave-to-excused-attendance automation.

## D6. Notifications, promotions, and timetable coordination — not authored

- **Notification fan-out:** move authoritative event generation to a trusted backend with an outbox, deterministic recipient IDs, pagination, retry tracking, and deduplication. The client currently stops recipient lookup at 500 and writes batches of 400. An entire school fan-out is not one unlimited atomic transaction.
- **Remote push:** add FCM token registration/refresh, permission handling, backend delivery, routing, and platform setup. The present UI correctly labels notifications as in-app only. FCM availability and deploying a Firebase delivery function are separate questions.
- **Promotion:** coordinate users, roster membership, verification, audit, and notifications. Define chunked resumable semantics for large cohorts; do not promise unbounded all-or-nothing transactions.
- **Timetables:** use authoritative resource reservations or another transaction-safe conflict design. Client read/check/write sequences race under concurrent publishers.

**Done when:** retries and partial failures are observable, cohort changes converge, revoked privileges do not survive in `school_members`, and concurrent conflicting timetable publishes are rejected.

## D7. Corrected symptom matrix

| Symptom | Actual classification | Action |
|---|---|---|
| Election callable 404/timeout | Functions currently absent; other network failures are also possible | Deploy a verified backend; preserve real errors; live vote/receipt must fail closed |
| Admin election action appears to work while callable fails | Client fallback and broad admin rules still permit bypass | Remove fallback and harden lifecycle rules; this is a code defect |
| `permission-denied` creating a class, chat, trophy, or upload | Role/query/schema/path mismatch may be responsible | Inspect the exact rule and payload; billing is not a universal remedy |
| Missing build-time HMAC/vault define | Current code has compiled fallback keys | Migrate trust/credentials; injecting another shared key into the app is not a security fix |
| Gemini 2.0/1.5 requests fail | Stale model candidates in the client | Select a supported model and test the API independently of Firebase billing |
| Library renewal displays a result | Current portal is explicitly a sample | Wire the UI to `schoolLibrary`; a deploy alone does not connect it |
| PDF export on web | Export is unimplemented; now returns a truthful failure | Implement a real browser download; no Blaze requirement |

## D8. Native Wallet signing — not authored

The client can prepare pass-like JSON, but there is no exported `schoolWallet`, Apple archive/signature generation, or Google issuer integration. Keep private certificates/service-account keys on a trusted backend, with authenticated ownership checks, revocation, and key rotation.

The current PDF fallback is a plain text PDF with a textual verification payload. It does **not** embed a scannable QR image, school artwork, or a platform share/print flow. Android/iOS output goes to temporary storage; web export now fails honestly. Fixing these client limitations does not require Blaze.

**Done when:** real signed passes can be added to the intended wallets, updates/revocations work, and PDF/printing is separately tested on each supported platform.

## D9. Storage and certificate verification — Blaze plus substantial fixes

Storage supports more than circular PDFs: certificates, profile photos, and academic resources also use it. The old document's “circulars only” scope was incomplete.

Before enabling uploads/trigger processing:

1. Bind each object to its uploader UID and an authorized claim/document; prevent overwriting another student's certificate. Current claim paths are writable by every authenticated user and all Storage objects have a broad authenticated read grant.
2. Create an authoritative claim/upload intent before finalization and bind it to object generation. The current client uploads before creating the claim.
3. The trigger must never create a partial claim from a filename or overwrite `scholar_no`, house, or human review status. Current success and error branches do all of these through Admin SDK merge writes.
4. Record scan output with generation/event deduplication and retries. Preserve approved/rejected state on late or repeated delivery.
5. Describe logo/OCR matches as review hints, not verified signatures. The current OCR path assigns a fixed 85% confidence; handle PDFs with a supported document-processing path.
6. Verify staff role coverage and delete behavior in Storage rules; current `request.resource` upload predicates do not authorize deletion.
7. Enforce byte/document limits before upload and Base64 encoding. Circular fallback remains limited to 700 KB; certificate/photo fallbacks lack comparable byte guards.

After these changes and Storage initialization, deploy rules and test small/large uploads, unauthorized overwrites/reads, deletion, timeout cleanup, repeated trigger delivery, and delayed human reviews.

## D10. Orders, payments, vouchers, and ID issuance — missing trusted backend

Add a server-owned product/price catalogue, inventory controls, real payment verification when money is collected, authoritative point debits where points are spent, idempotent order creation, and atomic redemption. Bind QR/ID credentials to server records and cover all important fields with a server-only signing key or public-key verification scheme.

Current rules permit a student to create `verified`/`ready` orders with arbitrary items and zero price; redemption uses a separate read then update and can claim local-only success after live errors. Those defects must be corrected even while remaining on Spark. A trusted Firebase Functions implementation would require Blaze, but Firestore transactions and tighter rules themselves do not.

## D11. Identity, roster, and suspension lifecycle — prerequisite, not just billing

Current self-signup does not bind `users.scholar_no` to a verified school identity or enforce uniqueness. Emulator probes confirmed that an unrelated authenticated account can adopt another scholar number and read that scholar's report card. Membership grades/houses originate from the same self-entered profile.

Provide verified school provisioning/enrollment and atomic synchronization of role, house, grade, active status, and capabilities. Suspensions must revoke access in rules and backend authorization, not just update a UI field. Super admins must provision staff capabilities under the new rules. Review existing records for privileges granted under older permissive rules; new rules do not clean old data.

The existing `admin`/`11209` bootstrap exception is retained per the recorded project decision. Its unverified-email grant remains an accepted high-impact risk; document and monitor that exception explicitly. Do not describe client signup guards as server-side account reservation.

## D12. AI service and credential handling — optional backend design

The current candidates are `gemini-2.0-flash`, `gemini-1.5-flash`, and `gemini-1.5-pro`; the previous document's claim that a newer candidate was already installed was false. Google's lifecycle documentation lists Gemini 2.0 Flash as shut down on 1 June 2026. [Gemini deprecations](https://ai.google.dev/gemini-api/docs/deprecations)

Choose/test a supported model, move API keys out of plaintext preferences/URL query strings, disclose what academic data is sent, and distinguish cached local heuristics from live AI output. A Firebase-hosted proxy requires Blaze; model selection, local secure storage, and accurate UI labeling do not.

## Completion order and release evidence

1. Resolve identity, storage ownership, authoritative election paths, order/points integrity, and schema mismatches from the deep audit. Establish verified roster provisioning and cleanup.
2. Re-run Flutter and emulator checks; add missing Storage, trigger, callable transport, and platform integration tests.
3. When the project chooses billing, configure budgets/monitoring, initialize the intended bucket/APIs, and deploy the verified backend/rules in staging first.
4. Wire each client feature to its service. Configure App Check only after every intended client has an attestation strategy.
5. Run live acceptance on Windows/Android/iOS/web as supported; record deployed versions, rule releases, function regions, and results.
6. Mark individual D-items complete only with that evidence. Billing activation or a passing local unit suite does not close them.
