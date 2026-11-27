# ASB House Hub — deep code audit, 26 November 2026

The repository is **not ready for production release**. This audit repaired several independently reproducible faults, but identity, authorization, sensitive local storage, authoritative scoring/orders, and backend integration still need work. Passing builds and tests do not resolve those gaps.

Baseline: `9d0a559`, branch `mustafa1`. Scope: all tracked source/configuration files, with targeted behavioral review of services, rules, backend functions, models, platform configuration, and affected UI flows. The baseline contained 84 application Dart files (85,011 lines) and 20 Flutter test files. Generated code and platform files received scans and applicable build checks; this is not a claim that every line or every possible runtime path was manually verified.

## Evidence and limits

- [Per-file inventory](audit/2026-11-26/source_inventory.csv) records source hashes, line counts, review modes, and heuristic indicators. Indicator counts are investigation leads, not fault counts. Regenerate with `python tool/deep_audit_inventory.py`.
- [Verification summary](audit/2026-11-26/verification.json) records completed checks and limits. Detailed local logs are in ignored `build/audit/`.
- [Known-gap emulator results](audit/2026-11-26/known-gap-probes.json) demonstrate remaining vulnerabilities and rejected legitimate payloads using synthetic data. These are diagnostic probes, not passing security assertions.
- A read-only live Functions inventory returned success with an empty result: **no deployed Cloud Functions**. Billing linkage, deployed rules/indexes, bucket initialization, and production data were not independently verified. No deployment or billing change was made.
- Existing `admin` bootstrap credentials are an explicitly accepted project exception recorded in the previous audit. They were preserved; O01 records the remaining consequence.
- No Android/iOS release build, physical-device testing, accessibility certification, penetration test, Storage emulator suite, or deployed HTTP/Auth/App Check integration test was completed. Backend tests ran on host Node 24; the deployment runtime is now pinned to Node 22, whose runtime parity still needs verification.

## Verification results

| Check | Result |
|---|---|
| Flutter static analysis | No issues |
| Full Flutter suite | 685 passing tests (baseline 684) |
| Firestore rules and actual election handler emulator suite | 13 passing tests; seven of the initial eleven and both subsequently added academic tests failed before their fixes |
| Backend JavaScript syntax | All three modules pass |
| Windows release build | Pass |
| Web release build | Pass; CupertinoIcons font warning remains |
| npm dependency audit | Before: 17 affected packages, including 5 high and 1 critical. After compatible updates and a narrow test dependency override: 10 moderate, zero high/critical, including dev dependencies |
| Flutter dependency inspection | 71 outdated entries; no current advisory/retracted/discontinued flags observed. Outdated is not equivalent to vulnerable |

## Faults repaired in this change

| ID | Fault and correction | Evidence |
|---|---|---|
| F01 | Student membership creation accepted arbitrary capabilities, including library management. Self-provisioning now permits only the explicitly false election capability. | Emulator negative and positive membership tests |
| F02 | Ordinary teachers could grant privileged roster roles consumed by `isSuperAdmin`. Roster administration now requires super-admin authority. | Teacher escalation denied; legitimate super-admin provisioning allowed |
| F03 | Inactive membership could be self-reactivated. Self-updates now require an active existing membership and active user status when present. | Emulator denial |
| F04 | A recursive class rule overrode academic ownership restrictions and validators through Firestore's OR semantics. Removed that blanket grant. | Unrelated report-card/attendance reads and malformed assignment writes denied |
| F05 | An outsider could alter a chat message's read receipt. Non-admin updates now require room participation. | Outsider denied; legitimate recipient allowed |
| F06 | Cancelled polls could certify and award points. Certification now accepts only published/closed polls, retaining certified idempotency. | Actual handler test |
| F07 | Gazette winner scholar numbers were random candidate IDs. Resolve the scholar from the private draft or legacy roster before transaction writes. | Correct scholar and exactly-once award test |
| F08 | Candidate add/remove operations lacked audit entries. Added both, and capture/validate private scholar snapshots. | Handler mutation audit test |
| F09 | Six confirmed asynchronous UI paths could use disposed widgets: circular picker, account removal, chat image selection/read, audit QR decode, substitute selection, and account-switch password return. Added mounted guards. | Analysis and full suite, including picker success/error after disposal regression |
| F10 | Web pass export returned fabricated success without a download. It now returns a truthful unsupported error. Actual web export remains missing. | Analysis and release build |
| F11 | Functions used an ambiguous `>=18` runtime declaration and vulnerable compatible dependencies. Pinned Node 22; applied compatible patches and test-only Firestore gRPC override. | Syntax check, emulator suite, dependency audit |
| F12 | Prior documentation conflated billing requirements with unfinished features and asserted free Storage indefinitely. Replaced the Blaze checklist and corrected related pricing claims. | Current official sources linked in the checklist |

These changes are local repository changes until deployed. In particular, stronger local rules do not prove the live database now enforces them. Teacher self-provisioning may now fail where the old client expected to grant itself admin membership; trusted roster provisioning is an explicit prerequisite.

## Remaining findings

Severity reflects potential impact; reachability depends on enabled features, deployed configuration, and data. **Critical/High** items should block relevant production use. Each row names source entry points and concrete remediation, rather than treating all missing features as a billing problem.

| ID / severity | Finding, source, and required follow-up |
|---|---|
| O01 Critical — accepted exception | `firestore.rules:isSuperAdmin`, authentication bootstrap: an unverified token carrying the reserved admin email can gain administrative access without a profile. Demonstrated locally. Preserve the recorded exception for now; a future approved replacement should use verified, server-provisioned authority and revoke the bootstrap path. |
| O02 Critical | `firestore.rules` user creation/`isScholar`: a new account can choose another student's scholar number, then read their academic record. Both steps reproduced. Bind identities to a trusted enrollment roster; user-editable scholar numbers cannot establish ownership. |
| O03 High | `lib/services/auth_service.dart` account vault: a shared compiled encryption key and persisted account passwords undermine local confidentiality; legacy plaintext migration remains relevant. Use platform-backed secret storage and avoid retaining reusable passwords. Build-time defines still become client binaries. |
| O04 High | User suspension is not enforced consistently in rules or synchronized with `school_members`. A suspended teacher can still read medical records in the emulator. Centralize active-status enforcement and invalidate stale capabilities/sessions. |
| O05 High | `auth_service.dart:switchAccount`: saved account data can overwrite a fresh authenticated profile, restoring stale roles. An outer timeout is shorter than the inner sign-in timeout and does not cancel it; late authentication changes can occur. Same-UID shortcuts also require freshness review. |
| O06 High | `auth_service.dart` cache lifecycle: logout/account switches do not consistently clear all scoped sensitive cached records. Review every preferences key and test cross-account isolation, restart, and failed switches. |
| O07 High | Notification rules allow any signed-in user to create official-looking notices for another user; demonstrated locally. Require authorized producers and trusted sender metadata; apply equivalent checks to refresh/control messages. |
| O08 High | Claim creation permits caller-supplied AI verification metadata, `auto_validated`, and a different house. Demonstrated locally. Make verification fields server-owned and bind student/house/points to trusted data. |
| O09 High | `storage.rules`, `functions/index.js`: broad authenticated file access, overwritable claim filenames, filename-derived identity, merge writes, and upload-before-claim ordering create ownership, replay, partial-document, and status-reset risks. Bind immutable object generation to an existing authorized claim and make processing idempotent. Vision OCR/logo hints do not authenticate signatures; fixed 85% confidence is misleading. |
| O10 High | Election service catches backend failures and can enter privileged direct-write fallbacks. Rules still permit manager/admin mutation of lifecycle documents outside the backend. Remove live fallbacks and enforce one authoritative lifecycle. |
| O11 High | No functions are deployed. Legacy `auth_service.dart:castDigitalVote` remains a separate direct-write path that is denied by hardened count/participation rules. Route all election screens through the same callable and identity mapping. |
| O12 Medium | Election audit UI reads `election_audits`, while the backend writes `election_polls_v2/{id}/audit` without a matching manager read rule. Participation batches cap at 50 while the client can submit all polls at once. Align paths/rules and chunk requests. |
| O13 Medium | Library UI retains sample/legacy loan paths while `functions/library-v2.js` uses a separate v2 schema. Missing v2 read rules, catalog provisioning, and connected UI prevent an end-to-end lending system. |
| O14 High | Gamification transaction flow writes a house before later contributor/user reads; Firestore requires transaction reads first. Nonces/cooldowns may be consumed before successful persistence, and student live awards are denied. Reorder reads and make authoritative award/retry state atomic. |
| O15 High | Repeated point increments lack a trusted event identifier and effective server rate enforcement. House/contributor/user ledgers can diverge, including writes after transaction failure. Use a server-owned immutable award ledger with idempotency. |
| O16 High | Honours rely on client-derived academic eligibility and separate merit-marker writes; protected student updates can fail. Compute eligibility from trusted records and award/mark atomically. Preserve the project's policy that medical leave does not excuse attendance for honours. |
| O17 High | Conduct revocation deletes the record before subsequent user merit updates, which may be disallowed, and does not consistently reverse house/contributor totals. Reverse all related effects atomically with an auditable reversal entry. |
| O18 Medium | A first demerit can produce a negative contributor total rejected by the nonnegative schema; council permissions also differ across negative-score paths. Define one supported scoring contract and test zero-to-negative transitions. |
| O19 High | Sports fixture/trophy serialization disagrees with rule validators. The trophy model sends `tournament_title` where rules require `title`; its current payload fails even for an admin. Align models, validators, and migrations before enabling awards. |
| O20 High | Sports score updates use stale absolute values and can lose concurrent changes. Broad catches can return local success after live failure. Use atomic event-based updates and explicit error states. |
| O21 High | Orders can be created already verified with arbitrary items and zero price; demonstrated locally. Client persistence precedes remote confirmation and can conceal failure. Resolve catalog prices and authorization on a trusted server. |
| O22 High | Voucher redemption reads then updates separately, allowing concurrent fulfillment. Status validation and local fallback after live errors weaken guarantees. Use an atomic server transition from an explicitly redeemable state. |
| O23 High | Election, gamification, sports, and voucher signing secrets are embedded in client code. Voucher signatures do not cover all item contents. Client-held secrets cannot authenticate authoritative awards/purchases; implement server issuance, complete payload binding, expiry, and revocation. |
| O24 Medium | Pass PDF export contains text payloads rather than a scannable QR and lacks robust pagination, Unicode fonts, sharing, and web delivery; mobile output is temporary. JSON wallet exports are not signed Apple/Google Wallet passes. Implement each advertised deliverable explicitly. |
| O25 Medium | AI model fallbacks use deprecated Gemini 2.0/1.5 IDs. Gemini 2.0 Flash shut down on 1 June 2026 according to the official schedule linked in the Blaze document. Validate a currently supported model and response contract. |
| O26 Medium | AI credentials are persisted locally and placed in request URLs; fallback context includes synthetic scholar/grade values. Review key handling, logs, provenance, and which student data is transmitted externally. |
| O27 Medium | New chat creation begins with a read of a missing room whose participant-based read rule denies it. Reproduced. Use a creation flow compatible with the authorization model. |
| O28 Medium | Client photo messages send `attachment_url`, absent from the rule whitelist; reproduced rejection. The UI can clear the draft and swallow the failure. Align schemas and preserve drafts until confirmed persistence. |
| O29 Medium | Chat peer restrictions mainly reside in the client; room creation verifies caller participation without a complete permitted-peer policy. Missing-profile role fallbacks can also mislabel authority. Enforce peer authorization server-side. |
| O30 Medium | Timetable conflict detection is a read/check/write sequence vulnerable to concurrent edits; audit writes are separate and can be ignored. Introduce a transactional reservation/version contract. |
| O31 Medium | Student promotion is sequential and partially applied on failure, without a resumable job or consistent membership synchronization. Use bounded batches with durable progress and reconciliation. |
| O32 Medium | Roster reads cap at 500 and unread streams at 100, while other lists/listeners are unbounded. Add pagination and distinguish bounded UI pages from complete counts/eligibility calculations. |
| O33 Medium | Accounts without a profile/grade can register for senior-only events; reproduced. Eligibility also relies on caller identity fields. Require verified roster eligibility and server-derived attendee identity. |
| O34 Medium | Inline base64 attachments lack consistent aggregate document-byte limits. Multiple timetable images can exceed Firestore's 1 MiB document limit even when individual sizes pass. Apply aggregate caps or move authorized binaries to Storage. Circulars already have an explicit cap. |
| O35 Medium | Some model decoders substitute current/future times for malformed data or use numeric casts that can throw. Stream mapping can fail an entire election snapshot on one malformed record. Validate inputs, isolate corrupt records, and avoid invented dates. |
| O36 High | Firebase initialization failure can continue into implicit demo/local behavior, including synthetic accounts and success states. Require an explicit demo mode and fail closed for live authentication/persistence. |
| O37 High | App Check lacks client integration; only elections expose a backend enforcement flag. Raw HTTP requests need token handling. Enforcement has no automatic Windows exemption. Design supported-platform providers and staged enforcement before activation. |
| O38 High | Android release configuration uses debug signing. iOS deployment targets remain 13 while installed FlutterFire podspecs require 15. Neither mobile release was built here. Configure release signing/targets and validate on appropriate hosts/devices. |
| O39 Medium | No complete CI gate; many existing security tests inspect source strings instead of enforcing rules. Ten moderate dependency advisories remain. Add emulator and transport integration coverage, runtime parity, Storage tests, and reviewed major dependency upgrades. |
| O40 Medium | `lib/screens/merch_store_tab.dart` indexes `userHouse[0]` without guarding empty input, causing a RangeError for that public component state. Validate/default the house before indexing. |
| O41 Low | English/Arabic strings and RTL behavior are incomplete; accessibility and device layouts remain unverified. Audit localization coverage, semantics, contrast, keyboard navigation, and large text. |
| O42 Medium | No committed Firestore index manifest reproduces the required query configuration in a clean environment. Inventory queries, capture required indexes, and verify staging setup; existing live indexes were not inspected. |
| O43 Medium | FCM client registration/token lifecycle and backend delivery are missing. Existing in-app notifications should not be represented as device push delivery. |
| O44 Medium | Role definitions differ among hierarchy code, Firestore, Storage, and membership provisioning. Storage omits some staff aliases; rejected bootstrap/profile provisioning can be swallowed. Establish one role/capability contract with positive and negative tests for each role. |

## Delivery order

1. Resolve verified identity, suspension, trusted role provisioning, notification/claim authorization, and local credential/cache handling. Keep the recorded bootstrap exception visible until deliberately replaced.
2. Align client/rule schemas for chat, sports, academic and conduct flows. Repair transaction ordering, concurrent updates, idempotency, and failure reporting.
3. Implement authoritative election, library, scoring, order, redemption, and honours flows; remove live local-success fallbacks. Add adversarial emulator and integration tests.
4. Follow [Blaze requirements and backend readiness](election_audit/BLAZE_REQUIRED_FEATURES.md): billing is only one prerequisite. Repair Storage/Vision before deployment; stage App Check; validate production configuration and monitoring.
5. Complete mobile signing/builds, localization/accessibility, real export/share flows, pagination, indexes, CI, and dependency/runtime verification.

## Reproduction

Run from the repository root. The demo emulator uses synthetic data and is isolated from production.

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --release --no-pub
flutter build web --release --no-pub
npm --prefix functions ci
npm --prefix functions run check
firebase emulators:exec --project demo-asb-audit --config firebase.audit.json --only firestore "node --test functions/test/security.test.js"
firebase emulators:exec --project demo-asb-audit --config firebase.audit.json --only firestore "node tool/probe_known_gaps.cjs"
npm --prefix functions audit --omit=dev
python tool/deep_audit_inventory.py
```

The diagnostic probe command records unsafe ALLOWED outcomes and legitimate DENIED outcomes; its successful exit does not mean security passed. `npm audit` still exits nonzero for the documented moderate advisories. Historical audit reports remain historical evidence, not certification of the current application.
