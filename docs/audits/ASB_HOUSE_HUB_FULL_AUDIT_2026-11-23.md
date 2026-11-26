# ASB House Hub — Full Application and Firebase Plan Audit

> Historical report. Current findings, fixes, and verification are in the [26 November deep audit](ASB_HOUSE_HUB_DEEP_AUDIT_2026-11-26.md). Preserve the accepted project exceptions documented here; older completion claims are not current release certification.

**Application:** ASB House Hub (`asb_house_hub`, version `1.0.1+2`)  
**Repository:** `C:\Users\User\OneDrive\Desktop\asb_house_hub_flutter`  
**Firebase project:** `asb-house-hub`  
**Audit window:** 23–25 November 2026  
**Audit HEAD:** `5707933`  
**Report type:** Read-only feature, architecture, security, and Firebase-plan audit  
**Revision:** 2 — adds the verification of the external 21-finding fault report (Appendix G) and the associated findings in §7.16.  
**Code changes made:** None. The pre-existing uncommitted change in `lib/services/auth_service.dart` was preserved. This report is the only new file.

---

## 1. Executive summary

ASB House Hub is a large, unusually broad Flutter school-life application. It combines house points and competitions, academics, attendance, claims and certificates, campus events, chat and groups, elections, sports, a merchandise store, digital passes, QR scanning, behaviour records, an AI assistant, and a substantial admin console. It is not a small demo: the `lib` tree contains **84 Dart files and 84,843 lines**, including **28 screens**, **14 services**, **21 models**, and **15 widgets**. The test suite contains **20 files and 21,793 lines**.

The codebase is in better mechanical health than its size suggests:

- `flutter analyze --no-pub` completed with **No issues found**.
- `flutter test --reporter compact` completed with **684/684 tests passing**.
- The working tree is clean apart from the uncommitted `auth_service.dart` change.
- Firestore rules are extensive (1,861 lines) and include validators, immutable-field checks, role checks, and bounded updates for several domains.

The central finding is that the application is **not production-ready for real student data, live elections, payments, or private messaging**, despite presenting many of those capabilities in the UI. The biggest risks are not visual or test failures; they are **trust-boundary failures**:

1. **Any signed-in student can make themselves a super-admin through `school_members`.** The rules let an owner write their own membership document, and `isSuperAdmin()` trusts that document's `role`. This is a complete Firestore privilege-escalation path.
2. **Election tally documents are writable by any signed-in user.** `election_polls_v2/{pollId}/counts/{candidateId}` has `allow write: if isSignedIn()`, and participation documents can be created by any signed-in user. Election integrity is impossible with these rules, even after the election callable is deployed.
3. **The live election fallback cannot work under the committed rules.** The student fallback transaction includes a poll update and an `election_votes` write, both of which are denied. The callable endpoint returns HTTP 404 because the functions are not deployed. In practice, live student voting is blocked, while the UI suggests it is available.
4. **Private chat is not private.** Any signed-in user can read any `chats/{channelId}` and its `messages` because the rules do not check channel participants. The UI labels messages as “Encrypted,” but they are plaintext in Firestore.
5. **The user directory is publicly readable, including unauthenticated reads.** `users/{userId}` has `allow read: if true`, and signup trusts a self-entered scholar number, name, house, and class. There is no roster pre-provisioning or invite proof.
6. **Client-side “security” is not a security boundary.** Election, gamification, sports, voucher, and credential-vault secrets have compiled fallback values in the client. HMAC tokens minted on the client can be forged by anyone who extracts the app binary.
7. **Several prominent features are simulations or local-only:** Apple/Google Wallet buttons, NFC, fee payment status, the library portal, parts of the house arena, and the store payment flow. The UI often does not distinguish these from real institutional integrations.
8. **Blaze is required for the authored server features, Storage, and Vision, but Blaze alone will not fix the rules.** The project still needs a rules hotfix and server-side roster authority.
9. **A 25 November verification pass against the external 21-finding report confirmed most of that report and found several additional release blockers.** The most important are a bootstrap super-admin path hardcoded on both the client and in rules, an unauthenticated Firestore REST fallback that can enumerate scholars, an account switch that swaps local data before authentication succeeds, an attendance formula that disagrees across screens and reports 100% when there is no data, report-card IDs that collide across academic years, and non-atomic conduct points/logging. See §7.16 and Appendix G.

**Verdict:** suitable for supervised demos, internal pilots with synthetic data, and UI/feature evaluation. Not suitable for a real school rollout until the P0 items in §10 are closed.

### At a glance

| Metric | Value |
|---|---:|
| Dart files in `lib/` | 84 |
| Lines in `lib/` | 84,843 |
| Screens | 28 |
| Services | 14 |
| Models | 21 |
| Widgets | 15 |
| Test files / lines | 20 / 21,793 |
| Firestore rules | 1,861 lines / ~97 KB |
| Authored Cloud Functions | 3 |
| Deployed Cloud Functions (probed) | 0 |
| Initialized Storage bucket (probed) | No |
| `flutter analyze` | Clean |
| `flutter test` | 684/684 pass |
| Current Firebase plan | Spark, per project documentation; Blaze deferred 2026-11-06 |

### Top findings by severity

| # | Severity | Finding |
|---|---|---|
| 1 | Critical | `school_members` self-write → `isSuperAdmin()` escalation → broad Firestore takeover |
| 2 | Critical | Election `counts` writable by any signed-in user; `participation` creatable by any signed-in user |
| 3 | Critical | Live election fallback is incompatible with rules; student live voting fails; callable is 404 |
| 4 | High | Chat channels and messages readable by any signed-in user; “Encrypted” label is false |
| 5 | High | Public `users` read and self-asserted identity/house/class at signup |
| 6 | High | Self-service house/grade changes affect groups, events, and election eligibility |
| 7 | High | Client-side HMAC secrets with compiled fallbacks; custom credential vault |
| 8 | High | Shared bootstrap admin account plus uncommitted automatic admin re-authentication |
| 9 | Medium | Storage rules allow any signed-in user to write claims/exam/circular paths |
| 10 | Medium | Any signed-in user can create notifications for any other user |
| 11 | Medium | Voucher signatures are optional; legacy unsigned vouchers are accepted |
| 12 | Medium | No payment gateway; store orders, fee receipt, Apple/Google Wallet, and NFC are simulated |
| 13 | Medium | Library is a three-book local cache; `schoolLibrary` backend is never called |
| 14 | Low | Dead localization scaffolding; all UI strings are hard-coded English |
| 15 | Low | Global `ErrorWidget` displays exception text to the user |

#### Additional findings confirmed during the 21-finding verification (details in §7.16)

| # | Severity | Finding |
|---|---|---|
| V1 | Critical | Bootstrap super-admin is hardcoded on both sides: client `11209`/`admin` checks plus rules trust of `admin@asianschool.bh` and `11209@asianschool.bh`; Auth account creation precedes the `users` validator |
| V2 | Critical | `checkScholarExists()` has an unauthenticated Firestore REST `runQuery` fallback into a publicly readable `users` collection |
| V3 | Critical on shared devices / High otherwise | `switchAccount()` swaps scholar, UID, profile, and house caches even when live re-authentication fails, is skipped, or times out |
| V4 | Critical (product/legal) / High otherwise | Fixed `BHD 150.000` “PAID IN FULL” fee receipt and QR are shown to every student, with no payment record |
| V5 | High | Attendance is calculated three different ways; empty attendance is reported as 100% on the home screen and in `AttendanceSummary` |
| V6 | High | Report-card document ID omits the academic year, so the same term in a later year overwrites the prior card |
| V7 | High | Conduct points are committed before the `student_conduct` audit record; a failure leaves points with no reason log |
| V8 | High | Class level silently defaults to `Grade 10` in 19 places in `auth_service.dart`; missing house defaults to Ruby in multiple paths |
| V9 | Medium | Every store order is created with `totalPts: 0`, and order history labels zero-point orders “PAID (BHD)” |
| V10 | Medium | Six relative-dated sample events exist; the first is always `isLive: true`; seeding is explicit in live mode but one tap in offline mode |
| V11 | Low | Spirit reactor delta is flushed every fifth tap with a fire-and-forget write; `dispose()` does not flush |

---

## 2. Scope, evidence, and limitations

### 2.1 What was audited

- Every Dart file under `lib/` was enumerated; key screens, services, models, and widgets were read directly.
- `lib/main.dart` was audited line by line as the app entry point.
- `pubspec.yaml`, `firebase.json`, `.firebaserc`, and `lib/firebase_options.dart` were inspected.
- All three Cloud Functions source files were read: `functions/index.js`, `functions/elections-v2.js`, `functions/library-v2.js`.
- `firestore.rules` (1,861 lines) and `storage.rules` were reviewed, with focused reads of authentication, users, school membership, elections, claims, orders, chat, groups, events, points, sports, notifications, and storage paths.
- Existing reports were reconciled against code: `PRODUCT_OVERVIEW.md`, `APP_STRUCTURE_AND_REALITY_REVIEW.md`, `development_plan/ACCEPTANCE_MATRIX.md`, `development_plan/REMAINING_MODULES_REPORT.md`, `MASTER_GAP_ANALYSIS.md`, `election_audit/BLAZE_REQUIRED_FEATURES.md`, `INFRASTRUCTURE_AND_PRICING_GUIDE.md`, and the module audit folders.
- Live HTTP probes for the two callable endpoints and the Storage bucket returned **HTTP 404**, indicating that neither the functions nor the Storage bucket are live.
- Verification commands were run against the current working tree.

### 2.2 Limitations

- Firebase Console state (billing plan, deployed rules revision, API enablement) cannot be queried from this environment without project credentials. Plan state is taken from the project's own explicit deferral record and is consistent with the 404 probes.
- No Firebase Emulator/rules-unit test run was performed. Security findings are based on the committed rules and the documented deployment state. If the deployed rules differ from the repository, the findings must be re-checked in the Console.
- No mobile-device, accessibility, load, penetration, or payment-provider testing was performed.
- “Live” in this report means “the client path can work against Firebase on the current plan if the committed rules are deployed.” It does not mean the feature has passed a production acceptance test.
- No secret values are reproduced. Where a secret or fallback secret exists, the report describes its location and impact only.

### 2.3 Verification baseline

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze --no-pub` | No issues found (post-remediation) |
| Unit/widget tests | `flutter test --reporter compact` | 684/684 passed (post-remediation) |
| Git HEAD | `git rev-parse --short HEAD` | `5707933` |
| Working tree | `git status --short` | 17 modified files plus the untracked audit report (remediation batch; see §12) |
| Election endpoint | `POST https://us-central1-asb-house-hub.cloudfunctions.net/schoolElection` | HTTP 404 |
| Library endpoint | `POST https://us-central1-asb-house-hub.cloudfunctions.net/schoolLibrary` | HTTP 404 |
| Storage bucket | `GET https://firebasestorage.googleapis.com/v0/b/asb-house-hub.firebasestorage.app/o` | HTTP 404 |

The original `auth_service.dart` modification was user work in progress: it adds automatic admin re-authentication inside `publishSchoolNotice` when the current Firebase session is unauthenticated, using a saved admin account on the device. That work was preserved. The broader 25 November remediation batch is also uncommitted; §12 records its scope, verification, and residuals.

---

## 3. Architecture and entry-point audit

### 3.1 Technology stack

| Layer | Technology / implementation |
|---|---|
| UI | Flutter (Material 3), custom `AppTheme` light/dark themes |
| State | `StatefulWidget` + `setState`, `StreamBuilder`, `ValueListenableBuilder`, global static stores, `SharedPreferences` caches |
| Navigation | Imperative `Navigator.push` / `MaterialPageRoute`; no named routes, router package, or deep links |
| Auth | Firebase Authentication, email/password; scholar number converted to an email address; fixed admin email |
| Database | Cloud Firestore; Windows uses an in-memory 100 MB cache with persistence disabled |
| Files | Firebase Storage (authored, not initialized); Base64 data-URI fallbacks; pure-Dart PDF generation |
| Server | Three authored Cloud Functions v2 (callable ×2, Storage trigger ×1); no client `cloud_functions` SDK |
| AI | Direct Gemini REST API call with a user-supplied API key; local heuristic fallback |
| Payments | None; no gateway or payment SDK |
| Push | None; no `firebase_messaging`; in-app Firestore notification documents only |
| Tests | `flutter_test`; 20 files, 21,793 lines |

### 3.2 `lib/main.dart` — what happens on launch

`lib/main.dart` is 223 lines and has four responsibilities.

1. **Global error rendering.** `ErrorWidget.builder` is replaced so a release build shows a warning card with the exception text instead of a grey box. This is useful for demos but exposes internal exception text to users and screenshots.
2. **Local preferences and theme hydration.** `AuthService.initPreferences()` and `AppThemeController.init()` run inside a `try/catch`; failures are logged and startup continues. This makes the app resilient but can hide a corrupted local cache.
3. **Firebase initialization.** `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` is wrapped in a `try/catch`; if it fails, the app still calls `runApp`. Services then see `AuthService.isFirebaseLive == false` and use local/demo fallbacks. There is no app-level blocking error or explicit “running offline/demo” banner at the root.
4. **Windows Firestore workaround.** On non-web Windows, Firestore is configured with `persistenceEnabled: false` and a 100 MB in-memory cache to avoid LevelDB lock assertions after rapid restarts. This is a sensible platform-specific mitigation, but it means Windows offline behaviour differs from mobile.
5. **App shell and auth gate.** `MaterialApp` supplies light/dark themes, localization delegates, and `home: AuthGate()`. `AuthGate` streams `AuthService().authStateChanges` and routes to onboarding, login, or `HomeScreen`.

### 3.3 `AuthGate` routing logic

| State | Result |
|---|---|
| Stream waiting, no user, no cached profile/house | Onboarding if onboarding not completed, otherwise Login |
| Stream waiting, current user exists | `HomeScreen` immediately, keyed by UID |
| Stream waiting, cached profile/house exists but no current user | Themed house-shield loading screen |
| Stream error | Login if onboarding completed, otherwise Onboarding |
| Authenticated user | `HomeScreen` keyed by UID |
| Signed out, onboarding incomplete | Onboarding |
| Signed out, onboarding complete | Login |

### 3.4 Entry-point findings

| ID | Finding | Impact | Severity |
|---|---|---|---|
| M1 | Firebase initialization failure is swallowed and the app continues | The app can present local/demo actions as if they were live; no root-level offline/demo state | High |
| M2 | `AuthGate` routes a current user to `HomeScreen` while profile/cache may still be hydrating | Brief empty/placeholder states; screens may assume a house/class that is not loaded | Medium |
| M3 | Auth stream error silently becomes Login/Onboarding | Users cannot distinguish “signed out” from “auth backend failed” | Medium |
| M4 | Localization delegates are configured but no screen calls `AppLocalizations.of(context)` | The l10n scaffold is dead; all visible strings are hard-coded English | Low |
| M5 | `ErrorWidget` prints exception details into the UI | Leaks implementation details and possibly sensitive error text | Low |
| M6 | No named route table, route guards, or deep links | Auth/profile assumptions are re-checked ad hoc in screens; external links cannot target features | Low |
| M7 | No `FlutterError.onError` / `PlatformDispatcher.onError` / crash reporting | Unhandled async/platform errors are not captured for operations | Medium |
| M8 | No App Check initialization | The election callable's App Check flag cannot be safely enabled for mobile/web | Medium |

### 3.5 App-wide architecture observations

**Strengths**

- Clear top-level separation between `screens`, `services`, `models`, and `widgets`.
- A large, consistent domain model set (academics, elections, sports, groups, notifications).
- Offline-tolerant caches and explicit local fallbacks in many services.
- Firestore rules are unusually extensive for a Flutter project and include schema validators and bounded updates.
- Accessibility semantics exist in several key widgets and loading states.
- The test suite is broad and fast.

**Structural risks**

| Area | Observation |
|---|---|
| God services | `lib/services/auth_service.dart` is 9,843 lines and mixes auth, profile, claims, notices, academics, points, elections, sports, storage, caching, and admin operations. |
| God screens | `academics_screen.dart` is 7,924 lines; `home_screen.dart` is 6,801 lines; `school_elections_page.dart` is 3,148 lines; `merch_store_tab.dart` is 3,302 lines. |
| State management | No Provider/Riverpod/Bloc; global static stores (`GlobalWalletStore`) and `setState` make cross-screen consistency difficult to reason about. |
| Networking | No generated client; raw `http.post` calls to callable functions duplicate auth/serialization logic. |
| Security placement | Authorization is split between client-side `HierarchyService` checks, Firestore rules, and functions; the three do not agree. |
| Localization | Generated l10n exists but is unused. |
| Testing | Strong unit/widget coverage, but no Firestore rules tests, no emulator integration suite, no live backend smoke test. |
| Documentation | Several documents describe intended end states as current behavior; see §9. |

### 3.6 Largest source files

| Lines | File |
|---:|---|
| 9,843 | `lib/services/auth_service.dart` |
| 7,924 | `lib/screens/academics_screen.dart` |
| 6,801 | `lib/screens/home_screen.dart` |
| 3,897 | `lib/widgets/mascot_3d_stage.dart` |
| 3,302 | `lib/screens/merch_store_tab.dart` |
| 3,148 | `lib/screens/school_elections_page.dart` |
| 2,637 | `lib/screens/admin_claims_screen.dart` |
| 2,437 | `lib/screens/events_screen.dart` |
| 2,114 | `lib/screens/admin_academics_screen.dart` |
| 1,975 | `lib/screens/election_chamber_screen.dart` |

---

## 4. Firebase backend and deployment reality

### 4.1 Configuration

| Item | Value |
|---|---|
| Project ID | `asb-house-hub` |
| Storage bucket in client options | `asb-house-hub.firebasestorage.app` |
| `firebase.json` services | Firestore rules, Storage rules, Functions (`functions/`, codebase `default`) |
| Functions runtime | Node.js >= 18; `firebase-admin` ^12, `firebase-functions` ^5, `@google-cloud/vision` ^4 |
| Client Firebase SDKs | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage` |
| Client SDKs not present | `cloud_functions`, `firebase_messaging`, `firebase_app_check`, `firebase_analytics`, `firebase_crashlytics` |
| Hosting / emulators | Not configured |
| Generated options | Android, iOS, Windows, web (`firebase_options.dart`) |

The Firebase API key embedded in `firebase_options.dart` is a public client identifier by design, but it should still be restricted by package/bundle ID and API in Google Cloud Console. No key value is reproduced here.

### 4.2 Authored Cloud Functions

| Function | Type | Source | Purpose | Live? |
|---|---|---|---|---|
| `schoolElection` | Callable (v2, default `us-central1`) | `functions/elections-v2.js` | Server-authoritative election draft/publish/vote/receipt/certify/close/cancel/audit/gazette; 100 points to winner house | No — endpoint 404 |
| `schoolLibrary` | Callable (v2) | `functions/library-v2.js` | Transactional checkout/return/renew using `library_loans_v2` and `library_copies_v2` | No — endpoint 404; no client caller |
| `verifyCertificateSignature` | Storage trigger (v2, `onObjectFinalized`) | `functions/index.js` | Cloud Vision logo detection + OCR fallback for `house_claims/` uploads; writes `ai_status`, `ai_confidence`, `ai_markers`, `ai_summary` | No — Storage bucket 404 |

`schoolElection` is the only function that is actively called by the client. `schoolLibrary` has no call sites. `verifyCertificateSignature` is also the only consumer of Storage; without it, claims remain human-reviewed only.

### 4.3 Deployment reality

| Capability | Authored? | Deployed? | Evidence / consequence |
|---|---|---|---|
| Firestore rules | Yes, 1,861 lines | Documented as deployed | Security findings assume this ruleset; verify in Console |
| Storage rules | Yes | No | Storage bucket is not initialized; `firebase deploy --only storage` fails |
| `schoolElection` | Yes | No | HTTP 404; 4-second timeout in the client; fallback path |
| `schoolLibrary` | Yes | No | HTTP 404; not called by UI anyway |
| `verifyCertificateSignature` | Yes | No | No Storage trigger; AI fields never populated |
| App Check enforcement | Partial server flag | No | `ENFORCE_APP_CHECK` defaults off; no client App Check SDK |
| Push messaging | No | No | `firebase_messaging` absent; only in-app Firestore notifications |
| Payment webhook | No | No | No payment provider integration |

### 4.4 Windows-specific Storage path

Because the native Storage plugin caused problems on Windows, the app calls the Firebase Storage REST endpoint directly for certificate and circular uploads. If the bucket is uninitialized or the request is unauthorized, the service falls back to a Base64 data URI:

- Claim images: `data:image/jpeg;base64,...` stored in Firestore.
- Circular PDFs: `data:application/pdf;base64,...` up to the inline cap (reported by the code as 700 KB).
- Large circular PDFs: explicit failure because the Firestore document limit would be exceeded.

This is a truthful degradation for small files, but it has three consequences:

1. No Storage object is created, so the Vision trigger never runs.
2. Base64 inflates payloads by roughly 33%; a 1 MiB Firestore document limit is reached far below the 10 MB Storage rule.
3. Large official circulars cannot be published without Blaze/Storage.

---

## 5. Feature inventory

**Status legend**

- **LIVE** — works against Firebase on the current plan if the committed Firestore rules are deployed.
- **PARTIAL** — works with an important limitation, fallback, or manual step.
- **LOCAL/DEMO** — hard-coded, cached, or simulated; not authoritative.
- **BLOCKED** — requires a Blaze-only service or a server component that is not deployed.
- **ABSENT** — not implemented.

| # | Module | Primary code | Status |
|---|---|---|---|
| 1 | Identity, onboarding, account switching | `onboarding_screen.dart`, `login_screen.dart`, `signup_screen.dart`, `auth_service.dart` | LIVE with identity caveats |
| 2 | Home shell, dashboard, navigation | `home_screen.dart`, `main.dart` | LIVE |
| 3 | Houses, standings, gamification | `house_leaderboard_screen.dart`, `house_arena_screen.dart`, `home_screen.dart` | LIVE + demo elements |
| 4 | Academics, timetable, attendance, circulars | `academics_screen.dart`, `teacher_timetable_editor_screen.dart`, `admin_academics_screen.dart`, `timetable_service.dart` | LIVE/PARTIAL |
| 5 | Claims and approvals | `admin_claims_screen.dart`, `approved_claims_screen.dart`, `auth_service.dart` | PARTIAL |
| 6 | Campus events | `events_screen.dart`, `campus_event.dart` | LIVE |
| 7 | Notifications | `notification_service.dart`, `notification_center_screen.dart` | LIVE in-app; push ABSENT |
| 8 | Chat and groups | `chat_service.dart`, `chat_list_screen.dart`, `chat_room_screen.dart`, `class_group_service.dart`, `house_group_service.dart` | LIVE with privacy defect |
| 9 | Sports and trophies | `sports_tournament_screen.dart`, `live_match_hud_screen.dart`, `sports_security_service.dart` | LIVE, client-trusted |
| 10 | Elections | `school_elections_page.dart`, `election_chamber_screen.dart`, `election_audit_screen.dart`, `election_gazette_screen.dart`, `elections-v2.js` | BLOCKED |
| 11 | Store, orders, vouchers | `merch_store_tab.dart`, `voucher_security_service.dart` | PARTIAL; payment ABSENT |
| 12 | Digital wallet and documents | `digital_wallet_screen.dart`, `pass_document_exporter.dart` | LOCAL/DEMO for wallet; PDF PARTIAL |
| 13 | ID scanning and behaviour | `id_scanner_screen.dart`, `student_behavior_evaluation_screen.dart`, `qr_decoder_service.dart` | LIVE, client-trusted |
| 14 | Library | `home_screen.dart` library modal; `library-v2.js` | LOCAL/DEMO; backend BLOCKED |
| 15 | AI assistant | `house_ai_chat_screen.dart`, `gemini_ai_service.dart` | PARTIAL / optional |
| 16 | Administration and governance | `admin_academics_screen.dart`, `admin_claims_screen.dart`, `hierarchy_service.dart`, `auth_service.dart` | LIVE with governance caveats |

### 5.1 Identity, onboarding, and account switching

**Implemented**

- First-run onboarding carousel with school/house branding.
- Login by scholar number plus password; scholar number is converted to an email address for Firebase Auth.
- Fixed administrator login path (`signInAdmin`) that uses a single bootstrap admin email and a password-only form.
- Student signup with full name, age, class level, division, house selection, password, and confirmation. The profile is written with `role: 'student'` and `class_verified: false`.
- Password reset by scholar number.
- Saved accounts on device, account switching, “remembered” profile/house caches.
- Theme mode persistence and light/dark switching.
- Automatic `school_members/{uid}` provisioning after signup and account switching.

**Data:** Firebase Auth; `users/{uid}`; `school_members/{uid}`; local `SharedPreferences` caches for profile, house, scholar number, saved accounts, and theme.

**Status:** LIVE, but the identity model is trust-based. There is no roster invite, no school-issued code, and no server verification that the scholar number belongs to the person registering. `class_verified` is only a flag; it does not authenticate the class placement. See §7.4.

**Key files:** `lib/screens/onboarding_screen.dart`, `lib/screens/login_screen.dart`, `lib/screens/signup_screen.dart`, `lib/services/auth_service.dart` (`signIn`, `signInAdmin`, `signUp`, `ensureSchoolMemberRecord`), `lib/widgets/account_switcher_modal.dart`.

### 5.2 Home shell and dashboard

**Implemented**

- Four bottom tabs: Dashboard, Store, Standings, Profile.
- Navigation drawer with role-aware entries.
- Dashboard cards for the major modules (academics, claims, events, elections, sports, wallet, scanner, AI, library, notifications).
- Notice ticker and notice feed, with admin publishing.
- Event Wall and campus event summaries.
- House-colour theming, greeting, points, and profile summary.
- Offline/cached data presentation in several cards.
- Student profile modal used from leaderboards and other screens.

**Status:** LIVE. This is the primary integration surface and the best starting point for a user acceptance walkthrough.

**Key files:** `lib/screens/home_screen.dart`, `lib/widgets/student_profile_modal.dart`, `lib/widgets/house_card.dart`.

### 5.3 Houses, standings, and gamification

**Implemented**

- Four houses (Ruby, Sapphire, Emerald, Topaz) with house colours and emblems.
- House points ledger (`house_points/{house}`), contributor records (`house_contributors/{scholarNo}`), and leaderboard placement.
- Standings screen with total points, category/sports points, podium, and contributor list.
- House arena with spirit gauge, “live” reactor increments, blitz quiz, cup oracle, badge vault, and honours.
- Apple Fitness-style badges and a 3D mascot stage.
- Battle chant synthesizer and confetti effects.

**Status:** The leaderboard and points ledger are LIVE. The arena has substantial LOCAL/DEMO elements: the “spirit reactor” is a `system_config/house_spirit_reactor` counter that any signed-in user can increment up to 500 per update; the blitz quiz and cup oracle are simulations; the 3D mascot is presentation.

**Key files:** `lib/screens/house_leaderboard_screen.dart`, `lib/screens/house_arena_screen.dart`, `lib/widgets/apple_fitness_badge.dart`, `lib/widgets/apple_fitness_badges_vault.dart`, `lib/widgets/mascot_3d_stage.dart`, `lib/widgets/battle_chant_synthesizer.dart`, `lib/widgets/strength_meter.dart`.

### 5.4 Academics

**Implemented**

- Academic structure: grades, sections/divisions, class IDs, rosters, placements.
- Class timetable view and teacher timetable editor.
- Cross-class teacher/room double-booking preflight in `timetable_service.dart` and `teacher_timetable_editor_screen.dart`.
- Timetable approval workflow (`timetable_requires_approval`, `timetable_editing_enabled`, assigned editor UIDs).
- Homework assignments with descriptions, due dates, submission/grading fields, and cached streams.
- Exam schedules, syllabus revision vault, exam hall/desk directory, and academic images.
- Report cards with GPA/merit summaries, PDF export, and an honours-merit claim path.
- Attendance records with present/absent/late states and the CBSE 75% status indicator.
- Medical leave request, admin approval/rejection, and admin remarks. Documented policy: leave never converts an absence into attendance.
- School circulars with an admin composer, notice publishing, PDF attachment, and Base64 fallback.
- Student promotion, placement verification, section creation, house/status/transfer dialogs, and audit logs in `admin_academics_screen.dart`.
- Class group chat associated with verified class placement.

**Status:** LIVE/PARTIAL. The strongest academic pieces are the timetable, attendance, report-card, homework, and circular workflows. Caveats:

- Timetable conflict validation is **client-side preflight**, not server-enforced. A crafted client can publish a conflicting timetable if it satisfies the rules.
- Large circular PDFs require Storage/Blaze.
- The report-card honours claim is documented as fail-closed pending a server authority; the `is_merit_claimed` flag write is admin-only, so a student claim cannot persist atomically today.
- Windows Firestore is memory-only, so academic caches do not survive a restart in the same way as mobile.

**Key files:** `lib/screens/academics_screen.dart`, `lib/screens/admin_academics_screen.dart`, `lib/screens/teacher_timetable_editor_screen.dart`, `lib/services/timetable_service.dart`, `lib/services/auth_service.dart`, `lib/models/academic_class.dart`, `lib/models/class_timetable.dart`, `lib/models/academic_assignment.dart`, `lib/models/exam_schedule_item.dart`, `lib/models/academic_report_card.dart`, `lib/models/attendance_record.dart`, `lib/models/medical_leave_request.dart`.

### 5.5 Claims and approvals

**Implemented**

- Student submits a house-point claim with activity title, points, house, and certificate image/PDF.
- Certificate upload attempts Storage at `house_claims/{house}/{scholarNo}_{claimId}.jpg`, with Base64 fallback.
- Pending claims queue for admins, council, and same-house captains.
- Approve/reject with reason, point award, and student notification.
- Approved-claims gallery with certificate preview.
- AI metadata fields (`ai_status`, `ai_confidence`, `ai_markers`, `ai_summary`) are written by the Storage trigger when it runs.
- Medical leave queue and roster management are co-located in the admin claims area.
- Direct role assignment and student status controls in the admin UI.

**Status:** PARTIAL. Human review works, subject to rules and image size. AI verification is BLOCKED because Storage and the trigger are not live. Small images may work via Base64; large images can exceed Firestore's document limit. The claim's points/house are immutable after creation, which is good.

**Key files:** `lib/screens/admin_claims_screen.dart`, `lib/screens/approved_claims_screen.dart`, `lib/services/auth_service.dart` (`uploadCertificateImage`, `submitHouseClaim`, `approveHouseClaim`, `rejectHouseClaim`), `functions/index.js`, `storage.rules`.

### 5.6 Campus events

**Implemented**

- Staff event composer with draft, publish, cancel, and edit lifecycle.
- House scope and grade-range targeting.
- Student-facing published event feed, event detail, RSVP registration, and attendee counts.
- Event Wall posts with images/captions.
- Sample/cache option for demos.
- Rules enforce published status, house scope, grade eligibility, author UID, one RSVP per student, and cancellation rather than hard delete.

**Status:** LIVE. This is one of the most complete and best-ruled modules. Grade targeting and house scoping are enforced in rules as well as UI.

**Key files:** `lib/screens/events_screen.dart`, `lib/models/campus_event.dart`, `firestore.rules` (`events/{eventId}`, `events/{eventId}/registrations/{uid}`, `event_wall`).

### 5.7 Notifications

**Implemented**

- In-app notification center with categories, priority, read/unread state, and unread counters.
- Client-side fan-out to `users/{uid}/notifications` for notices, timetable changes, house/class announcements, chat alerts, and points.
- Deterministic dedupe keys / source IDs so retries do not duplicate items.
- Admin can publish notices and trigger fan-out.
- Chat service writes notification documents for message alerts.

**Status:** LIVE in-app. PUSH IS ABSENT: there is no `firebase_messaging`, no device token registration, and no background delivery. Notifications are only visible when the app reads Firestore. The rules allow any signed-in user to create a notification under any user, so spoofed notifications are possible.

**Key files:** `lib/services/notification_service.dart`, `lib/screens/notification_center_screen.dart`, `lib/models/app_notification.dart`, `firestore.rules` (`users/{userId}/notifications`).

### 5.8 Chat and groups

**Implemented**

- Direct messages between students and at least one council member/teacher.
- Deterministic DM room IDs.
- Class group chats and house group chats.
- Messages, unread counters, read receipts, pinned/hidden moderation, and chat-linked notifications.
- Group membership derived from verified class/house placement in rules (class groups use academic registry; house groups use `users.house_name`).
- UI labels messages as “Encrypted.”

**Status:** LIVE functionally, but PRIVACY IS BROKEN. `firestore.rules` allows any signed-in user to read any `chats/{channelId}` and any message. The “Encrypted” label is false: messages are stored as plaintext fields in Firestore. This is a high-severity finding, not a cosmetic issue.

**Key files:** `lib/services/chat_service.dart`, `lib/screens/chat_list_screen.dart`, `lib/screens/chat_room_screen.dart`, `lib/screens/class_group_screen.dart`, `lib/screens/house_group_screen.dart`, `lib/services/class_group_service.dart`, `lib/services/house_group_service.dart`, `firestore.rules` (`chats`).

### 5.9 Sports and trophies

**Implemented**

- Sports fixtures (`fixtures`, `sports_fixtures`) with house/team/venue/time data.
- Live match HUD with score events, timer, MVP, and player statistics.
- Tournament brackets and championship progression.
- Trophy cabinet (`sports_trophies`) and championship awarding.
- Client-side sports certification tokens and verification.
- House points integration for winners.

**Status:** LIVE but client-trusted. The rules gate writes to sports leads/captains/admin, but the integrity token is minted and verified in the client with a compiled secret. A determined sports lead or a modified client can inflate scores/points. There is no server-side match authority.

**Key files:** `lib/screens/sports_tournament_screen.dart`, `lib/screens/live_match_hud_screen.dart`, `lib/services/sports_security_service.dart`, `lib/models/sports_tournament.dart`, `lib/models/match_telemetry.dart`, `lib/models/player_sports_stats.dart`, `lib/models/sports_trophy.dart`, `firestore.rules` (`sports_fixtures`, `sports_trophies`, `house_points`).

### 5.10 Elections

This is the most consequential and least production-ready module.

**Implemented**

- Elections v2 UI: draft creation, candidate add/remove, publish, vote, receipt, participation lookup, close, certify, cancel, delete draft, audit log, gazette.
- Legacy election chamber and ballot UI.
- House/grade eligibility checks in the callable and fallback.
- Server-issued participation receipts and a “one scholar, one vote” transaction in the callable.
- Winner certification awards 100 points to the winner's house and writes a gazette.
- Client fallback (`_callFirestoreFallback`) that writes poll counts, participation, legacy election totals, and legacy vote documents.
- Admin/council election management UI and audit/gazette screens.
- Auto-provisioning of `school_members` so students can vote.

**Status:** BLOCKED / LOCAL DEMO. The callable is authored but not deployed (HTTP 404). The client attempts it with a 4-second timeout and then falls back. Under the committed rules, a student vote transaction fails because it updates the poll (admin-only), writes `election_votes` (write false), and updates the legacy election (admin-only). The transaction is atomic, so the vote is not recorded. The UI may still show cached ballots, drafts, and local receipts, which makes the election look functional when it is not.

**Critical integrity issue:** even if the callable were deployed, `election_polls_v2/{pollId}/counts/{candidateId}` is writable by any signed-in user, and `participation/{key}` is creatable by any signed-in user. Direct clients can therefore alter tallies and participation outside the server transaction. The callable's “server-authoritative” guarantee is void while those rules remain.

**Key files:** `lib/screens/school_elections_page.dart`, `lib/screens/election_chamber_screen.dart`, `lib/screens/election_audit_screen.dart`, `lib/screens/election_gazette_screen.dart`, `lib/services/election_security_service.dart`, `functions/elections-v2.js`, `firestore.rules` (`elections`, `election_votes`, `election_gazettes`, `election_polls_v2`, `election_drafts_v2`, `school_members`).

### 5.11 Store, orders, and vouchers

**Implemented**

- Ten hard-coded merchandise products with house variants and BHD prices.
- Product detail sheet, sizes, quantity, cart, favourites, and local persistence.
- “Instant buy” and cart checkout flows.
- Order creation in Firestore with student identity, items, total, status, and QR voucher payload.
- Digital wallet pass display for each order.
- Staff QR scanner validates and claims vouchers; `orders` status and `claimed_by`/`claimed_at` are updated by an admin.
- Order history, claim status, and local wallet cache.

**Status:** PARTIAL. The catalogue/cart/order/voucher flow exists, but THERE IS NO PAYMENT GATEWAY. Checkout creates an order with `total_pts: 0` and a “PAID (BHD)” presentation without collecting money. Fulfilment relies on staff manually marking an order claimed. Voucher signatures are optional: the validator accepts legacy unsigned `ASB-ORDER-*` payloads and JSON without a token, so the QR is not a reliable proof of payment. The rules allow any signed-in user to create an order; without payment verification, fake/abusive orders are possible.

**Key files:** `lib/screens/merch_store_tab.dart`, `lib/services/voucher_security_service.dart`, `lib/screens/id_scanner_screen.dart`, `firestore.rules` (`orders`).

### 5.12 Digital wallet, passes, and fee receipts

**Implemented**

- Three wallet tabs: Store Passes, Campus ID, Fee Receipts.
- On-screen QR passes for orders and student ID.
- Campus ID with scholar number, house, class, points, and access tier.
- Fee receipt card with a fixed `BHD 150.000` amount and `PAID IN FULL` status.
- “Add to Apple Wallet” / “Save to Google Wallet” buttons.
- “NFC Active” presentation.
- PDF export and print actions via `PassDocumentExporter`.
- Web export reports a synthetic `browser_download:` success.

**Status:** LOCAL/DEMO for the native wallet, payments, and NFC. The Apple/Google buttons show success sheets but do not create a `.pkpass` or Google Wallet pass object; no signing service exists. The fee receipt is hard-coded and not linked to a billing system. The PDF exporter is a real pure-Dart PDF, but it prints QR data as text rather than rendering a scannable QR image; on web it returns a synthetic success without a real browser download.

**Key files:** `lib/screens/digital_wallet_screen.dart`, `lib/services/pass_document_exporter.dart`, `lib/services/voucher_security_service.dart`.

### 5.13 ID scanning and behaviour evaluation

**Implemented**

- Camera scanning on mobile, upload/image decode path, and manual scholar-number lookup.
- Voucher validation and claim flow.
- Student pass validation.
- Navigation to a behaviour evaluation screen for merit/demerit.
- Merit/demerit reasons, 1–100 points, evaluator identity, and record revocation.
- Conduct records and student notifications.

**Status:** LIVE, client-trusted. The scanner validates HMACs generated by the client, with a compiled fallback secret. The voucher validator accepts unsigned legacy payloads. A modified client can forge a pass or voucher; the remaining protection is the Firestore order/claim check and staff presence. Behaviour writes are restricted to admin/council by rules, which is good.

**Key files:** `lib/screens/id_scanner_screen.dart`, `lib/screens/student_behavior_evaluation_screen.dart`, `lib/services/qr_decoder_service.dart`, `lib/services/voucher_security_service.dart`, `lib/services/auth_service.dart` (`recordStudentConduct`, `revokeConductRecord`), `firestore.rules` (`student_conduct`).

### 5.14 Library

**Implemented in the client**

- Library portal modal from the home screen.
- Three hard-coded borrowed books with due day counters and renewal counts.
- Renewal action adds 14 days and increments the local renewal count.
- Local cache in `SharedPreferences`, plus an attempted `library_loans/{scholarNo}` Firestore write.
- UI text describes a “catalog” and live loans.

**Server-side**

- `schoolLibrary` callable exists with transactional `checkout`, `return`, and `renew` against `library_loans_v2` and `library_copies_v2`.
- No client code calls the callable.
- No Firestore rules exist for the client's `library_loans` path (the callable uses Admin SDK, which bypasses rules).

**Status:** LOCAL/DEMO. The three books are hard-coded, the renewal is local, and the backend is never invoked. The Firestore `library_loans` write is likely denied by default-deny rules; the UI continues from local cache. This should not be presented as a live library system.

**Key files:** `lib/screens/home_screen.dart` (`_borrowedBooks`, `_showLibraryPortalModal`, `_saveLibraryLoans`), `functions/library-v2.js`, `firestore.rules`.

### 5.15 AI assistant

**Implemented**

- House AI chat screen with suggested prompts: timetable, attendance, homework, house rank, sports, exams, battle chant.
- Direct Gemini REST calls to `generativelanguage.googleapis.com` with a user-supplied API key stored in `SharedPreferences`.
- Candidate models: `gemini-2.0-flash`, `gemini-1.5-flash`, `gemini-1.5-pro`.
- Local heuristic/contextual fallback when no key is configured or the API fails.
- API-key settings UI and status indicator.

**Status:** PARTIAL / optional. The AI assistant is not a Firebase feature and does not require Blaze. It does require a Gemini API key and network access. The key is stored in plain shared preferences on the device, not in a secure keystore; a server proxy would be safer but would require Blaze. The model names are old and may be retired; the fallback keeps the screen usable but is not a real model response.

**Key files:** `lib/screens/house_ai_chat_screen.dart`, `lib/services/gemini_ai_service.dart`.

### 5.16 Administration and governance

**Implemented**

- Admin academics console: class/section creation, roster placement verification, promotion, timetable approval/rejection, status/house/transfer dialogs, audit log.
- Admin claims console: pending claims, medical leaves, approved gallery, roster management, role assignment.
- Notice/circular composer with admin publish.
- Event management and election management.
- Account switching and admin login.
- Client-side hierarchy policy in `HierarchyService` (hard-coded super-admin scholar IDs, role/email checks, captain/council/prefect inclusion, timetable editor gate).
- Firestore rules for admin roster, teachers/faculty, senior admin, and super admin.

**Status:** LIVE with governance caveats. The admin console is broad and useful for a pilot, but it inherits the identity and rules problems in §7. The fixed bootstrap admin account and the uncommitted auto-reauthentication change are the most important operational risks.

**Key files:** `lib/screens/admin_academics_screen.dart`, `lib/screens/admin_claims_screen.dart`, `lib/services/hierarchy_service.dart`, `lib/services/auth_service.dart`, `lib/screens/home_screen.dart`.

---

## 6. Firebase Blaze plan analysis

### 6.1 Plan facts used in this audit

The following are the relevant 2026 Firebase/Google Cloud constraints. They were checked against current official documentation during the audit.

| Service | Plan / billing requirement | Consequence for this app |
|---|---|---|
| Cloud Functions for Firebase (v2) | Deployment requires the Blaze (pay-as-you-go) plan; Cloud Build and Artifact Registry must be enabled | All three authored functions are undeployable on Spark |
| Cloud Storage for Firebase | New provisioning requires Blaze; Blaze includes a 5 GB no-cost allowance | The project has no initialized bucket; certificate/circular hosting and the Storage trigger are blocked |
| Cloud Vision API | Billing must be enabled; first 1,000 units/month are free | Logo detection/OCR cannot run without a billing account |
| Gemini Developer API | Free tier is available with an API key; paid tiers require billing | The AI assistant can work on Spark, but only with a user key; a server proxy would need Blaze |
| Cloud Firestore | Spark has a free quota; rules deployment is free | Core app data works on Spark within quotas |
| Firebase Authentication | Spark-compatible for email/password within quotas | Login/signup work on Spark |
| Firebase Cloud Messaging (FCM) | No-cost | Push itself does not require Blaze; sending from Cloud Functions would |
| App Check | No-cost | Not currently integrated on the client |
| Firebase Hosting | Separate product; not configured | Not relevant to this app |

**Important:** Blaze is necessary for the authored server features, but it is **not sufficient** for election integrity or data privacy. The rules defects in §7 remain after an upgrade.

### 6.2 Authored but undeployed

| Function | What activates on deployment | Blaze dependency | Current Spark behavior |
|---|---|---|---|
| `schoolElection` | Server-side vote transaction, receipt, participation lookup, draft lifecycle, certification, gazette, audit | Functions deployment (Blaze) | Endpoint 404; client waits 4 s and falls back; student fallback fails under rules |
| `schoolLibrary` | Server-side checkout/return/renew, loan state, copy state | Functions deployment (Blaze) | Endpoint 404; no client call site; library remains local |
| `verifyCertificateSignature` | Storage-triggered Vision logo/OCR analysis; `ai_*` fields | Functions + Storage + Vision billing | No Storage object; no trigger; human review only |

### 6.3 Blaze-required feature matrix

The “Blaze?” column answers the practical question: **can the feature work as designed on Spark today?**

| Capability | Current implementation | Blaze required today? | Spark behavior / workaround | Priority |
|---|---|---|---|---|
| Deploy `schoolElection` | Authored callable | **Yes** | 404; fallback path; live student vote fails | P0 |
| Live, server-authoritative elections | Callable plus Firestore fallback | **Yes** | Only local/demo; counts open to tampering | P0 |
| Deploy `schoolLibrary` | Authored callable | **Yes** | 404; not called; local library | P1 |
| Deploy `verifyCertificateSignature` | Authored Storage trigger | **Yes** | No AI verification; human review only | P1 |
| Cloud Storage bucket / certificate uploads | Storage rules + client upload | **Yes** | Base64 fallback; no object; 1 MiB doc cap | P0/P1 |
| Large circular PDFs (> ~700 KB) | Storage upload with inline fallback | **Yes** | Explicit failure; no large PDFs | P1 |
| AI certificate verification | Cloud Vision logo/OCR | **Yes** | Never runs without Storage/trigger/Vision | P1 |
| Native Apple Wallet `.pkpass` | No implementation | **Yes** for server signing | Buttons are simulated; PDF text pass only | P2 |
| Native Google Wallet pass | No implementation | **Yes** for server JWT signing | Buttons are simulated | P2 |
| `schoolGamification` server authority | Not authored | **Yes** for server design | Direct point writes by privileged roles; student awards fail closed | P1 |
| Sports certification server authority | Not authored; client HMAC | **Yes** for server design | Client-minted tokens; trust-based | P1 |
| Server notification fan-out / push send | Client-side Firestore fan-out only | **Conditional** (FCM free; Functions send needs Blaze) | In-app notifications work; no device push | P1 |
| Atomic promotion / transfer callable | Not authored; client sequential writes | **Conditional** (a client transaction is possible) | Sequential writes with failure reporting | P2 |
| Server timetable conflict validation | Client preflight only | **Conditional** | Works client-side; no server enforcement | P2 |
| Gemini assistant | Direct client REST with user key | **No** | Works on free tier with a key; local fallback | P2 |
| Payment gateway / fee billing | None | **No** (external PSP) | No payment; simulated paid states | P0 product decision |
| App Check enforcement | Server flag only; no client SDK | **No** (App Check is free) | Cannot safely enforce on mobile/web yet | P1 |
| Firestore backups / PITR / monitoring | Not configured | Operational; likely Blaze | No managed backup/restore | P1 |

### 6.4 Features that do **not** require Blaze

These can remain on Spark, within Firestore/Auth quotas, if the security rules are fixed:

- Email/password auth, profile creation, onboarding, account switching, password reset.
- Firestore-backed academics: classes, timetable, homework, exams, report cards, attendance, medical leave, circulars (small PDFs).
- House points, leaderboard, contributors, conduct records, claims with human review, and small Base64 certificate images.
- Campus events, RSVPs, notices, event wall, class/house groups, in-app notifications.
- Store catalogue, cart, local favourites, order documents, QR voucher display, and staff claim flow (but not real payment).
- Client-side PDF/QR generation, on-screen passes, and local library cache.
- Sports fixtures, live HUD, stats, trophies, and client-side certification (with integrity caveats).
- Gemini AI with a user-supplied key and free-tier quota.
- FCM push itself, if a trusted sender is available; sending from this project's Cloud Functions would need Blaze.
- App Check client integration (the service is no-cost).

### 6.5 Cost expectations

The project's existing `INFRASTRUCTURE_AND_PRICING_GUIDE.md` says Firebase is “100% free forever (Spark).” That statement is no longer true for this app's intended feature set: Cloud Functions and Storage require Blaze, and Vision requires billing. The practical cost is usage-based and likely modest for a single school, but it is not zero by policy.

- **Functions:** Blaze includes monthly no-cost invocation/compute allowances; verify the current quotas. A school-scale election/claims workload is likely far below the free allowance; the risk is accidental loops or abusive traffic.
- **Storage:** Blaze includes 5 GB no-cost. Certificate images and circulars can fit, but retention and duplicate uploads matter.
- **Vision:** First 1,000 units/month free; OCR/logo detection per certificate. This is the most likely line item if every claim is scanned.
- **Gemini:** Free tier with a user key; paid tier if the school wants a managed key/proxy. A direct client key is free but insecure.
- **Budget controls:** Set a Google Cloud budget and alerts before enabling Blaze. Do not rely on “free tier” assumptions.

### 6.6 Recommended upgrade sequence

1. Upgrade `asb-house-hub` to Blaze in the Firebase Console and attach a billing account with budget alerts.
2. Enable Cloud Build, Artifact Registry, Cloud Functions, Cloud Storage, and Cloud Vision APIs as prompted.
3. Initialize the default Storage bucket; deploy `storage.rules`.
4. Store server secrets in Google Secret Manager or Functions environment configuration; do not ship them in the client.
5. Deploy `functions/` and verify `schoolElection` returns an auth error rather than 404.
6. Run the six-step live election smoke test from `election_audit/BLAZE_REQUIRED_FEATURES.md` — but only **after** the rules hotfix.
7. Test a >700 KB circular PDF and a certificate image; confirm Storage URLs and AI fields.
8. Add App Check to mobile/web clients; keep Windows on compensating controls or document the gap.
9. Re-run security/rules tests and a live claims/election smoke test.
10. Update the Blaze deferral document and the infrastructure guide to match reality.

---

## 7. Security, integrity, and privacy findings

> **Assumption:** the committed `firestore.rules` is the deployed ruleset, as stated by the project's own Blaze deferral document. If the live rules differ, re-test these findings in the Firebase Console or Emulator.

### 7.1 Critical: `school_members` self-write enables super-admin escalation

**Evidence**

- `firestore.rules:1833-1836`:

  ```rules
  match /school_members/{memberId} {
    allow read: if isSignedIn();
    allow write: if isSignedIn() && (isOwner(memberId) || isAdmin());
  }
  ```

- `firestore.rules:265-283` — `isSuperAdmin()` returns true if the caller's `school_members/{uid}.role` is `super_admin` or `admin`.
- `firestore.rules:294-300` — `isAdmin()` includes `isSuperAdmin()`.
- `functions/elections-v2.js:107-115` — the election callable reads `school_members/{uid}` and requires `active === true`.
- `functions/elections-v2.js:178-180` — election management requires `person.capabilities.manage_elections === true`.
- `lib/services/auth_service.dart:4468-4565` — `ensureSchoolMemberRecord` writes `role`, `house`, `grade`, and `capabilities` from a cached profile with no server validation.

**Attack chain**

1. Any signed-in student writes their own `school_members/{uid}` document with `role: 'super_admin'` and `capabilities: { manage_elections: true }`.
2. `isSuperAdmin()` now returns true for that UID.
3. `isAdmin()` and `isSeniorAdmin()` inherit that truth.
4. The student can write `admin_roster`, election drafts/polls, notices, classes, events, claims, orders, and other collections governed by those helpers.
5. The election callable, once deployed, also trusts the forged membership and grants election management.

**Impact:** complete Firestore authorization bypass for the affected user. This is the highest-severity finding in the audit.

**Immediate fix:** make `school_members` writes server/admin-only, remove `school_members.role` from `isSuperAdmin()` until a server-managed roster exists, add strict field validation if any self-service fields remain, and migrate role/capability assignment to a callable using Admin SDK plus audited admin approval. Do not rely on the client's `ensureSchoolMemberRecord` for authorization.

### 7.2 Critical: election tallies and participation are client-writable

**Evidence**

- `firestore.rules:1839-1852`:

  ```rules
  match /election_polls_v2/{pollId} {
    allow read: if true;
    allow write: if isAdmin();

    match /counts/{candidateId} {
      allow read: if true;
      allow write: if isSignedIn();
    }

    match /participation/{key} {
      allow read: if false;
      allow create: if isSignedIn();
      allow update, delete: if false;
    }
  }
  ```

- `lib/screens/school_elections_page.dart:609-702` — the fallback transaction writes `participation`, increments `counts`, updates the poll, and writes legacy election/vote documents.

**Impact:** any signed-in user can set or increment vote counts directly, without a ballot, receipt, eligibility check, or transaction. Participation documents can be created by any signed-in user. Even if `schoolElection` is deployed, its server transaction is not the only writer; the tally is not trustworthy.

**Immediate fix:** set `counts` and `participation` writes to `false`; only the Admin SDK callable should write them. Keep reads as appropriate. Add rules tests that assert direct writes fail. If a fallback must exist, it cannot be a secure election; label it a local demo and disable live result certification.

### 7.3 Critical: the live election fallback is incompatible with the rules

**Evidence**

- `lib/screens/school_elections_page.dart:449-488` attempts the callable, catches any failure, and unconditionally calls `_callFirestoreFallback`.
- `lib/screens/school_elections_page.dart:609-702` runs a Firestore transaction that:
  - creates `participation/{key}` (allowed),
  - increments `counts/{candidateId}` (allowed, but insecure),
  - updates `election_polls_v2/{pollId}` (admin-only),
  - updates legacy `elections/{pollId}` (admin-only),
  - writes `election_votes/{id}` (write false).
- The transaction is atomic; the denied poll/legacy/vote writes abort the whole transaction. The UI catches the error and reports that the vote could not be recorded.

**Impact:** with Firebase live, a student cannot cast a vote without the callable. The fallback is not a Spark-compatible election; it is a broken one. Admin fallback can create drafts/polls but voting still fails. Offline/demo mode (`AuthService._isFirebaseLive == false`) can use local caches, but that is not a school election.

**Fix:** deploy the callable and remove the live fallback, or hide elections until Blaze; do not present local demo results as certified. The audit document's claim that the fallback is a safe Spark path should be corrected.

### 7.4 High: public user directory and self-asserted identity

**Evidence**

- `firestore.rules:1203-1205` — `users/{userId}` has `allow read: if true`.
- `lib/services/auth_service.dart:4406-4448` — signup accepts a scholar number, name, age, class, division, and house, then writes `role: 'student'` and `class_verified: false`.
- `firestore.rules:495-535` — `isValidUser` validates field shapes and allowed roles but does not verify a school roster.
- `firestore.rules:471-475` — `isScholarOwner` trusts the email prefix or the user document's `scholar_no`.

**Impact:** anyone, including an unauthenticated client, can enumerate student profiles, roles, houses, classes, and scholar numbers. Anyone can register an unused scholar number, choose a house/class, and be treated as that scholar for claims, orders, and other owner-scoped data. `class_verified: false` is only a flag; it does not stop access. This is identity spoofing and a privacy breach. The unauthenticated REST fallback that compounds it is detailed in §7.16.2.

**Fix:** restrict `users` reads to signed-in users (or a dedicated directory collection with limited fields); pre-provision accounts or require an invite/roster code; verify scholar number, name, house, and class server-side; make identity fields immutable after verification; do not use a self-entered scholar number as an ownership credential.

### 7.5 High: self-service house/grade changes affect authorization

**Evidence**

- `firestore.rules:1226-1248` — self-update requires `role`, `points`, `points_contributed`, `scholar_no`, `created_at`, `uid`, `class_id`, `class_verified`, and `status` to remain unchanged, but it does **not** protect `house_name`, `grade`, `class_level`, `division`, or `full_name`.
- `firestore.rules:372-377` — `isSameHouse()` uses `users.house_name`.
- Event rules use `isSameHouse` and grade eligibility; house group rules use `isSameHouse`.
- Election fallback derives grade/house from the cached profile; `ensureSchoolMemberRecord` derives grade from `class_level`/`grade`.

**Impact:** a student can change their own house and grade, then access another house's groups/events or meet a different election/event eligibility band. They can also change their display name to impersonate another student. `class_id` and `class_verified` are immutable, but `grade` is not, creating an inconsistent and exploitable profile.

**Fix:** make house, grade, class, division, full name, and scholar number admin/verification-controlled; use a server-verified roster for eligibility; do not derive authorization from self-asserted profile fields.

### 7.6 High: chat privacy and false “Encrypted” labeling

**Evidence**

- `firestore.rules:1670-1692` — `chats/{channelId}` and `chats/{channelId}/messages/{messageId}` allow `read` to any signed-in user; no participant check.
- `lib/screens/chat_room_screen.dart:578,971` — UI labels the room/message input as “Encrypted.”
- `lib/services/chat_service.dart` — client restricts DM creation to at least one council/teacher, but rules do not enforce that constraint on reads.

**Impact:** any authenticated account can read any direct message or group message if it knows or guesses the channel ID. Deterministic DM room IDs make discovery easier. Messages are plaintext fields; there is no end-to-end encryption. The “Encrypted” label is misleading and could create a false expectation of confidentiality.

**Fix:** restrict reads to `request.auth.uid in resource.data.participants` for channels and to channel members for messages; add rules tests; remove the “Encrypted” label unless real E2E encryption is implemented. E2E would require a different data model and key management, not just a label.

### 7.7 High: client-side secrets and home-grown credential storage

**Evidence**

- `lib/services/auth_service.dart:43-146` — `CredentialVaultService` uses a custom HMAC-SHA256 keystream + HMAC tag, with a hard-coded fallback secret when `VAULT_SECRET` is absent. It is not AES-GCM and the key is in the client.
- `lib/services/auth_service.dart:54-61` — `VAULT_SECRET` environment value falls back to a compiled literal.
- `lib/services/election_security_service.dart:17-22` — `ELECTION_HMAC_SALT` fallback.
- `lib/services/gamification_security_service.dart:60-78` — `GAMIFICATION_HMAC_SECRET` fallback despite a “fail-closed” comment.
- `lib/services/sports_security_service.dart:17-25` — `SPORTS_CERT_SECRET` fallback.
- `lib/services/voucher_security_service.dart` — client-generated voucher HMAC and student-pass HMAC.
- `lib/services/voucher_security_service.dart:108-122` — legacy unsigned `ASB-ORDER-*` payloads are accepted as valid.
- `lib/services/voucher_security_service.dart:172-192` — if a JSON payload has no token, signature verification is skipped.

**Impact:** a compiled secret is not a secret. Anyone with the app binary can extract it and mint election receipts, score proofs, sports certificates, student passes, or voucher tokens. The credential vault protects saved passwords only against casual inspection; a local attacker who can read app storage and extract the key can decrypt them. Legacy unsigned voucher acceptance makes the QR signature advisory, not mandatory.

**Fix:** move trust-bearing signatures to a server (Admin SDK/Secret Manager); remove all runtime fallbacks and fail closed in release; use platform secure storage for local secrets (Keychain/Keystore/DPAPI) or avoid storing passwords; require voucher signatures and reject unsigned/legacy payloads after migration; rotate any secret that has shipped.

### 7.8 High: shared admin account and automatic re-authentication

**Evidence**

- `lib/services/auth_service.dart:4362-4381` — `signInAdmin` uses a single fixed admin email and writes an admin profile.
- `lib/services/hierarchy_service.dart` — hard-coded super-admin scholar IDs and role/email policy.
- Uncommitted change in `lib/services/auth_service.dart` (`publishSchoolNotice`) — if the current user is null, it reads saved accounts, finds an `admin` account with a stored password, and calls `signInAdmin` automatically.

**Impact:** all administrators share one identity, so audit logs cannot distinguish them. Saved admin passwords are encrypted with a client-side key and can be replayed on the device. The auto-reauth change makes a stale session silently regain admin power, which is convenient but dangerous on shared/kiosk devices. This change is user work in progress and was not modified by the audit, but it should be reviewed before commit/release. The hardcoded bootstrap identity path is separately confirmed in §7.16.1.

**Fix:** individual admin accounts with role claims and MFA; remove the shared bootstrap credential from daily use; require explicit re-authentication with a fresh password or SSO; do not store admin passwords on shared devices; add audit identity to every admin action.

### 7.9 Medium: Storage rules are authenticated but not role-scoped

**Evidence:** `storage.rules:21-54`

- `house_claims/{house}/{fileName}`: any signed-in user can write an image/PDF up to 10 MB, for any house.
- `claims/{fileName}`: same legacy path.
- `profile_pictures/{userId}`: owner-only, good.
- `exam_schedules/{fileName}`: any signed-in user can write image/PDF up to 15 MB.
- `circulars/{noticeId}/{fileName}`: any signed-in user can write a PDF up to 15 MB; no admin check.
- Default `write: false` for other paths.

**Impact:** after Storage is initialized, any student account can upload files to claims/exam/circular paths, causing cost/abuse and potentially placing malicious PDFs where staff expect official documents. Firestore notice publishing is still admin-only, so an attacker cannot directly publish a circular, but they can consume storage and create confusing objects.

**Fix:** scope claim writes to the owner/house; restrict exam/circular writes to staff roles; validate content type and size server-side where possible; add retention/cleanup.

### 7.10 Medium: notification spoofing

**Evidence:** `firestore.rules:1254-1276` — any signed-in user can create a notification under any `users/{userId}/notifications` path, provided it passes `isValidNotification`. Deduplicated updates are also broadly allowed.

**Impact:** a user can send a fake “urgent” notification to another user, including a forged sender/category, as long as the document shape is valid. There is no server-side fan-out or signing.

**Fix:** restrict creates to server/admin or a callable that verifies the event source; use a server-written notification document; add a `source`/signature check if client fan-out must remain.

### 7.11 Medium: order, voucher, and payment integrity

**Evidence**

- `firestore.rules:1474-1495` — any signed-in user can create an order with status in `placed`/`pending`/`verified`/`ready`; updates/claims are admin-only.
- `lib/screens/merch_store_tab.dart:2200-2277` — checkout creates an order with `totalPts: 0` and opens a wallet pass; no payment provider.
- `lib/services/voucher_security_service.dart:111-122` — unsigned `ASB-ORDER-*` accepted.
- `lib/services/voucher_security_service.dart:172-192` — tokenless JSON accepted.
- `lib/screens/digital_wallet_screen.dart` — fixed `BHD 150.000` / `PAID IN FULL` fee receipt; Apple/Google/NFC simulations.

**Impact:** a student can create an order without paying and may receive merchandise if staff fulfil it without checking payment. A forged voucher can be presented for a real order; the signature is not required. The fee receipt and wallet status are not financial records. The fixed fee receipt is elevated to a release-blocking document-fabrication issue in §7.16.4.

**Fix:** integrate a payment provider or explicitly make checkout “pay at the counter” with a pending-payment state; require staff payment confirmation before fulfilment; require signed vouchers and server-side verification; make fee receipts data-driven; label simulated wallet/NFC actions as demos.

### 7.12 Medium: house points and spirit reactor can be inflated

**Evidence**

- `firestore.rules:1708-1733` — sports leads, council, and same-house captains can update `house_points` with positive increments up to 500 per update; no rate limit or idempotency.
- `firestore.rules:1771-1787` — any signed-in user can create/update `system_config/house_spirit_reactor` with positive increments up to 500.
- `lib/screens/house_arena_screen.dart` — spirit gauge and quiz interactions.

**Impact:** a privileged user can repeat increments to inflate house points; any signed-in user can inflate the decorative spirit reactor. The leaderboard may not reflect a single authoritative ledger.

**Fix:** move awards to a server callable with idempotency keys and audit logs; rate-limit or remove self-service spirit increments; lock direct `house_points` writes.

### 7.13 Lower-severity observations

| ID | Observation | Impact |
|---|---|---|
| L1 | `ErrorWidget` displays exception text | Internal detail leakage |
| L2 | No `FlutterError.onError`/`PlatformDispatcher.onError` or Crashlytics | Production diagnostics gap |
| L3 | No analytics/performance monitoring | No usage or latency visibility |
| L4 | All UI strings hard-coded; l10n unused | No Arabic/Urdu/Hindi localization despite scaffold |
| L5 | Windows Firestore persistence disabled | Different offline behavior; data may not survive restart |
| L6 | Gemini API key in `SharedPreferences` | Device compromise exposes the key; use secure storage/proxy |
| L7 | No FCM/device tokens | Notifications only appear when app is open/refreshed |
| L8 | No `cloud_functions` SDK; raw HTTP callables | Fragile error/retry/CORS behavior; manual envelope parsing |
| L9 | No route guards/deep links | Screen-level auth assumptions can drift |
| L10 | No visible “demo mode” banner at app root | Users may mistake local fallbacks for live data |

### 7.14 Rules posture summary

| Collection / path | Read | Write | Main issue |
|---|---|---|---|
| `users/{uid}` | **Anyone (`true`)** | Owner create/update with restrictions; admin/super admin | Public directory; self-asserted house/grade/name; role protected but identity is not |
| `users/{uid}/notifications` | Owner/admin | Any signed-in create | Spoofing |
| `school_members/{uid}` | Any signed-in | **Owner or admin** | Self-write role/capabilities → super-admin escalation |
| `admin_roster/{id}` | Any signed-in | Super admin | Fine if super-admin is trustworthy |
| `house_claims` | Owner/admin/council/captain | Owner create pending; staff/council/captain update | Points/house immutable; review path okay |
| `orders` | Owner/admin | Any signed-in create; admin update | No payment verification; fake orders |
| `elections/{id}` | Public | Admin | Legacy poll admin-only |
| `election_votes` | False | False | Good |
| `election_gazettes` | Public | Admin | Fine |
| `election_polls_v2` | Public | Admin | Poll itself protected |
| `.../counts` | Public | **Any signed-in** | **Tally tampering** |
| `.../participation` | False | **Any signed-in create** | **Fake participation** |
| `election_drafts_v2` | Any signed-in | Admin | Draft candidate privacy, minor |
| `chats` / messages | **Any signed-in** | Participant/admin (write); any signed-in read | **No read privacy; “Encrypted” false** |
| `house_groups` / messages | Same house/senior admin | House sender/moderator | Reasonable, but house can be self-changed |
| `class_groups` / messages | Class viewer | Class moderator | Reasonable |
| `house_points` | Any signed-in | Admin/sports lead/council/captain (bounded positive) | Repeatable inflation |
| `house_contributors` | Any signed-in | Admin/council/captain | Same |
| `student_conduct` | Owner/admin/council/prefect | Admin/council | Reasonable |
| `medical_leaves` | Owner/admin | Owner create; admin review | Good |
| `sports_fixtures` / events | Any signed-in | Sports lead/admin | Client trust; no server certification |
| `sports_trophies` | Any signed-in | Sports lead/admin | Same |
| `events` / registrations | Signed-in, published/house/grade | Staff; owner RSVP | Strong |
| `notices` / announcements | Signed-in | Admin | Good |
| `system_config/house_spirit_reactor` | Signed-in | Any signed-in positive increment | Demo counter can be gamed |
| Storage `house_claims`, `exam_schedules`, `circulars` | Signed-in | Any signed-in (type/size only) | No role/owner scoping |
| Storage `profile_pictures/{uid}` | Signed-in | Owner | Good |

### 7.15 Truthfulness matrix — what is real vs simulated

| Feature | What the UI implies | Reality |
|---|---|---|
| Apple Wallet / Google Wallet | Pass is added/synced | Success sheet only; no `.pkpass`/Google Wallet object, no signing |
| NFC access | “NFC Active” | Decorative label; no NFC read/write integration |
| Fee receipt | `BHD 150.000`, `PAID IN FULL` | Fixed placeholder; no billing/fee system |
| Store checkout | Order/payment completed | No payment gateway; staff manually claim; `total_pts: 0` |
| Library | Borrowed books, renewals | Three hard-coded books; local cache; backend never called |
| Elections | Live school election | Callable 404; fallback fails under rules; local demo only |
| AI certificate verification | AI-scanned certificate | No Storage bucket/trigger; AI fields never populated |
| Chat | “Encrypted” | Plaintext Firestore; any signed-in user can read |
| House arena spirit/quiz/oracle | Live gamified house reactor | Counter increments and local simulations |
| PDF “pass” | Scannable pass | Text-only PDF; QR data printed as text, not a QR image |
| Web PDF export | Download succeeds | Synthetic `browser_download:` result; no browser download |
| Push notifications | Alerts/notifications | In-app Firestore documents only; no FCM/device push |
| Sports certification | Certified results | Client HMAC with compiled fallback secret; trust-based |
| Student points from arena | Earned points | Student direct awards fail closed under rules; local demo/privileged paths only |

### 7.16 Findings confirmed during the 21-finding verification

These findings were re-checked on 25 November 2026 against the cited code. They supplement, and in two cases sharpen, the findings above. Full per-finding verdicts are in Appendix G.

#### 7.16.1 Critical — bootstrap super-admin is hardcoded on both sides

**Evidence**

- `lib/services/auth_service.dart:4520-4522` — `scholarNo == '11209'` and `scholarNo == 'admin'` force `isStaffOrAdmin`; `HierarchyService.isSuperAdmin()` repeats the same literals at `lib/services/hierarchy_service.dart:13-17`.
- `lib/services/auth_service.dart:4529-4548` — `ensureSchoolMemberRecord` then writes `role: 'admin'` for those identities.
- `lib/services/auth_service.dart:3721-3744` — `saveAccount()` rewrites a saved account's cached role to `super_admin` and its class to `Staff`.
- `firestore.rules:265-276` — `isSuperAdmin()` returns true for the exact token emails `admin@asianschool.bh` and `11209@asianschool.bh`.
- `firestore.rules:1207-1215` — `users` creation has a matching bootstrap-email exception.
- `firestore.rules:507-508` — the `users` validator rejects `scholar_no` `admin`/`11209`, but the client creates the Firebase Auth user first at `auth_service.dart:4415-4421`, before writing the profile at line 4448.

**Why the cited line alone understates the problem:** the `users` document can be rejected while the Auth token still carries the bootstrap email. `isSuperAdmin()` checks the token email before any profile is required, so a rejected profile is not a reliable barrier. The separate `school_members` self-write path (§7.1) already grants the same power without any bootstrap identity at all. The hardcoded `11209` path is therefore one of at least two escalation routes, not the only one.

**Impact:** while a bootstrap Auth account is unclaimed, a user can create it with the reserved email and satisfy rules-level `isSuperAdmin()` even though the profile write is rejected; if the account is already claimed, the hardcoded literals still make it a fixed, APK-visible target and the rules email trust remains a single point of failure. A user who can write their own `school_members` document obtains the same power without any special number. Hardcoded identifiers cannot be rotated without shipping a new build.

**Fix:** remove every literal identity check from the client; remove email-based trust from `firestore.rules`; set `admin`/`super_admin` only through a server-side custom claim or protected roster; reserve and pre-provision bootstrap accounts, block self-signup for them, and rotate their credentials. Then delete the `school_members` self-write path per §7.1.

#### 7.16.2 Critical — unauthenticated REST fallback into a public user directory

**Evidence:** `lib/services/auth_service.dart:3970-4003` posts a `runQuery` for `users.scholar_no` with only `Content-Type`, no `Authorization` header. `firestore.rules:1203-1205` allows `users` reads to anyone.

**Impact:** an unauthenticated caller who knows the project ID can probe scholar numbers and confirm accounts. The fallback is not the root cause — the public `users` rule is — but it is an unnecessary unauthenticated path and it bypasses the authenticated SDK query above it. Removing only the fallback leaves the enumeration possible through the public rule.

**Fix:** delete the REST fallback; require an ID token on any REST call; restrict `users` reads to authenticated, authorized callers or a minimal directory collection; rate-limit existence checks and move them server-side.

#### 7.16.3 Critical on shared devices / High otherwise — account switch swaps local data before auth succeeds

**Evidence:** `lib/services/auth_service.dart:3877-3902` attempts `signIn`/`signInAdmin` and swallows every failure; `3904-3928` then unconditionally writes `cached_scholar_no`, `cached_uid`, house, and profile; `lib/widgets/account_switcher_modal.dart:193-198` switches on tap without a password prompt.

**Impact:** on a shared or kiosk device, anyone can tap a saved account and see that student's cached grades, attendance, profile, and house even if the password is wrong, the network is down, or the account was never re-authenticated. Firestore's `currentUser` can still be the previous account while the UI displays the target identity, producing mixed-identity reads. This is not a server-side authentication bypass, but it is a local confidentiality and session-integrity failure.

**Fix:** switch only after a successful live re-authentication (or use Firebase Auth persistence and restore the session through the SDK); do not swap caches on failure; encrypt cached profiles per account and clear sensitive caches on logout; require a device credential for account switching.

#### 7.16.4 Critical for product/legal risk — fabricated fee receipt

**Evidence:** `lib/screens/digital_wallet_screen.dart:771-789` renders a fixed `TUITION & ACTIVITY FEE RECEIPT`, `Receipt #REC-2026-T2`, `PAID IN FULL`, `BHD 150.000`, and a QR payload `ASB-FEE:<scholar>:PAID:TERM2` for every student. No payment collection or provider is consulted.

**Impact:** the screen fabricates a financial document with a scannable QR code. A screenshot can be presented as proof of payment; parents may rely on it; the school has no record backing it. This is a release blocker even though it is not a privilege-escalation bug.

**Fix:** remove the fixed receipt or label it unmistakably as a sample; drive fees from a real payments collection; issue signed, server-generated receipts only after reconciliation; show `PENDING`/`UNPAID` when no record exists.

#### 7.16.5 High — three attendance formulas and a 100% empty default

**Evidence**

- Home: `lib/screens/home_screen.dart:6330-6343` computes `(present + excused + late × 0.5) / total × 100`, then falls back to `attendance_rate`, then to `100.0%`.
- Gemini: `lib/services/gemini_ai_service.dart:421-430` computes `present / total × 100` and ignores excused and late.
- Academics: `lib/models/attendance_record.dart:182-183` computes `presentDays / totalDays × 100` and returns `100.0` when `totalDays == 0`; `attendance_record.dart:222-228` omits late/excused from `presentDays`; `academics_screen.dart:6420` uses that summary.

**Impact:** the same 80 present / 10 late / 10 excused record shows **95%** on the home screen, **80%** in the AI assistant and academic summary, and **100%** when there are no records. The 75% compliance message can therefore be wrong in either direction. The external report’s example says the home screen shows 90%; the code actually produces 95%, so the discrepancy is even larger.

**Fix:** one shared `calculateAttendancePercentage()` with an explicit institutional policy, used by home, Gemini, academics, and report cards; return `null`/“No attendance data” for an empty set; add tests for present/late/excused/absent and empty.

#### 7.16.6 High — report-card ID collision across academic years

**Evidence:** `lib/services/auth_service.dart:2314-2318` builds `rep_<scholar>_<term>`; the method stores `academicYear` in the document at `2329-2330` but writes it to `.doc(cardId)` at `2352`. The year is not part of the ID and no query shown filters on it.

**Impact:** a Term 1 card published in 2026-27 and again in 2027-28 overwrites the earlier document. Historical report cards are silently destroyed, and any honours claim that reads the ID may read the wrong year.

**Fix:** include a normalized academic year in the ID, e.g. `rep_<scholar>_<year>_<term>`, and migrate/read with an explicit year filter. Add a regression test that publishes the same term in two years and asserts two documents.

#### 7.16.7 High — conduct points commit before the audit record

**Evidence:** `lib/services/auth_service.dart:5441-5497` runs the house/contributor transaction and commits it; `5500` updates the local cache; `5503-5512` separately adds `student_conduct`. The second write is outside the transaction and has no compensating rollback.

**Impact:** a network drop or rules rejection after the transaction leaves the house and student totals changed with no reason record. The conduct log and the points ledger disagree; reversal requires manual database work. The same pattern applies to demerits and to the user-document update that follows.

**Fix:** include a pre-generated `student_conduct` document reference in the same transaction/batch, or add an idempotent outbox with reconciliation. Never update the local cache before the authoritative write succeeds.

#### 7.16.8 High — silent `Grade 10` and `ruby` defaults

**Evidence**

- `'Grade 10'` appears 19 times in `lib/services/auth_service.dart`, including `724`, `2139`, `2176`, `2308-2310`, and the `grade = 10` initialization at `4529` in `ensureSchoolMemberRecord`.
- `'ruby'` defaults appear at `1505`, `2172`, `3925`, `4354`, `4504-4510`, and elsewhere.

**Impact:** a student whose profile lacks `class_level` can be served Grade 10 timetables, report cards, exam schedules, and eligibility checks; a missing house can silently credit Ruby. These are wrong-data bugs, not cosmetic fallbacks, because the defaults are used in academic and points paths.

**Fix:** fail closed on missing class/house; show a profile-completion prompt; derive the authoritative class/house from the school roster server-side; add tests for missing fields.

#### 7.16.9 Medium and low confirmations

| Finding | Evidence | Assessment |
|---|---|---|
| Zero-point orders labeled `PAID (BHD)` | `merch_store_tab.dart:2220-2223` creates `totalPts: 0`; `1112-1114` and `1390-1392` render `PAID (BHD)` / `Verified Store Order` | Confirmed. Label zero-cost orders `FREE`/`0 Pts`; no BHD payment exists. |
| Sample events are relative-dated | `auth_service.dart:2762-2845`; first event `isLive: true`; `events_screen.dart:56-75,124,1607-1620` | Partially confirmed. They do **not** appear automatically on every launch. In live mode they seed only via the explicit “Load Sample Events” action; in offline mode the refresh action seeds them. Remove the live flag and label them samples. |
| Library is local-only | `home_screen.dart:263-330` (3 books, SharedPreferences `asb_library_loans_cache`, Firestore `library_loans`); no `schoolLibrary` call site | Confirmed fake feature, but the claim “resets on restart” is wrong: loans persist locally and sync when live. Due days also do not count down; “Renew” adds 14. |
| Gemini `class` keyword is too broad | `gemini_ai_service.dart:405` | Confirmed. Any prompt containing “class” returns the timetable fallback. |
| No `cloud_functions` SDK | `pubspec.yaml`; raw call sites `auth_service.dart:3401-3412`, `school_elections_page.dart:459` | Confirmed gap. But the raw callable **does** send `Authorization: Bearer <ID token>`, so “no request authentication” is inaccurate. The missing pieces are App Check, SDK retries, region handling, and callable envelope/error parsing. `schoolLibrary` is never called. |
| Spirit delta lost on kill | `house_arena_screen.dart:356-389`; `dispose()` at `299-307` | Confirmed. The write is also fire-and-forget with `catchError`, so even flushed taps can be lost if the process dies before completion. |
| Default house `ruby` | `auth_service.dart:1505,2172,3925,4354,4504-4510` | Confirmed. Scope is broader than the three cited lines. |
| Monolithic service | `auth_service.dart` 9,843 lines / 348,433 bytes | Confirmed. The external report’s “67+ Dart files” understates the tree: 84 Dart files, 84,843 lines in `lib/`. |

---

## 8. Feature-by-feature operational notes

### 8.1 What works best today

1. **Campus events** — lifecycle, drafts, house/grade targeting, RSVP ownership, and rules are coherent.
2. **Academic timetable and attendance** — rich UI, models, teacher editor, approval workflow, and client-side conflict preflight.
3. **Notices and circulars** — admin composer, feed, and a truthful small-PDF fallback.
4. **Claims with human review** — pending queue, approve/reject, points, gallery, and a certificate preview path.
5. **Class/house groups** — membership derived from class/house in rules, with moderation.
6. **Store catalogue/cart/orders** — complete UX, vouchers, and staff claim path, minus payment.
7. **Leaderboard and contributions** — real Firestore points and contributor data.
8. **Admin console breadth** — academics and claims admin tools cover a lot of ground.

### 8.2 What should be labeled demo until fixed

- Apple/Google Wallet and NFC.
- Fee receipt `PAID` status.
- Store payment/checkout.
- Library portal.
- Elections while the callable is undeployed.
- AI certificate verification.
- Arena spirit/quiz/oracle.
- “Encrypted” chat.

### 8.3 What is missing entirely

- Payment gateway and reconciliation.
- FCM/device push (and token lifecycle).
- Native wallet pass signing.
- E2E encrypted chat.
- Server-authoritative gamification and sports.
- Server-side timetable conflict enforcement.
- Server-side promotion/transfer transaction.
- Managed backups/PITR, crash reporting, analytics, and operations dashboards.
- App Check client integration.
- Per-admin identities/MFA.
- Localization usage.

---

## 9. Documentation discrepancies

The repository contains several documents that describe intended or partially completed states as current reality. These should be corrected so operators do not make decisions on stale claims.

| Document | Claim | Observed |
|---|---|---|
| `election_audit/BLAZE_REQUIRED_FEATURES.md` | Release builds “fail closed” without secrets; hashing/vault throw `StateError` | Code has compiled fallback secrets in the vault, election, gamification, sports, and voucher services |
| Same | D2 step 6: “Confirm direct Firestore client writes to `election_polls_v2` are denied by rules” | Poll document is admin-only, but nested `counts` is writable by any signed-in user and `participation` is creatable by any signed-in user |
| Same | “The app runs elections in demo/offline mode today” | Offline demo works, but with Firebase live the student fallback transaction fails under rules; live elections are blocked |
| Same | Gemini candidate model includes `gemini-3.8-flash` | Code lists `gemini-2.0-flash`, `gemini-1.5-flash`, `gemini-1.5-pro` |
| Same | Storage “may require Blaze” | Current Cloud Storage for Firebase provisioning requires Blaze; the project has no bucket |
| Same | `schoolLibrary` is a live backend feature | No client call site; UI uses hard-coded books and local cache |
| `INFRASTRUCTURE_AND_PRICING_GUIDE.md` | Firebase backend “100% free forever (Spark)” | Functions and Storage require Blaze; Vision requires billing |
| `INFRASTRUCTURE_AND_PRICING_GUIDE.md` | Gemini annual cost estimate | Direct API key can use the free tier; a server proxy/managed key changes the cost model |
| `PRODUCT_OVERVIEW.md` / `APP_STRUCTURE_AND_REALITY_REVIEW.md` | Feature descriptions may imply live integrations | Verify each against §5/§7.15; wallet, library, payment, push, AI verification, and elections are not live as designed |
| `development_plan/ACCEPTANCE_MATRIX.md` | 64/64 PASS for claims spec §11 | The claims spec acceptance tests pass, but the matrix does not cover the cross-cutting rules/security defects in this report |
| `gamification_audit` / `academics_audit` | “Interim no-Blaze hardening complete” | Several hardenings are present (bounds, truthful failures), but compiled fallback secrets and direct-write risks remain |

---

## 10. Prioritized recommendations

### P0 — before any pilot with real accounts or real data

1. **Hotfix `school_members`.** Make writes admin/server-only. Remove `school_members.role` from `isSuperAdmin()` until a server-managed roster is authoritative. Add field validation if any self-service fields remain. Migrate role/capability assignment to a callable with an audit trail.
2. **Lock election internals.** Set `election_polls_v2/{pollId}/counts/{candidateId}` and `participation/{key}` writes to `false`; only Admin SDK writes. Deploy the callable or hide/disable live elections. Remove the live fallback; keep a clearly labeled local demo only.
3. **Fix chat reads.** Require channel membership for `chats` and `messages`; add rules tests. Remove the “Encrypted” label unless real E2E encryption is implemented.
4. **Restrict `users` reads.** Require authentication; split a minimal directory collection for legitimate lookups; stop exposing full profiles to unauthenticated clients.
5. **Stop self-asserted identity.** Pre-provision accounts or require an invite/roster code; verify scholar number, name, house, grade, and class server-side; make them immutable after verification.
6. **Remove/rotate client secrets.** Move election, gamification, sports, voucher, and credential-vault trust to the server; remove compiled fallbacks; fail closed in release; rotate anything that has shipped.
7. **Review the uncommitted admin re-auth.** Do not ship automatic admin re-authentication on shared devices; use per-admin accounts and explicit re-auth/MFA.
8. **Fix Storage role rules before initialization.** Owner-scope claim uploads; staff-scope exam/circular uploads; add retention/abuse controls.
9. **Fix notification creation.** Server-side fan-out or restrict creates; prevent spoofed urgent notices.
10. **Remove bootstrap identities on both sides.** Delete the client `admin`/`11209` literals and the rules trust of `admin@asianschool.bh` / `11209@asianschool.bh`; use server-set custom claims or a protected roster; reserve/block bootstrap signup and rotate credentials. This is a second, independent escalation path on top of §7.1.
11. **Delete the unauthenticated REST fallback and gate account switching.** Remove `checkScholarExists()`’s REST block, restrict `users` reads, and make `switchAccount()` swap caches only after a successful live `signIn`. Require a device credential for switching on shared devices.
12. **Fix low-friction integrity bugs before pilot data exists.** Use one attendance formula and return “No data” for empty; include academic year in report-card IDs; make conduct points and the audit log atomic; fail closed instead of defaulting to `Grade 10`/`ruby`.
13. **Remove the fabricated fee receipt and `PAID (BHD)` labels.** Show a sample label or an explicit `UNPAID`/`PENDING` state until a real payment record exists; label zero-cost orders `FREE`/`0 Pts`.

### P1 — go-live readiness

10. **Upgrade to Blaze** with budget alerts; enable Cloud Build, Artifact Registry, Functions, Storage, and Vision.
11. **Initialize Storage** and deploy `storage.rules`; test small and large certificate/circular files.
12. **Deploy the three authored functions**; verify auth errors (not 404), run the live election smoke test after P0.
13. **Add App Check** to mobile/web and decide the Windows posture.
14. **Implement or remove** `schoolGamification`, sports certification, `schoolWallet`, server notification fan-out, promotion/transfer callable, and server timetable conflict validation. Do not present these as live until implemented.
15. **Payment decision:** integrate a PSP or make checkout explicitly “pay at the counter”; remove simulated `PAID` states; make fee receipts data-driven.
16. **Push decision:** FCM is free; add `firebase_messaging` and token management, with a trusted sender. Sending via Functions needs Blaze.
17. **Operations:** backups/PITR, monitoring, crash reporting, analytics, audit review, and incident response.
18. **Test:** Firestore rules unit tests in CI, emulator integration tests, live smoke tests, load tests, and a privacy/security review.

### P2 — quality and maintainability

19. Split `auth_service.dart`, `academics_screen.dart`, `home_screen.dart`, `school_elections_page.dart`, and `merch_store_tab.dart` into domain modules.
20. Introduce a state-management and routing strategy; remove global mutable stores where possible.
21. Use the `cloud_functions` SDK instead of raw HTTP callables; centralize retries, errors, and App Check tokens.
22. Localize the UI or remove the unused l10n scaffold.
23. Improve accessibility (semantics, focus order, contrast, dynamic type).
24. Update documentation to distinguish live, partial, demo, and blocked features.
25. Add device/browser coverage for Windows, Android, iOS, and web; document platform differences.

---

## 11. Go-live checklist

Use this as a hard gate, not a feature wish list.

### Security and data integrity

- [ ] `school_members` write is admin/server-only; self-write escalation test fails.
- [ ] `isSuperAdmin()` no longer trusts member-writable data.
- [ ] Election `counts` and `participation` direct writes are denied.
- [ ] Chat reads require membership; privacy test passes.
- [ ] `users` reads are authenticated/limited; unauthenticated enumeration fails.
- [ ] Identity/house/grade/class are server-verified and immutable after verification.
- [ ] No client-side trust secrets; release build has no fallback secrets.
- [ ] No `admin`/`11209` literals in the client or rules; bootstrap emails cannot self-register. **Accepted exception:** the project keeps the `11209`/`admin` bootstrap identity; self-registration is blocked and sign-in still requires the Firebase password (see §12.1).
- [ ] `checkScholarExists()` has no unauthenticated REST path; anonymous scholar enumeration fails.
- [ ] Account switching requires successful re-authentication; wrong-password switch fails.
- [ ] Attendance uses one formula; empty attendance is not reported as 100%.
- [ ] Report-card IDs include the academic year; two-year regression test passes.
- [ ] Conduct points and `student_conduct` are atomic; failure leaves neither.
- [ ] Missing class/house fails closed; no silent `Grade 10`/`ruby` data.
- [ ] Storage rules are role/owner-scoped.
- [ ] Notification creation is server-controlled.
- [ ] Voucher signatures are mandatory and legacy unsigned payloads are rejected.
- [ ] Admin accounts are individual, MFA-protected, and audited; auto-reauth removed.
- [ ] Rules unit tests run in CI and pass.

### Firebase / Blaze

- [ ] Project upgraded to Blaze with budget alerts.
- [ ] Cloud Build, Artifact Registry, Functions, Storage, Vision APIs enabled.
- [ ] Storage bucket initialized; `storage.rules` deployed.
- [ ] `schoolElection`, `schoolLibrary`, `verifyCertificateSignature` deployed.
- [ ] `schoolElection` returns an auth error, not 404.
- [ ] Certificate image creates a Storage object and AI fields.
- [ ] >700 KB circular PDF uploads successfully; >15 MB rejected.
- [ ] App Check configured for mobile/web.
- [ ] Backups/PITR and monitoring enabled.

### Product truthfulness

- [ ] Payment gateway integrated, or checkout says “pay at counter” and no `PAID` claim is shown.
- [ ] Fee receipt is data-driven, not a fixed `BHD 150.000`, or is removed/labeled “SAMPLE — NOT A RECEIPT.”
- [ ] Zero-point orders show `FREE`/`0 Pts`, not `PAID (BHD)`.
- [ ] Apple/Google Wallet buttons create real passes, or are labeled “PDF pass only.”
- [ ] NFC label removed or real NFC implemented.
- [ ] Library is connected to `schoolLibrary`, or labeled “sample catalogue.”
- [ ] Elections are live and certified, or labeled “demo.”
- [ ] AI certificate fields are populated, or the UI says “human review.”
- [ ] Chat is not labeled encrypted unless E2E is real.
- [ ] Push notifications work in background, or the UI says “in-app only.”

### Quality / operations

- [ ] `flutter analyze` clean.
- [ ] Full test suite green.
- [ ] Rules/emulator tests green.
- [ ] Live election/claims/events smoke tests green.
- [ ] Load test at school-scale concurrency.
- [ ] Accessibility and localization review.
- [ ] Crash reporting/analytics enabled.
- [ ] Documentation updated to match reality.
- [ ] Rollback/incident plan documented.

---

## 12. Remediation status (25 November 2026)

This section records the remediation batch applied after the audit. It covers the local working tree only: no rules, Storage rules, functions, or client build described here has been deployed or smoke-tested against the live project. The go-live checklist above remains the deployment gate.

### 12.1 Accepted project decision

The `11209` / `admin` bootstrap identity is retained by explicit project decision. It remains a hardcoded client route and a rules-level bootstrap account, and signing in with it still requires the real Firebase password. Only self-registration of the reserved identifier is blocked, both in the signup screen and inside `AuthService.signUp`. This is an accepted exception, not an oversight.

### 12.2 Fixed in the working tree

**Security and rules**

- `users` reads require authentication, and owner self-updates can no longer change `role`, `points`, `points_contributed`, `scholar_no`, `created_at`, `uid`, `class_id`, `class_verified`, `status`, `house_name`, `grade`, `class_level`, `division`, or `full_name`.
- Chat room/message reads are participant-only. `school_members` self-provisioning is limited to student rows whose scholar number, house, and grade mirror the immutable `users` profile, and house/grade cannot change after creation. Direct client writes to election `counts` and `participation` are denied.
- `storage.rules` restrict exam-schedule and circular writes to staff/admin roles through a `firestore.get` role lookup.
- Signup rejects the reserved `11209` / `admin` identifier both in the signup screen and inside `AuthService.signUp`.
- Login failures no longer distinguish a missing account from a wrong password in the scholar flow; the login screen shows one generic “Incorrect scholar number or password.” message, and the unauthenticated Firestore REST enumeration fallback in `checkScholarExists()` is removed.
- `switchAccount()` requires a successful live Firebase re-authentication when Firebase is live and aborts the switch on failure or a missing password. Offline/no-Firebase mode still swaps the local cache for tests and first-run recovery.
- Voucher QR validation requires an HMAC signature. Unsigned legacy `ASB-ORDER-*` payloads are rejected.

**Data integrity**

- Election `vote` / `receipt` fallbacks fail closed when Firebase is live, and the election page states that voting is server-verified. Live voting is intentionally unavailable until the `schoolElection` callable is deployed.
- Attendance uses one policy everywhere: `present + excused + 0.5 * late`. Empty attendance renders as “No attendance data” / “No data” instead of 100%.
- Report-card IDs include the academic year (`rep_<scholar>_<year>_<term>`). Legacy IDs remain readable because reads query by scholar/term fields, and the cache dedupes the same scholar/term/year.
- The `student_conduct` audit row is written inside the same transaction as house and contributor points, so a failure leaves neither.
- Missing class, house, or scholar fails closed in report-card, conduct, claim, roster, timetable, assignment, and attendance write paths instead of defaulting to `Grade 10` or `ruby`. Students without a verified house/grade are not given invented `school_members` rows, and assignment points are only awarded to a verified target scholar.
- The spirit reactor flushes its pending delta every fifth tap and from `dispose()`.

**UI truthfulness**

- Chat says “Private”, not “Encrypted”.
- The fee receipt is labeled `SAMPLE — NOT PAID` with no fixed BHD amount.
- BHD merchandise orders are labeled payment-unverified instead of `PAID (BHD)`, and the store no longer claims “verified” merchandise or direct Digital Wallet fulfilment.
- Apple/Google Wallet and NFC claims are replaced with a local pass preview, an “ASB Digital Passes” title, and PDF export wording.
- The library portal is labeled as sample data, and renewal is labeled simulated.
- Seeded campus events are not marked live.
- The push toggle is replaced by an in-app-only notification notice.
- The global `ErrorWidget` no longer prints exception text to the user.

### 12.3 Local verification

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | No issues found |
| `flutter test --reporter compact` | 684/684 passed |
| Firestore rules compile check | Temporary demo emulator started and loaded the rules without a syntax error |
| Rules/storage behavioral emulator tests | Not run; rules not deployed |

### 12.4 Residual and deployment-dependent work

- Run the rules emulator suite, then deploy `firestore.rules` and `storage.rules`; initialize the Storage bucket.
- Deploy `schoolElection`, `schoolLibrary`, and `verifyCertificateSignature`. All three return 404 today. Live election voting is deliberately blocked until `schoolElection` is deployed and verified.
- Add a real payment provider or an explicit pay-at-counter flow; the current store and fee surfaces are now labeled but still simulated.
- Configure FCM delivery for background push, or keep the in-app-only wording. Configure App Check, backups/PITR, monitoring, and budget alerts on Blaze.
- Move roster authority, role assignment, and notification creation to server-side code or custom claims. Add individual audited MFA-protected admin accounts; the shared bootstrap admin remains an accepted risk.
- Remove compiled client-side HMAC/vault secrets. Mandatory signatures reject unsigned legacy vouchers and casual tampering, but a determined binary extractor can still mint tokens.
- Add rules tests to CI, plus live smoke tests for elections, claims, events, and uploads.

---

## Appendix A — Screen inventory (28)

| Screen | Purpose | Status |
|---|---|---|
| `onboarding_screen.dart` | First-run introduction; marks onboarding complete | LIVE |
| `login_screen.dart` | Scholar/admin login, saved accounts | LIVE |
| `signup_screen.dart` | Student self-registration, house/class selection | LIVE with identity caveat |
| `home_screen.dart` | Dashboard, 4 tabs, drawer, service cards, notices, library modal | LIVE |
| `academics_screen.dart` | Timetable, homework, exams, reports, attendance, leave, circulars | LIVE/PARTIAL |
| `teacher_timetable_editor_screen.dart` | Teacher timetable editing and conflict preflight | LIVE |
| `admin_academics_screen.dart` | Classes, rosters, promotion, approvals, audit | LIVE |
| `admin_claims_screen.dart` | Pending claims, medical leaves, roster/role tools | LIVE/PARTIAL |
| `approved_claims_screen.dart` | Approved claim gallery | LIVE |
| `events_screen.dart` | Campus event lifecycle and RSVPs | LIVE |
| `notification_center_screen.dart` | In-app notification list | LIVE in-app |
| `chat_list_screen.dart` | Chat channel list | LIVE |
| `chat_room_screen.dart` | Chat messages, “Encrypted” label | LIVE, privacy defect |
| `class_group_screen.dart` | Class group chat | LIVE |
| `house_group_screen.dart` | House group chat | LIVE |
| `house_leaderboard_screen.dart` | House standings and contributors | LIVE |
| `house_arena_screen.dart` | Spirit gauge, quiz, oracle, badges | LIVE + DEMO |
| `sports_tournament_screen.dart` | Fixtures, brackets, trophies | LIVE, client-trusted |
| `live_match_hud_screen.dart` | Live scoring, timer, MVP/stats | LIVE, client-trusted |
| `school_elections_page.dart` | Elections v2 UI and fallback | BLOCKED |
| `election_chamber_screen.dart` | Legacy election/ballot UI | PARTIAL/BLOCKED |
| `election_audit_screen.dart` | Receipt/audit verification | PARTIAL |
| `election_gazette_screen.dart` | Certified results gazette | BLOCKED until certification |
| `merch_store_tab.dart` | Store, cart, orders, pass display | PARTIAL; payment ABSENT |
| `digital_wallet_screen.dart` | Store passes, campus ID, fee receipt | LOCAL/DEMO for native wallet |
| `id_scanner_screen.dart` | QR/student/voucher scanner | LIVE, client-trusted |
| `student_behavior_evaluation_screen.dart` | Merit/demerit entry | LIVE |
| `house_ai_chat_screen.dart` | Gemini assistant | PARTIAL/optional |

## Appendix B — Service inventory (14)

| Service | Lines / role | Notes |
|---|---|---|
| `auth_service.dart` | Core auth, profiles, claims, notices, academics, points, elections, sports, storage, caches | 9,843 lines; god object; uncommitted admin reauth diff |
| `chat_service.dart` | DM/group creation, messages, unread, notification docs | Client restricts DMs; rules do not |
| `class_group_service.dart` | Class group metadata/messages | Membership via class registry |
| `house_group_service.dart` | House group metadata/messages | Membership via `users.house_name` |
| `notification_service.dart` | Firestore fan-out, dedupe, categories | No FCM |
| `election_security_service.dart` | Receipt/audit HMAC | Client salt/fallback |
| `gamification_security_service.dart` | Score proof tokens, cooldowns, nonce store | Client secret/fallback; local nonce store |
| `sports_security_service.dart` | Sports certification HMAC | Client salt/fallback |
| `voucher_security_service.dart` | Voucher/student pass HMAC, claim status | Legacy unsigned acceptance |
| `gemini_ai_service.dart` | Gemini REST, model fallback, local heuristics | User key in SharedPreferences |
| `hierarchy_service.dart` | Role/scholar/email policy | Hard-coded IDs; client policy |
| `timetable_service.dart` | Timetable CRUD, double-booking preflight | Client-side validation |
| `pass_document_exporter.dart` | Pure-Dart PDF pass/receipt export | Text-only QR; synthetic web success |
| `qr_decoder_service.dart` | QR/image decoding | Scanner support |

## Appendix C — Firestore collections observed

`users`, `users/{uid}/notifications`, `admin_roster`, `school_members`, `classes`, `academic_classes`, `class_timetable`, `homework`, `exam_schedules`, `report_cards`, `attendance`, `medical_leaves`, `student_conduct`, `house_claims`, `orders`, `house_points`, `house_contributors`, `sports_fixtures`, `fixtures`, `sports_fixtures/{id}/events`, `sports_trophies`, `elections`, `elections/{id}/ballots`, `election_votes`, `election_gazettes`, `election_polls_v2`, `election_polls_v2/{id}/counts`, `election_polls_v2/{id}/participation`, `election_polls_v2/{id}/audit`, `election_drafts_v2`, `notices`, `announcements`, `events`, `events/{id}/registrations`, `event_wall`, `house_groups`, `house_groups/{id}/messages`, `class_groups`, `class_groups/{id}/messages`, `chats`, `chats/{id}/messages`, `system_config`, `library_loans` (client path, no rules), `library_loans_v2` / `library_copies_v2` (callable-only paths), and the legacy claims path.

## Appendix D — Models and widgets

**Models (21):** `academic_assignment`, `academic_class`, `academic_report_card`, `app_notification`, `attendance_record`, `campus_event`, `class_group`, `class_timetable`, `digital_ballot_cast`, `election_audit_record`, `election_ballot`, `election_gazette`, `exam_schedule_item`, `house_group`, `match_telemetry`, `medical_leave_request`, `player_sports_stats`, `school_notice`, `sports_tournament`, `sports_trophy`, `timetable_period`.

**Widgets (15):** `academic_image`, `account_switcher_modal`, `apple_fitness_badge`, `apple_fitness_badges_vault`, `battle_chant_synthesizer`, `camera_capture_dialog`, `confetti_overlay`, `gamification_cooldown_banner`, `house_card`, `managed_modal_scope`, `mascot_3d_stage`, `pill_selector`, `school_circular_composer`, `strength_meter`, `student_profile_modal`.

## Appendix E — Dependencies and platform notes

- Flutter SDK constraint `^3.11.5`; app version `1.0.1+2`.
- Firebase: core `^4.11.0`, auth `^6.5.4`, Firestore `^6.6.0`, Storage `^13.4.3`.
- Media/scanning: `image_picker`, `camera`, `camera_windows`, `mobile_scanner`, `zxing2`, `qr_flutter`, `image`, `cached_network_image`.
- Platform/storage: `shared_preferences`, `file_selector`, `url_launcher`.
- Crypto/network: `crypto`, `http`.
- `flutter_localizations` + `intl` are present, but no UI uses the generated localizations.
- No `cloud_functions`, `firebase_messaging`, `firebase_app_check`, `firebase_analytics`, `firebase_crashlytics`, `firebase_performance`, payment SDK, or printing/PDF package.
- Windows Firestore uses an in-memory cache; mobile/web use platform defaults.
- Assets: `assets/images/`, `assets/images/mascots/`; Material icons enabled.

## Appendix F — Audit command log

```powershell
# Static analysis
flutter analyze --no-pub

# Full test suite
flutter test --reporter compact

# Repository state
git rev-parse --short HEAD
git status --short
git diff -- lib/services/auth_service.dart

# Codebase size
# - 84 Dart files, 84,843 lines in lib/
# - 28 screens, 14 services, 21 models, 15 widgets
# - 20 test files, 21,793 lines

# Source review
# - lib/main.dart
# - lib/services/*.dart
# - lib/screens/*.dart (entry points and key workflows)
# - firestore.rules, storage.rules
# - functions/index.js, functions/elections-v2.js, functions/library-v2.js
# - pubspec.yaml, firebase.json, .firebaserc, lib/firebase_options.dart

# Live probes
# POST https://us-central1-asb-house-hub.cloudfunctions.net/schoolElection  -> 404
# POST https://us-central1-asb-house-hub.cloudfunctions.net/schoolLibrary   -> 404
# GET  https://firebasestorage.googleapis.com/v0/b/asb-house-hub.firebasestorage.app/o -> 404
```

---

## Appendix G - Verification of the 21-Finding Fault Report

**Input:** external “Full Faults & Vulnerabilities Report” dated 24 November 2026, with 21 findings (5 Critical, 7 High, 5 Medium, 4 Low).  
**Method:** every cited file and line was re-read on 25 November 2026, together with the relevant call sites, models, and `firestore.rules`. No exploit was executed and no live Firebase state was changed. The baseline in §2.3 still applies.  
**Result:** **17 findings confirmed, 4 confirmed with material corrections, 0 wholly false.** One High was downgraded to Medium. The report’s counts become **5 Critical, 6 High, 6 Medium, 4 Low** after correction. Its most important omission is the rules-level escalation paths in §7.1–§7.3, which are more severe than its own top finding.

### G.1 Per-finding verdicts

| ID | Verdict | Reported → assessed | Evidence and corrections |
|---|---|---|---|
| CRIT-01 | Confirmed | Critical → Critical | `auth_service.dart:4520-4522`; `hierarchy_service.dart:13-17`; `firestore.rules:265-276,1207-1215`. The cited client literals are real. The mechanism is broader: rules trust the exact bootstrap emails, and `signUp()` creates the Auth user at `4415-4421` before the `users` validator rejects `scholar_no` 11209 at rules `507-508`, so a rejected profile is not a barrier. The separate `school_members` self-write path (§7.1) grants the same power without any special number. Fix both. |
| CRIT-02 | Confirmed | Critical → Critical | `auth_service.dart:43-146`. It is **not a plain XOR cipher**: it is a home-grown HMAC-SHA256 keystream (CTR-like) with an HMAC-SHA256 tag. That is still custom crypto with a compiled fallback secret, and `decrypt()` accepts legacy plaintext at `100-104`. Passwords are saved in `SharedPreferences` (`3707-3749`). The secret value is intentionally not reproduced. Use platform secure storage or stop storing passwords. |
| CRIT-03 | Confirmed with conditions | Critical → Critical | `auth_service.dart:3970-4003` sends no `Authorization` header; `firestore.rules:1203-1205` allows public `users` reads. On the committed rules, anonymous enumeration is possible through the public read even without this fallback. Removing only the REST block is insufficient; restrict `users` reads and move existence checks server-side. Whether Google additionally requires an API key for this endpoint should be tested in the deployed project. |
| CRIT-04 | Confirmed | Critical → Critical on shared devices / High otherwise | `auth_service.dart:3877-3937`. It is not a race: Step 2 is **unconditionally** executed after a caught failure, timeout, or omitted password. The local cache swap is real. It is not a server-side auth bypass, but on a shared device it exposes cached grades, attendance, and profile data under the target identity. Gate the swap on successful re-auth. |
| CRIT-05 | Confirmed | Critical → Critical (product/legal) | `digital_wallet_screen.dart:771-789`. Fixed receipt number, `PAID IN FULL`, `BHD 150.000`, and a QR payload are rendered for every student. No payment record is consulted. Remove, or label unmistakably as a sample; issue receipts only from reconciled server data. |
| HIGH-01 | Confirmed | High → High | `home_screen.dart:6330-6343` uses `(present + excused + late×0.5)/total`; `gemini_ai_service.dart:421-430` uses `present/total`; `attendance_record.dart:182-183,222-228` also uses `present/total` and feeds `academics_screen.dart:6420`. The report’s arithmetic is wrong: 80 present + 10 late + 10 excused gives **95%** at home, not 90%, versus **80%** in Gemini/academics. That is a 15-point gap, not 10. |
| HIGH-02 | Confirmed | High → High | `attendance_record.dart:182-183` returns `100.0` when `totalDays == 0`; `home_screen.dart:6340-6343` falls back to `attendance_rate` and then `100.0%`. The defect exists in both the model and the home screen. Return `null`/“No attendance data.” |
| HIGH-03 | Confirmed | High → High | `auth_service.dart:2314-2318` builds `rep_<scholar>_<term>`; `academicYear` is stored at `2329-2330` but is not in the ID, and the write is `.doc(cardId)` at `2352`. A later year overwrites the earlier card. Add the year to the ID and filter reads by year. |
| HIGH-04 | Confirmed | High → High | `auth_service.dart:5441-5497` commits the house/contributor transaction; `5500` updates the local cache; `5503-5512` adds the `student_conduct` log outside the transaction. A failure leaves points changed with no reason record. The following user-document update is also outside the transaction. Use one transaction/batch or an idempotent outbox. |
| HIGH-05 | Partially confirmed | High → Medium | `auth_service.dart:2762-2845` defines six relative-dated events; the first is `isLive: true`. But they are **not** loaded automatically on every launch. `events_screen.dart:56-75,124,1607-1620` seeds them only when the user taps “Load Sample Events” in live mode or the refresh action in offline mode. In live mode they do not mix with real Firestore events. Remove the `isLive` flag and label them samples; do not present fixed venues as official. |
| HIGH-06 | Confirmed and understated | High → High | `'Grade 10'` appears **19 times** in `auth_service.dart`, not 5, including `724`, `2139`, `2176`, `2308-2310`, and the `grade = 10` default at `4529`. Missing-house `ruby` defaults are also broader than cited (`1505,2172,3925,4354,4504-4510`). Fail closed and prompt for profile completion. |
| HIGH-07 | Confirmed | High → High | `firestore.rules:1670-1692`: `chats/{channelId}` and `messages` both `allow read: if isSignedIn()`. The fix should use the existing **`participants`** field (already required on create at `1672-1674`), not a new `members` array. Messages need a parent-channel participant check as well. |
| MED-01 | Confirmed | Medium → Medium | `merch_store_tab.dart:2220-2223` creates every checkout order with `totalPts: 0`; `1112-1114` shows `PAID (BHD)`, and `1390-1392` shows `Verified Store Order`. Use `FREE`/`0 Pts` and a truthful payment state. |
| MED-02 | Confirmed | Medium → Medium | `gemini_ai_service.dart:405` matches the bare substring `class`, so unrelated prompts return the timetable fallback. Narrow the matcher. |
| MED-03 | Confirmed with correction | Medium → Medium | `home_screen.dart:263-330` holds three fixed books; there is no `schoolLibrary` call site. But the report’s “resets on app restart” is **wrong**: loans persist in `SharedPreferences` (`asb_library_loans_cache`) and sync to `library_loans` when live. Due days also do not count down; “Renew” adds 14 days (`6578-6587`). The feature is still fake. |
| MED-04 | Confirmed with correction | Medium → Medium | `pubspec.yaml` has no `cloud_functions`; only `schoolElection` is called, via raw HTTP (`auth_service.dart:3401-3412`; `school_elections_page.dart:459`). But the raw callable **does** send `Authorization: Bearer <ID token>`, so “no request authentication” is inaccurate. What is missing is App Check, SDK retries, region handling, and callable envelope/error parsing. `schoolLibrary` is never called. |
| MED-05 | Confirmed | Medium → Medium | No `firebase_messaging` or device-token path in `pubspec.yaml`. “Notifications” are in-app Firestore documents only. FCM itself is free; sending from Functions needs Blaze. |
| LOW-01 | Confirmed | Low → Low | `auth_service.dart` is 9,843 lines / 348,433 bytes. The report’s “67+ Dart files” understates the tree: **84 Dart files, 84,843 lines** in `lib/`, plus 20 test files / 21,793 lines. |
| LOW-02 | Partially confirmed | Low → Low / Info | The Firebase API key is public by design; security depends on rules and API restrictions. The Gemini key is user-supplied, stored in `SharedPreferences`, and sent as a URL query parameter (`gemini_ai_service.dart:10,38-49,66-67,285,312-313`). HTTPS protects transport, so “vulnerable to network interception” is overstated; the real risks are at-rest storage, URL leakage in logs/proxies, and key abuse. Use secure storage or a server proxy and restrict the key. |
| LOW-03 | Confirmed | Low → Low | `house_arena_screen.dart:356-389` flushes every fifth tap; `dispose()` at `299-307` does not flush. The write is also fire-and-forget with `catchError`, so even a flushed delta can be lost if the process dies before completion. The 60-point worst case is plausible. |
| LOW-04 | Confirmed and understated | Low → Low | Defaults to `ruby` at `auth_service.dart:1505,2172,3925,4354,4504-4510`, plus `inferHouseFromScholarNo` fallback at `433-435`. Scope is broader than the three cited lines. Fail closed for points-bearing operations. |

### G.2 Factual corrections to the external report

1. **File count:** 84 Dart files and 84,843 lines in `lib/`, not “67+”. The test suite is 20 files / 21,793 lines.
2. **CRIT-02 cipher description:** it is a custom HMAC-SHA256 keystream plus HMAC tag, not a plain XOR cipher. It is still unsafe because the key ships in the binary and legacy plaintext is accepted.
3. **HIGH-01 example:** the home formula yields **95%**, not 90%; Gemini/academics yield **80%**. There are three formulas, not two.
4. **HIGH-02 scope:** the 100% empty default exists in both the home screen and `AttendanceSummary`, not only one screen.
5. **HIGH-05 automatic launch:** the sample events are **not** loaded on every app launch. They load through an explicit action; only offline mode wires that action to the refresh button. The first event is indeed `isLive: true`.
6. **MED-03 library reset:** loans persist across restart in `SharedPreferences` and `library_loans`; they do not reset. The feature is still a local mock with static due days.
7. **MED-04 authentication:** raw callable requests do send a Firebase ID token in the `Authorization` header. The gap is the missing SDK/App Check/retry/region/envelope handling, not absent authentication.
8. **HIGH-07 field name:** chat rooms already have a `participants` field; the fix should enforce it on reads. A new `members` array would duplicate the model.
9. **CRIT-01 mechanism:** the `users` validator does reject `scholar_no` 11209, but Auth account creation happens first and rules trust the token email; the `school_members` self-write is a separate and broader escalation. The client literals alone are not the whole story.
10. **LOW-02 interception:** HTTPS mitigates transport interception. The actionable risks are storage at rest, URL query leakage, and unrestricted key use.

### G.3 Important issues the 21-finding report did not cover

These remain the highest-severity items in this audit, even though the external report did not list them:

- **`school_members` self-write → `isSuperAdmin()`** (§7.1). Any signed-in student can write their own membership document and obtain full rules-level admin. This is more severe than CRIT-01 because it needs no special scholar number.
- **Election `counts` and `participation` are client-writable** (§7.2). Vote tallies can be changed directly, so the election result cannot be trusted even after the callable is deployed.
- **The live election fallback cannot work under the rules** (§7.3). The transaction writes admin-only poll/legacy documents and a write-disabled `election_votes` document, so student live voting fails.
- **Self-service house/grade/name changes** (§7.5) affect group access, event eligibility, and election eligibility.
- **Shared bootstrap admin plus automatic re-authentication** (§7.8). Audit logs cannot distinguish administrators, and a stale session can silently regain admin power.
- **Storage rules are authenticated but not role-scoped** (§7.9), allowing any signed-in user to write claim/exam/circular objects once Storage is initialized.
- **Notification spoofing** (§7.10), **unsigned voucher acceptance** (§7.11), and **no payment gateway/wallet/NFC** (§7.11 and §7.15).
- **Broad client-side trust secrets** beyond the credential vault (§7.7): election, gamification, sports, and voucher HMACs all have compiled fallbacks.

### G.4 Assessed severity distribution

| Severity | Count | Findings |
|---|---:|---|
| Critical | 5 | CRIT-01, CRIT-02, CRIT-03, CRIT-04 (shared-device), CRIT-05 |
| High | 6 | HIGH-01, HIGH-02, HIGH-03, HIGH-04, HIGH-06, HIGH-07 |
| Medium | 6 | HIGH-05, MED-01, MED-02, MED-03, MED-04, MED-05 |
| Low | 4 | LOW-01, LOW-02, LOW-03, LOW-04 |
| **Total** | **21** | |

### G.5 Recommended fix order after verification

| Order | Fix | Why |
|---:|---|---|
| 1 | `school_members` server-only; remove `role` from `isSuperAdmin()` | Broader and easier than the `11209` path; any signed-in user can escalate |
| 2 | Remove bootstrap email/literal trust; custom claims; reserve/block bootstrap signup | Closes the second escalation path and makes admin identity rotatable |
| 3 | Lock election `counts`/`participation`; deploy the callable or hide live elections | Election integrity cannot be restored by client fixes |
| 4 | Restrict `users` reads; delete the REST fallback; move existence checks server-side | Stops anonymous scholar enumeration |
| 5 | Gate `switchAccount()` on successful re-auth; encrypt/clear caches | Stops local cross-account data exposure |
| 6 | Enforce `participants` on chat and message reads | Restores messaging privacy; remove “Encrypted” |
| 7 | Replace the credential vault and all client HMAC trust secrets | Stops offline password recovery and token forgery |
| 8 | Remove/label the fee receipt; stop `PAID (BHD)` for zero-cost orders | Removes fabricated financial documents |
| 9 | One attendance formula; “No data” for empty; year in report-card ID; atomic conduct writes; fail closed on missing class/house | Prevents wrong academic records and silent data loss |
| 10 | Connect or label library/events; add `cloud_functions` and FCM only after the trust fixes | Product truthfulness and maintainability |

**Bottom line:** the external report is substantially accurate and useful, but it leads with a narrower backdoor than the one that matters most. The `school_members` self-write and client-writable election tallies remain the top release blockers; the bootstrap `11209`/email path, unauthenticated REST fallback, account-switch cache swap, and fabricated receipt are confirmed additional blockers. None of these should be deferred to the Blaze migration.

---

**End of report.**
