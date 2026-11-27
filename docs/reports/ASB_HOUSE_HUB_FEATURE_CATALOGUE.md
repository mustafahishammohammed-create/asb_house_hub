# ASB House Hub

## Feature Catalogue & Release Readiness Review

**Application features for academics, houses, events, leadership, and administration**

**Prepared for:** The Administration, The Asian School, Bahrain  
**Prepared by:** Mustafa Hisham  
**Application version:** 1.0.1 (Build 2)  
**Date:** 27 November 2026  
**Document status:** Submission for administrative review — not a production release approval

> **Current release position: not cleared for production.** While the Batch 1 local security remediations and commits `2e54a9a..13b791c` resolved suspension enforcement, saved-account cache isolation, notification sender scoping, claim self-approval guards, Storage ownership regexes, chat/trophy schemas, scannable QR PDF export, and Android release signing locally, live Cloud Functions deployment (requiring Firebase Blaze), Storage activation, server-owned scoring/catalog authority, App Check, FCM, and enrollment roster binding remain open. No live school data should be entered.

> **Purpose of this document.** This catalogue documents what each module of ASB House Hub contains, who can use it, its current release status, and the open audit/deployment gates that block production use. It reflects the 27 November 2026 codebase state (including Batch 1 local security remediations); it is not a production approval.

---

## Contents

| Metric | Value |
| --- | ---: |
| Application modules | **16** |
| Purpose-built screens | **28** |
| Automated tests passing | **710** |
| Emulator security tests passing | **28** |

**Status labels:** `GATED` · `PILOT` · `ACTIVATION` · `ROADMAP` · `READY` *(target state; no module is currently assigned)*

1. Executive summary
2. The app at a glance
3. What the app contains
4. How to read the release status
5. Complete feature catalogue
6. Role-based experience
7. Student-facing capabilities
8. Design, accessibility, and platform support
9. Security design and open findings
10. Audit results, quality, and release gates
11. Deployment readiness and phased rollout
12. Proposed pilot and success measures (conditional)
13. Product roadmap
14. Submission pack and approval request
15. Appendix: module summary

---

## 1. Executive summary

ASB House Hub is a Flutter application for academic information, house points, events, communication, recognition, and administration. It contains **16 modules** and **28 screens**, across **84 Dart source files**, with role-based access for students, teachers, captains and council members, and administrators.

Students at The Asian School, Bahrain do not bring mobile phones to school. Student-facing features are provided for use outside school hours on a personal device, subject to school and family policy. Staff features — attendance, scanning, approvals, event management, and academic administration — run on school-authorised devices.

> **Current release position: not cleared for production.** Following the deep code audit of 26 November 2026, substantial local remediations (`2e54a9a..13b791c` plus the Batch 1 security patch) closed key client and rules gaps around suspension enforcement, cache isolation, role parity, notification sender scoping, claim self-approval, bounded store pricing and HMAC-SHA256 voucher binding, Storage ownership, chat creation and photo attachments, trophy schema, scannable vector QR PDF exports, fail-closed release startup, Android signing, and iOS deployment targets. However, **no Cloud Functions are deployed** (the project remains on the Firebase Spark plan without Blaze billing), Cloud Storage is not initialized live, Batch 1 `firestore.rules`, `storage.rules`, and `firestore.indexes.json` are not yet pushed live, and server-side authority (points ledger, sports scoring, election tallies, store catalog, enrollment roster binding, App Check, FCM, and AI proxy) remains open. The build is suitable for code review and synthetic-data demonstration only. No live student, staff, medical, payment, or election data should be entered.

The app is designed around five goals:

- **Role-aware access.** What a user can see and do follows their school role and placement across unified client and Firestore/Storage role definitions.
- **One account per scholar.** Students, teachers, captains, council members, and administrators use a single sign-in with clean cache isolation between sessions.
- **Visible house records.** Points, contributors, standings, badges, and recognition are stored and reviewable.
- **Staff-controlled workflows.** Claims, conduct, elections, events, and approvals follow defined staff permissions and fail closed when suspended or missing data.
- **Truthful status reporting.** Sample data, pilot engagement widgets (such as Spirit Reactor), and services requiring Blaze activation are labelled as such.

Capabilities that depend on school IT and Firebase Blaze services — background push notifications, live Cloud Storage uploads and OCR certificate checks, server-verified elections, the transactional library backend, server-side AI proxy, and any future payment integration — are marked `ACTIVATION`. Modules with remaining server-authority, roster, or deployment blockers are marked `GATED` and are not approved for live use.

Verification completed after the final Batch 1 code and rules edits: **710 of 710 automated Flutter tests passing** across 22 test files, a clean `flutter analyze --no-pub` run, **28 of 28 Firestore and Storage Emulator tests passing**, and **3 Cloud Functions JS syntax checks** passing. (Release builds for Android APK, Windows, and Web were previously verified at commit `13b791c`, prior to Batch 1 rules/service edits.) Live Cloud Function deployment, live Blaze Storage activation, iOS macOS/Xcode archiving, physical mobile device testing on the latest patch, accessibility certification, and deployed integration tests remain incomplete.

> **Recommended next step:** approve a closed, synthetic-data technical review and complete the remaining backend deployment gates (`G1`–`G3`) once Firebase Blaze provisioning and school IT sponsorship are confirmed. Do not approve a live pilot until updated `firestore.rules`, `storage.rules`, indexes, Cloud Functions, App Check, and server-owned authority are deployed and verified.

---

## 2. The app at a glance

| Item | Detail |
| --- | --- |
| **Product name** | ASB House Hub |
| **Purpose** | Academic information, house points, events, communication, recognition, and administration |
| **Primary users** | Students, teachers and faculty, house captains and council, school administrators |
| **Student access** | Outside school hours on a personal device, subject to school and family policy |
| **Staff access** | School-authorised devices |
| **Platforms** | Android, iOS, Windows, web targets |
| **Technology** | Flutter front end; Firebase Authentication, Cloud Firestore, and Cloud Storage |
| **Modules** | 16 |
| **Screens** | 28 |
| **Capabilities** | 100+ user-facing features |
| **Visual identity** | Four house colours, light and dark themes, school branding, responsive layouts |
| **Current release position** | **Not cleared for production** — Batch 1 & `2e54a9a..13b791c` local fixes verified; Spark/Blaze backend deployment, server authority (`G2`/`G3`), and accepted bootstrap governance (`O01`) remain open |
| **Deployment state** | Rules updated locally (prior `firestore.rules` pushed at `13b791c`, Batch 1 `firestore.rules`/`storage.rules`/`firestore.indexes.json` pending deploy); no Cloud Functions or Storage bucket active live (Spark plan) |
| **Quality evidence** | 710/710 Flutter tests passing; 28/28 Firestore + Storage Emulator tests passing; static analysis clean; 3 backend JS checks clean; GitHub Actions CI configured |
| **Release** | Version 1.0.1, Build 2 — November 2026 |

### Core design principles

The app is designed around these principles. Sections 9 and 10 record both the controls enforced locally and where server-side authority still remains to be deployed.

1. **Student-first clarity.** Important information is reachable in a few taps, with plain-language labels and clear empty states.
2. **Role-aware by design.** What a user can see and do follows their school role and verified placement.
3. **Truthful interfaces.** The app does not label a sample, preview, interactive toy, or unverified request as live, official, or paid.
4. **Fail closed on missing data or errors.** Release startup fails closed on Firebase initialization error (`O36`), live voucher claims reject unverified orders (`O22`), and missing class/house/scholar data stops privileged writes.
5. **Auditability.** Points, conduct, claims, elections, and administrative actions leave a reviewable record.

### Device policy and access

Students at The Asian School, Bahrain do not bring mobile phones to school. Student-facing features are for use outside school hours on a personal device, subject to school and family policy.

Staff-facing features — attendance, scanning, approvals, event management, and academic administration — run on school-authorised devices. The app does not replace classroom teaching, in-person attendance, the school's official ID, or any school-issued process.

---

## 3. What the app contains

Implemented scope is summarised below. Inclusion does not imply production clearance; every module is subject to the release gates in Section 10.

| Area | Included functions |
| --- | --- |
| **Academic information** | Student timetable, homework, exam schedule, report cards, attendance record, medical leave request, and circulars. |
| **House system** | House points ledger, contributor records, standings, badges, House Arena (including visual Spirit Reactor), and house group chat. |
| **Student leadership** | Election workspace for eligible roles, claims review for authorised captains and council members, and event tools for authorised users. |
| **Staff administration** | Class and section rosters, placement verification, promotion, timetable approval, claims and leave review, notices, events, and audit logs. |
| **Communication** | Direct messages, class groups, and house groups restricted to participants, with room creation and photo attachments enabled in rules. |
| **Recognition** | Claim submission with evidence, non-self-approvable staff/captain review, point award, and sender-attributed notification. |
| **Events** | Staff event publishing, student RSVP, attendee counts, and event-wall posts. |
| **Data controls** | Protected profile fields, centralized suspension checks across UI/Auth/Firestore/Storage, cache isolation across switches, and missing-data guards. |

---

## 4. How to read the release status

Every module carries one of these labels. The labels describe implementation and release status, not marketing readiness.

| Status | Meaning |
| --- | --- |
| `GATED` | Implemented and locally tested, but one or more open server-authority, deployment, or governance findings block production release. No live school data. |
| `PILOT` | Interactive demonstration using sample, local, or engagement data. Not authoritative. |
| `ACTIVATION` | The app-side experience is built. A required school IT / Firebase Blaze service is not yet deployed. |
| `ROADMAP` | Planned enhancement, not present in this build. |
| `READY` | Target state: implemented, locally tested, deployed, and no open release-blocking finding. **Not assigned to any module as of 27 November 2026.** |

> **Release note.** No module is production-cleared. While major local authorization, suspension, schema, and platform bugs identified in the 26 November 2026 audit have been closed in code and emulator tests, backend deployment (`G3`), server-owned authority (`G2`), and governance sign-off (`O01`, `O02`) keep production gates open. The companion [deep audit](../audits/ASB_HOUSE_HUB_DEEP_AUDIT_2026-11-26.md) records the original baseline findings and probes.

---

## 5. Complete feature catalogue

### 5.1 Identity, onboarding, and account access

**Purpose:** Provide role-aware sign-in and account access while protecting school identity data.

**Features**

- **Branded first-run onboarding** introduces the app, the house system, and the main student services.
- **Scholar-number sign-in and signup** let students register and sign in with bounded timeouts, rollback safety, and non-blocking post-commit sync (`13b791c`).
- **Password reset by scholar number** sends reset instructions through the school's Firebase Authentication setup.
- **Saved accounts** let shared-device users return to an existing profile, with verified re-authentication, full scoped cache scrubbing (`clearCache()`), and fresh live-role preference (fixing `O05` and `O06`).
- **Centralized suspension enforcement** blocks suspended or deactivated users at `signIn()`, `switchAccount()`, `HomeScreen` lock view, Firestore rules, and Storage `isActiveUser()` (`O04`).
- **Unified role definitions** align `'administrator'` super-admin recognition and `'teacher'` membership mapping across `AuthService` and `firestore.rules` without hardcoded scholar display escalation (`O44`).
- **Fail-closed release startup** refuses silent demo fallback if Firebase fails to initialize in release mode (`O36`).

**Status:** `GATED` — local suspension, role parity, cache scrubbing, and signup reliability are fixed and tested, but bootstrap admin governance (`O01`) and pre-seeded enrollment roster binding (`O02`) remain open.

> **Audit note.** **Closed locally:** `O04` suspension bypass, `O05` stale saved-account role escalation, `O06` cross-account cache leakage, `O36` release startup fallback, and `O44` role-contract divergence. **Open:** `O01` accepted `11209/admin` bootstrap exception (retained until named governance phase) and `O02` lack of a server-enforced pre-seeded school enrollment roster binding scholar signups.

### 5.2 Home dashboard and navigation

**Purpose:** Provide the app's main entry point for the dashboard, store, standings, profile, notices, and service navigation.

**Features**

- **Four primary tabs:** Dashboard, Store, Standings, and Profile.
- **Role-aware navigation drawer** exposes academics, claims, events, elections, sports, notifications, scanner, AI assistant, library, and administration tools only where appropriate.
- **Suspended-account lockout gate** replaces dashboard navigation with a locked notice and sign-out action if a signed-in profile is suspended or deactivated.
- **House-coloured greeting** with the student's name, house, points, and current standing.
- **Service cards, notice ticker, and Event Wall preview** highlight active campus modules and announcements.
- **Unread notification badges** keep attention on new items with sender attribution.
- **Student profile modal** gives a quick view of identity, house, class, points, and recognition.
- **Cached dashboard states** stay scoped to the active account and clear on switch/sign-out.

**Status:** `GATED` — dashboard layout and sender-scoped feeds are hardened locally, but live sign-in enrollment binding (`O02`) and live rules deployment (`G3`) remain pending.

> **Audit note.** **Closed locally:** `O36` fail-closed startup, `O04` suspension lockout, `O06` scoped dashboard caches, and `O07` sender-scoped in-app notifications. **Open:** `O01`/`O02` identity governance and push notification activation (`O43`).

### 5.3 Houses, standings, and spirit

**Purpose:** Provide house points, contributors, standings, badges, spirit screens, and house groups.

**Features**

- **Four houses** — Ruby, Sapphire, Emerald, and Topaz — each with its own colour and emblem.
- **House points ledger & contributor records** display points and scholar attribution.
- **Standings screen** presents total points, category points, sports points, podium placement, and top contributors.
- **House Arena** includes the Spirit Gauge, **Spirit Reactor**, Blitz Quiz, Cup Oracle, Badge Vault, and Honours. The Spirit Reactor provides interactive particle shockwaves, haptic pulse, and house chant feedback purely as a visual/engagement experience — it does **not** award official house points or modify standings.
- **Badges and confetti effects** celebrate participation and achievement.
- **3D mascot stage and battle chant synthesiser** for each house.
- **House group chat** gives each house a private coordination space.

**Status:** `GATED` — display, engagement widgets, and house-group UI are built; the points ledger is not yet server-authoritative. The Spirit Reactor, Blitz Quiz, and Cup Oracle are `PILOT` engagement experiences that carry zero effect on official house totals.

> **Audit note.** Client-initiated award writes are still not server-owned (`O14`, `O15`), conduct revocation ordering (`O17`), and the first-demerit negative contributor edge (`O18`) remain open until migrated to Blaze Cloud Functions. Treat standings as display-only until the award ledger is server-owned.

### 5.4 Academics

**Purpose:** Provide student academic information and staff academic tools in one module.

**Features**

- **Structure and placement:** Class/section rosters, placement verification, section creation, house/status/transfer controls, and student promotion tools.
- **Timetable:** Student day/period view, teacher timetable editor with conflict preflight, approval/rejection workflow, and image/circular attachments.
- **Homework and assignments:** Publishing with due date and reference image, per-scholar submission tracking, grading, and merit awards.
- **Exams & report cards:** Hall/desk allocation, syllabus revision checklists, term report cards with GPA and academic-year separation, PDF export, and honours summaries.
- **Attendance and leave:** Period and daily attendance (`present + excused + 0.5 × late`), CBSE 75% compliance indicator, medical leave queue, and clear non-conversion policy.
- **Circulars and class group chat:** Composer with audience targeting and class chat bound to verified class placement.

**Status:** `GATED` — core academic screens, attendance policy, report cards, and query limits work locally; server-side honours/promotion authority and live Storage attachments remain gated.

> **Audit note.** **Closed locally:** Query limits on academic listeners, unified `'teacher'` role mapping, and `O42` committed `firestore.indexes.json` covering `medical_leaves`, `users`, `timetable_versions`, and `timetable_audit`. **Open:** Client-derived honours eligibility (`O16`), sequential promotion batch risk (`O31`), timetable read/check/write concurrency (`O30`), inline attachment size limits without Storage (`O34`), and malformed-record stream isolation (`O35`). Large PDF attachments require `ACTIVATION` of Cloud Storage.

### 5.5 Claims and recognition

**Purpose:** Record student achievement and conduct with evidence, review, points, and notifications.

**Features**

- **Claim submission** with activity title, requested points, house, and supporting certificate image or PDF.
- **Strict Storage evidence path** enforces immutable create-only uploads scoped to `house_claims/{uid}/{scholarNo}_...` with safe raster/PDF MIME checks (`O09`).
- **Non-self-approvable review queue** prevents submitters or captains from approving their own scholar claim in rules, `AuthService.approveClaim`, and UI, while scoping captains to their own house (`O08`).
- **Approve or reject** with reason, point award, and sender-attributed student notification.
- **Approved-claims gallery** with certificate preview and immutable claim identity.
- **Student conduct records** for merit and demerit entries with evaluator identity and revocation history.

**Status:** `GATED` — claim ownership, MIME security, house scoping, and self-approval blocks are enforced in Batch 1; server-owned atomic points ledger (`O14`/`O15`) and Blaze Storage OCR triggers remain pending.

> **Audit note.** **Closed locally:** `O08` self-approval, caller-forged `ocr_keywords`/`file_path`/`ai_verified` fields, and cross-house captain reads; `O09` Storage MIME whitelist (blocking SVG XSS), `resource == null` overwrite prevention, and matching `verifyCertificateSignature` trigger path parsing (`parts[1]` = UID). **Open:** `O14`/`O15`/`O17` server-side points/conduct atomicity and Blaze Storage + OCR Cloud Function activation (`G3`).

### 5.6 Campus events

**Purpose:** Manage staff-created events, audience eligibility, student RSVPs, and an event wall.

**Features**

- **Staff event composer** with draft, preview, publish, edit, and cancel actions.
- **Audience targeting** by whole school, individual house, or grade range.
- **Student event feed and detail view** with venue, time, category, description, and organiser.
- **RSVP registration** with one response per student and live attendee counts.
- **Event Wall** for images, captions, and campus highlights.
- **Sample event mode** for training and demonstrations.

**Status:** `GATED` — event creation, cancellation, and index definitions are hardened; caller-supplied profile grade eligibility (`O33`) still requires trusted server/roster enforcement.

> **Audit note.** Rules enforce published state, house scope, author checks, and cancellation (`O42` index added for `events`), while grade-restricted RSVP eligibility (`O33`) still depends on profile grade fields until bound to trusted roster metadata (`O02`).

### 5.7 Notifications

**Purpose:** Deliver in-app notices and alerts with read state, priority, and per-category counts.

**Features**

- **In-app notification centre** with categories, priority, timestamps, and `From <senderName>` attribution when supplied.
- **Read/unread states, mark all as read, and clear all actions.**
- **Deterministic deduplication** via `source_id` (falling back to `dedupeKey`) so retries update deterministically without duplicate alerts.
- **Scoped notification rules** bind `isNotificationScopeSender` to verified target memberships, lock `chat_message` to `category == 'chat'` and `priority == 'normal'`, house-scope captains, and forbid captains/council from spoofing `account_status` or `role_assigned` alerts (`O07`).
- **Suspended users blocked** from mutating or deleting notifications (`O04`).

**Status:** `GATED` — in-app sender scoping and anti-spoofing rules are hardened and tested in Batch 1; server Cloud Function fan-out and background FCM push (`O43`) remain `ACTIVATION`.

> **Audit note.** **Closed locally:** `O07` arbitrary cross-user notification spoofing and privilege-escalation category/type forgery; `O04` suspended user updates. **Open:** `O43` background FCM token lifecycle/delivery (`ACTIVATION` pending Blaze/Functions) and deployment of updated Batch 1 `firestore.rules`.

### 5.8 Chat and groups

**Purpose:** Provide participant-only direct messages, class groups, and house groups.

**Features**

- **Direct messages** between students and authorised peers/staff, with deterministic conversation rooms.
- **New room creation & photo attachments** fixed in `firestore.rules` and `ChatService` (`attachment_url` supported up to 9000 chars, bounded stream limits applied) (`O27`, `O28`).
- **Class and house group chats** scoped to verified members.
- **Unread counters, read receipts, and pinned/hidden moderation** for staff.
- **Honest privacy labelling** — conversations are described as private to participants, not end-to-end encrypted.

**Status:** `GATED` — room creation, photo attachments, stream limits, and peer rules are repaired (`84446a1` / `a0800af`), pending live rule deployment (`G3`) and server-verified roster binding (`O29`).

> **Audit note.** **Closed locally:** `O27` new DM creation path, `O28` `attachment_url` photo schema acceptance, and `ChatService` stream query bounds. **Open:** Server-backed peer role validation (`O29`) remains aligned with `O02` roster verification and requires Batch 1/post-`13b791c` rule parity live.

### 5.9 Sports and trophies

**Purpose:** Record fixtures, match events, tournaments, trophies, and player statistics.

**Features**

- **Fixture scheduling, live match HUD, tournament brackets, victory PDF certificates, and trophy cabinet.**
- **Aligned trophy schema** reconciles `SportsTrophy` `tournament_title` with Firestore `title` requirements (`O19`).
- **House points integration and sports certification tokens.**

**Status:** `GATED` — trophy payload compatibility is repaired (`O19`); concurrent score updates (`O20`) and server match authority remain open.

> **Audit note.** **Closed locally:** `O19` trophy creation schema mismatch (`title` / `tournament_title`). **Open:** `O20` concurrent live score updates still rely on client writes without a server-authoritative scoring Cloud Function (`ROADMAP` / `G2`).

### 5.10 Elections and student leadership

**Purpose:** Provide an election workspace, eligibility rules, voting, participation receipts, audit records, and certified results.

**Features**

- **Election workspace** for drafts, candidates, publish, close, certify, cancel, and delete-draft actions.
- **Leadership roles** including House Captain, House Vice-Captain, Head Boy, Head Girl, Class Prefect, Sports Captain, and Cultural Secretary.
- **Server-transactional one-scholar-one-vote & fail-closed UI** — `SchoolElectionsPage` fails closed when Cloud Functions (Blaze) are unavailable rather than faking live tallies (`d471029`).
- **Participation receipts, audit log, and certified results gazette.**

**Status:** `ACTIVATION` — management, UI fail-closed guards, and `functions/elections-v2.js` callable code exist, but live voting cannot run until school IT enables Firebase Blaze and deploys + verifies the election Cloud Functions.

> **Device & Audit note.** Election voting is not live; any activated voting requires a school-approved device or supervised kiosk. **Open (`O10`–`O12`, `O23`):** No Cloud Functions are deployed (`O11`); legacy lifecycle rules (`O10`), audit UI/backend path alignment (`O12`), and moving signing secrets off the client (`O23`) must complete alongside Blaze deployment.

### 5.11 School store and orders

**Purpose:** Provide a merchandise catalogue, cart, order request, order history, and staff-recorded collection status.

**Features**

- **Ten-item internal merchandise catalogue** with house variants and BHD prices. **No external e-commerce website, print-on-demand service (e.g., Printify), or online payment gateway is connected** — the store is strictly an internal Firestore order-request workflow handled offline by the school office.
- **Cart customisation before checkout:** Shoppers can open the cart, change item size/variant options, adjust quantities (`+` / `-`), or remove items before submitting a request. Once submitted, an order request is immutable; staff record verification and collection handover.
- **Bounded order pricing integrity** enforces `total_bhd > 0 && total_bhd <= 10000`, `total_pts == 0`, `total_price >= total_bhd`, and immutable financial/item fields on updates in `firestore.rules` (`O21`).
- **True HMAC-SHA256 `v2.0` voucher tokens** bind order ID, scholar number, full `items` digest, and `total_bhd` in `VoucherSecurityService` (without client hardcoded fallbacks).
- **Verified-only fulfillment:** Live claims via `claimStoreVoucher` and `IdScannerScreen` reject unverified `'placed'`/`'pending'` orders (requiring `'verified'` or `'ready'` status) and do not fall back to local cache when live Firestore records are missing (`O22`).

**Status:** `GATED` — cart customization, bounded order pricing, HMAC-SHA256 voucher binding, and verified-only claim checks are implemented in Batch 1; full server-side catalog pricing and key removal from the client (`O23`) require Blaze Cloud Functions.

> **Audit note.** **Closed locally:** `O21` zero-price/unbounded order creation, `O22` unverified order claim fallback & double-state mismatch in scanner, and weak v1 voucher binding. **Open:** `O23` removing the HMAC secret from client binaries in favour of a Cloud Function signer/verifier and server-side product price lookup. Orders remain unverified office requests — not online payments.

### 5.12 Digital passes and documents

**Purpose:** Provide pass and receipt previews with scannable PDF export.

**Features**

- **Three pass tabs:** Store Passes, Campus ID, and Fee Receipts.
- **Campus ID card and QR pass** displaying scholar number, house, class, points, and access tier.
- **Scannable vector QR PDF export** powered by `QrPainter` in `PassDocumentExporter` (`O24`, replacing the earlier text-only PDF payload).
- **Sample fee receipt view** clearly labelled as a non-billing sample.

**Status:** `PILOT` — previews and vector QR PDF export (`O24`) are implemented locally, while server-held signing secrets (`O23`), live billing integration, and Apple/Google Wallet or NFC (`ROADMAP`) are not implemented.

> **Audit note.** **Closed locally:** `O24` vector QR rendering in exported PDF passes. **Open:** `O23` client-embedded signing secret (requires server callable verification), plus platform sharing/web polish where applicable. The pass is an app preview, not a school-issued ID or campus-entry credential.

### 5.13 ID scanning and behaviour evaluation

**Purpose:** Provide staff-operated scanning, student lookup, voucher validation, and conduct recording.

**Features**

- **Staff-operated camera scanner, image upload decoding, and manual scholar-number fallback.**
- **Student pass validation and order/voucher verification** requiring live Firestore `'verified'` or `'ready'` order status before marking claimed in UI (`O22`).
- **Behaviour evaluation screen** for merit/demerit entries (1–100 points) with structured reasons, evaluator identity, and revocation.

**Status:** `GATED` — scanner claim state synchronization (`O22`) and Storage claim evidence rules (`O09`) are tightened in Batch 1; server-side voucher signing (`O23`) and atomic conduct revocation (`O17`) remain open.

> **Audit note.** **Closed locally:** `O09` Storage claim path/MIME protections and `O22` live-verified voucher state checks. **Open:** `O23` server voucher verification and `O17` atomic conduct reversal (`G2`).

### 5.14 Library

**Purpose:** Provide a library portal with loan cards, renewal preview, and local cache while the backend service is prepared.

**Features**

- **Library portal, borrowed-book cards, due-day counters, renewal preview, and local cache.**
- **Authored server-side library module (`functions/library-v2.js`)** prepared for transactional checkout, return, and renewal once Blaze is enabled.

**Status:** `PILOT` — the portal still displays sample/legacy loan data; end-to-end backend lending requires Blaze `ACTIVATION`.

> **Audit note.** Missing live v2 Firestore rules, catalog seeding, and connected UI against `functions/library-v2.js` remain open (`O13`), gated on Blaze deployment (`O11`). Student access is outside school hours.

### 5.15 House AI assistant

**Purpose:** Provide an optional AI chat with house-aware prompts, Gemini integration, and local fallback guidance.

**Features**

- **House AI chat screen** with house-aware styling and quick prompt shortcuts.
- **Updated Gemini `2.5` integration** using `gemini-2.5-flash`, `gemini-2.5-pro`, and `gemini-2.0-flash` with `x-goog-api-key` HTTP header authentication (removing query-string key exposure, `O25`).
- **Local fallback guidance** when no key is configured or offline.

**Status:** `PILOT` — uses current Gemini 2.5 models with header auth (`O25`), but remains client-keyed and unapproved for real student data (`O26`).

> **Audit note.** **Closed locally:** `O25` deprecated model IDs and URL query-parameter API key exposure. **Open (`O26`):** API keys still persist locally via `SharedPreferences`, and a server-side Gemini Cloud Function proxy is required before entering real student/academic context (`G3`/`G4`).

### 5.16 Administration and governance

**Purpose:** Provide administration tools for academics, recognition, communication, events, and student leadership.

**Features**

- **Academic administration:** Class creation, placement verification, promotion, timetable approval/rejection, house/status/transfer controls, and audit log.
- **Claims and conduct administration:** Pending claims queue (blocking self-approval), medical leave queue, approved-claims gallery, roster management, and conduct records.
- **Communication, events, elections, and sports management.**
- **Unified governance checks:** Single role contract aligning `'administrator'` across `AuthService` and Firestore (`O44`), unified teacher mapping in `school_members`, fail-closed missing-data guards, and per-device local vault protection (`84446a1`).

**Status:** `GATED` — UI and Batch 1 authorization/role-parity protections are built locally; bootstrap admin governance (`O01`), trusted enrollment roster provisioning (`O02`), and Cloud Function authority (`G2`/`G3`) remain open.

> **Audit note.** **Closed locally:** `O04` suspension enforcement, `O05`/`O06` cache & stale-role isolation, `O08` self-approval guard, `O44` role-contract alignment, and `84446a1` per-device vault key. **Open:** `O01` accepted `11209/admin` bootstrap exception, `O02` enrollment roster binding, `O10` election Cloud Function transition, and `O31` atomic promotion batches. Named administrator accounts, MFA, and server-side roster authority remain `ROADMAP`.

---

## 6. Role-based experience

The matrix describes intended permissions backed by unified `AuthService`, Firestore, and Storage role contracts (`O44`) and central suspension checks (`O04`). Until live rules/Functions deployment (`G3`) and trusted enrollment roster binding (`O02`) close, treat this as a pre-deployment target rather than verified live production access control.

| Capability | Student | Teacher / Faculty | Captain / Council | Administrator |
| --- | :---: | :---: | :---: | :---: |
| Branded dashboard and notices | ✓ | ✓ | ✓ | ✓ |
| Timetable, homework, exams, report cards | ✓ | ✓ | ✓ | ✓ |
| Attendance record and medical leave | View / request | Review | Review | ✓ |
| House standings and contributors | ✓ | ✓ | ✓ | ✓ |
| Submit a house-point claim | ✓ | — | ✓ | ✓ |
| Review and approve claims (non-self only) | — | ✓ | House-scoped | ✓ |
| Publish events and notices | — | ✓ | Scoped | ✓ |
| RSVP to campus events | ✓ | ✓ | ✓ | ✓ |
| Direct and group chat | ✓ | ✓ | ✓ | ✓ |
| Live sports scoring and trophies | View | ✓ | ✓ | ✓ |
| Stand for election | ✓ | — | ✓ | — |
| Vote in an election (activation-dependent) | ✓ | — | ✓ | — |
| Manage election lifecycle | — | — | Scoped | ✓ |
| Student conduct evaluation | View own | ✓ | ✓ | ✓ |
| Staff scan passes and claim orders | — | ✓ | ✓ | ✓ |
| View or export own scannable QR pass | ✓ | ✓ | ✓ | ✓ |
| Academic administration and promotion | — | — | — | ✓ |
| Role assignment and audit review | — | — | — | ✓ |

*Student access to the app is outside school hours. Election voting is not live and would require a school-approved device or supervised kiosk if activated. Scoped means the action is limited to the user's house, class, or delegated capability; self-approval of claims is blocked across all roles.*

---

## 7. Student-facing capabilities

Student accounts provide the following implemented functions outside school hours on a personal device, subject to school and family policy. No path is production-cleared until G1–G3 close live.

### Account and profile
- Branded onboarding, scholar-number sign-in/signup with bounded timeout handling, and password reset.
- Saved accounts with re-authentication and full cache scrub across account switches.
- Profile view with house, class, points, recognition, and light/dark theme preference.

### Academics
- Timetable by day and period; homework list, submission, and status.
- Exam schedule, hall/desk allocation, and syllabus revision checklist.
- Term report cards with GPA, honours, and PDF export; attendance record and CBSE 75% indicator.
- Medical leave request with supporting document; circulars and class group.

### Houses, recognition, and events
- House points, standing, contributor list, badges, House Arena (with interactive Spirit Reactor), and house group chat.
- Claim submission with evidence, non-self-approvable status tracking, sender-attributed notifications, and own conduct record.
- Event feed, RSVP, event wall, direct messages, and class/house groups (including room creation and photo attachments).

### Services & known limits
- Internal merchandise catalogue with cart customisation (size, quantity, removal), office order requests, and order status.
- Pass and receipt preview with vector QR PDF export; library portal (`PILOT` sample loans); optional Gemini 2.5 AI assistant.
- **Known limits:** Order totals rely on client price inputs until server catalog validation (`O23`); AI keys persist locally without a server proxy (`O26`); election voting (`O11`) and library backend (`O13`) require Blaze Cloud Functions; grade-restricted event eligibility (`O33`) awaits trusted roster binding (`O02`); no module is production-cleared as of 27 November 2026.
- **Not provided:** No external store/Printify integration, no online payment, no campus-entry pass, no live election results, no Apple Wallet / Google Wallet / NFC support.

---

## 8. Design, accessibility, and platform support

### Visual design & accessibility (implemented, not certified)
- House-led colour system, light and dark themes, structured cards/badges, celebratory motion, school branding, 3D house mascots, and responsive desktop/mobile/web layouts.
- Semantic labels, minimum 48 dp touch targets, large-font checks, keyboard/focus navigation, clean empty/loading/error states without raw stack traces, and non-colour-only status indicators.
- Accessibility has not yet been certified with assistive technology, and localization/RTL coverage (`O41`) remains incomplete.

### Supported platforms

| Platform | Support | Current verification note |
| --- | --- | --- |
| **Android** | Student access outside school hours; staff scanner and notification centre | Release keystore signing (`android/key.properties`) and ProGuard deferred-component fixes landed (`9cfd7f0`, `d471029`); release APK previously built at `13b791c` before Batch 1 edits; physical device test pending after final edits |
| **iOS** | Student access outside school hours; staff scanner and notification centre | Deployment target raised to `15.0` (`d471029`); release build requires macOS/Xcode (`O38`) |
| **Windows** | Desktop access to the app | Release build previously verified at `13b791c` before Batch 1 edits |
| **Web** | Browser access to the app | Release build previously verified at `13b791c` before Batch 1 edits |

---

## 9. Security design and open findings

This section reflects the 27 November 2026 security posture across locally verified Batch 1 controls and remaining backend/governance gaps.

| Area | Implemented control (through Batch 1) | Remaining open audit position |
| --- | --- | --- |
| **Identity** | Re-authentication before switching, full `clearCache()` scrub (`O06`), live-role preference (`O05`), central UI/Auth/Firestore/Storage suspension (`O04`), unified role parity (`O44`), fail-closed release startup (`O36`), bounded signup timeouts (`13b791c`). | **Accepted exception:** `11209/admin` bootstrap path (`O01`). **Open:** pre-seeded enrollment roster binding (`O02`). |
| **Authorization** | Sender-scoped `isNotificationScopeSender` + anti-spoof category/type bounds (`O07`), house-scoped captain claim reads, blocked `ocr_keywords`/`file_path`/`ai_verified` injection, and self-approval block (`O08`). | Authoritative server fan-out for notices/OCR and live push delivery (`O43`). |
| **Storage** | Raster/PDF MIME whitelist blocking SVG XSS, expanded `isLeader()`, `resource == null` + strict `house_claims/{uid}/{scholarNo}_...` path regex, split create/update vs delete, aligned `verifyCertificateSignature` trigger, **Storage Emulator tested (`28/28`)**. | Cloud Storage bucket not activated on Spark plan; rules and OCR trigger await Blaze deployment (`G3`). |
| **Elections** | Direct client tallies denied; UI fails closed when Cloud Functions are unavailable (`d471029`). | No deployed Cloud Functions (`O11`); legacy lifecycle rules (`O10`), audit path mismatch (`O12`), and client secret (`O23`) await Blaze deploy. |
| **Scoring and conduct** | Points/conduct carry reviewer identity; self-approval on claims blocked; sports trophy schema aligned (`O19`). | Non-atomic client point awards (`O14`, `O15`), client honours (`O16`), revocation order (`O17`), negative contributor edge (`O18`), concurrent sports scoring (`O20`). |
| **Orders and vouchers** | Bounded positive BHD pricing & immutable order financial fields (`O21`), HMAC-SHA256 `v2.0` tokens binding items + BHD total, live `'verified'`/`'ready'`-only scanner claims without cache fallback (`O22`). | Client-embedded HMAC signing secret and lack of server-side product catalog validation (`O23`). |
| **Passes, AI & platform** | Vector QR PDF export (`O24`), Gemini `2.5` models + `x-goog-api-key` header (`O25`), per-device local vault key (`84446a1`), Android release signing + iOS `15.0` target (`O38`), `firestore.indexes.json` (`O42`), CI pipeline. | User AI keys persisted locally (`O26`), no App Check (`O37`), no iOS macOS build (`O38`), no Blaze server AI proxy. |
| **Chat, events & academics** | Participant-only reads/receipts, new DM creation + `attachment_url` photo schema + query limits (`O27`, `O28`). | Peer policy roster binding (`O29`), event grade roster binding (`O33`), timetable concurrency (`O30`), atomic promotion (`O31`), inline Base64 size cap (`O34`), malformed-doc isolation (`O35`), localization (`O41`). |

### Privacy posture & what is not claimed
- Chat is **private to participants**, not end-to-end encrypted; fee receipts are samples; store orders are offline office requests (no external website or payment gateway); Spirit Reactor is a visual pilot element with zero point impact; digital passes are app/PDF previews (not Apple/Google Wallet, NFC, or campus entry IDs); AI assistant keys/prompts remain unapproved for real student data (`O26`).
- No claim is made of production security certification, penetration testing, accessibility certification, or live Blaze Cloud Function deployment.

---

## 10. Audit results, quality, and release gates

### Current release decision

**Not cleared for production.** Since the 26 November 2026 deep audit (`9d0a559`/`0beb87b`), eight engineering commits (`2e54a9a..13b791c`) plus the Batch 1 local security remediation fixed identity suspension/cache isolation/role parity (`O04`–`O06`, `O44`), notification spoofing (`O07`), claim self-approval (`O08`), Storage path/MIME ownership and trigger alignment (`O09`), order price bounds and live verified-only voucher claims (`O21`, `O22`), chat room/photo rules (`O27`, `O28`), trophy schema (`O19`), scannable vector QR PDFs (`O24`), Gemini `2.5` header auth (`O25`), fail-closed release startup (`O36`), Android signing / iOS `15.0` (`O38`), committed indexes (`O42`), and CI automation.

However, **Firebase Cloud Functions (requiring Blaze) are not deployed**, **Cloud Storage is not active live**, **Batch 1 rules updates are not yet deployed over the prior `13b791c` live ruleset**, and **server-owned points/sports/catalog/election authority** remains open.

### Verification results

| Check | Result | Notes / Scope |
| --- | --- | --- |
| Flutter static analysis (`flutter analyze --no-pub`) | **No issues** | Verified after final Batch 1 edits |
| Flutter automated test suite (`flutter test --no-pub`) | **710 of 710 passing** | 22 test files, verified after final Batch 1 edits |
| Firestore + Storage Emulator security suite | **28 of 28 passing** | `functions/test/security.test.js` (`--only firestore,storage`), verified after Batch 1 edits |
| Backend JavaScript syntax (`functions/index.js`, `elections-v2.js`, `library-v2.js`) | **3 of 3 passing** | `npm run check` (`node --check`), host Node; CI pins Node 22 |
| GitHub Actions CI workflow (`.github/workflows/ci.yml`) | **Configured** | Runs `flutter analyze`, `flutter test`, and Firestore+Storage emulator tests |
| Live Firestore rules | **Stale vs local** | Prior ruleset deployed at `13b791c`; Batch 1 `firestore.rules` hardenings await deploy |
| Live Cloud Functions & Cloud Storage | **None deployed / inactive** | Blocked on Firebase Blaze billing & IT provisioning |
| Release binaries (Android APK, Windows, Web) | **Not rebuilt post-Batch 1** | Previously built cleanly at `13b791c` (with `key.properties` signing); iOS release build requires macOS |

### Release gates

| Gate | Scope | Exit criteria | Status |
| --- | --- | --- | --- |
| **G1 — Identity and access** | `O01`, `O02`, `O04`–`O06`, `O44` | `O04`–`O06`, `O44` closed locally; **remaining:** bind scholar identity to a pre-seeded school enrollment roster (`O02`) and resolve accepted bootstrap exception (`O01`) in governance phase. | **PARTIAL (OPEN)** |
| **G2 — Trusted records** | `O07`–`O23`, `O30`, `O31` | `O07`–`O09`, `O19`, `O21`–`O22` hardened locally; **remaining:** server-own points/conduct (`O14`–`O18`), sports scoring (`O20`), elections (`O10`–`O12`), store catalog & remove client HMAC secret (`O23`), atomic timetable/promotion (`O30`, `O31`). | **OPEN** |
| **G3 — Backend deployment** | `O11`–`O13`, `O25`, `O37`, `O42`, `O43` | `O42` indexes & CI emulator gate created; **remaining:** enable Blaze, deploy Functions on Node 22 (`O11`), activate Storage bucket, push Batch 1 `firestore.rules` + `storage.rules` + indexes, stage App Check (`O37`), verify FCM (`O43`). | **OPEN** |
| **G4 — Client and platform** | `O23`–`O26`, `O36`–`O38` | `O24` vector QR, `O25` Gemini 2.5, `O36` fail-closed startup, `O38` Android signing & iOS `15.0` closed locally; **remaining:** rebuild after Batch 1, macOS iOS release build, physical device test, move AI key to server proxy / secure keystore (`O26`), remove client HMAC key (`O23`). | **PARTIAL (OPEN)** |
| **G5 — Verification and operations** | `O32`–`O35`, `O39`–`O41` | `O39` CI emulator/Flutter pipeline added & query limits applied; **remaining:** hard pagination/aggregate caps (`O32`), roster-backed event/chat eligibility (`O29`, `O33`), corrupt-record isolation (`O35`), accessibility certification & localization/RTL (`O41`), monitoring & backups. | **OPEN** |

---

## 11. Deployment readiness and phased rollout

### Current deployment state

| Component | State as of 27 November 2026 |
| --- | --- |
| Cloud Functions | **None deployed** (3 modules authored locally; requires Blaze) |
| Firestore rules | Hardened through Batch 1 locally and emulator-tested (**28/28**); live project still runs prior `13b791c` ruleset until redeployed |
| Storage | Rules hardened and **emulator-tested** in Batch 1; live Cloud Storage bucket awaits Blaze initialization |
| Indexes | `firestore.indexes.json` committed locally (`O42`); pending live deploy |
| App Check | No client or backend enforcement (`O37`) |
| Push delivery | No FCM token lifecycle or backend delivery (`O43`) |
| Payments | Not enabled; store is an internal office request flow |
| Release builds | Android keystore signing (`key.properties`), ProGuard fix, and iOS `15.0` target configured locally; APK/Windows/Web verified at `13b791c`; iOS archive requires macOS |

### Phased rollout

- **Stage 0 — Current (Local Hardened & Synthetic Demo):** 710 Flutter tests + 28 Firestore/Storage emulator tests pass locally; Batch 1 security fixes verified. Allowed for code review, emulator demos, and administrative walkthroughs with synthetic data only.
- **Stage 1 — Remaining G1–G2 Server Authority:** Close server-owned points/sports/catalog/election authority (`O10`, `O14`–`O18`, `O20`, `O23`) and pre-seeded enrollment roster binding (`O02`).
- **Stage 2 — Blaze Deployment & Live Verification (G3):** Provision Firebase Blaze, deploy Batch 1 `firestore.rules`, `storage.rules`, `firestore.indexes.json`, and Cloud Functions on Node 22, activate Storage & FCM (`O43`), and stage App Check (`O37`).
- **Stage 3 — Conditional Supervised Pilot:** Requires G1–G3 live verification and senior leadership sign-off for one grade and one house (students outside school hours, staff on authorised devices).
- **Stage 4 — Activated Services & Scale (G4–G5):** Server AI proxy (`O26`), official library lending (`O13`), optional official kiosk elections, iOS release build on macOS, assistive-technology accessibility certification, and localization/RTL review (`O41`).

---

## 12. Proposed pilot and success measures (conditional)

A live pilot remains **conditional on closing and verifying G1–G3 live**.

| Item | Proposal |
| --- | --- |
| **Prerequisites** | G1–G3 closed and verified on live Firebase (Blaze/Functions/Storage/updated rules); administration sign-off |
| **Duration & scope** | Four school weeks — one grade and one house, plus supporting staff |
| **Device policy** | Students outside school hours; staff on school-authorised devices |
| **Target metrics** | ≥70% weekly active pilot students; ≥90% timetable/homework viewers; ≥50 claims reviewed (<2 days median); ≥80% RSVP conversion; ≥95% attendance visibility; <2%/week support requests; ≥4/5 satisfaction |

---

## 13. Product roadmap

| Priority | Work | Gate or dependency |
| :---: | --- | --- |
| 1 | Deploy updated Batch 1 `firestore.rules`, `storage.rules`, and `firestore.indexes.json` once target environment is ready | G3 |
| 2 | Bind new scholar registrations to a trusted school enrollment roster (`O02`) and resolve accepted bootstrap admin exception (`O01`) | G1 / Governance |
| 3 | Enable Blaze and deploy Cloud Functions on Node 22: authoritative points/conduct ledger (`O14`–`O18`), live sports scoring (`O20`), election callable (`O10`–`O12`), store catalog & server voucher signing (`O23`), library v2 (`O13`), and AI proxy (`O26`) | G2 / G3 |
| 4 | Initialize Cloud Storage bucket, stage App Check (`O37`), and enable FCM background notifications (`O43`) | G3 |
| 5 | Complete atomic timetable/promotion hardening (`O30`, `O31`), pagination/corrupt-doc isolation (`O32`, `O35`), and rebuild/test Android/iOS physical release packages on macOS & Android (`O38`) | G4 / G5 |
| 6 | Complete assistive-technology accessibility certification, localization/RTL (`O41`), monitoring, and backup drills | G5 |
| 7 | Run conditional 4-week supervised pilot, then activate Library, AI proxy, and optional kiosk elections | Post-G1–G3 |

---

## 14. Submission pack and approval request

### Documents in this submission

1. **ASB House Hub — Feature Catalogue & Release Readiness Review** (this document, updated 27 November 2026)
2. **Deep Code Audit, 26 November 2026** — [docs/audits/ASB_HOUSE_HUB_DEEP_AUDIT_2026-11-26.md](../audits/ASB_HOUSE_HUB_DEEP_AUDIT_2026-11-26.md)
3. **Source code & CI** — Flutter app (84 Dart files), Firebase rules (`firestore.rules`, `storage.rules`, `firestore.indexes.json`), Cloud Functions (3 Node 22 modules), and GitHub Actions CI (`.github/workflows/ci.yml`)
4. **Verification summary** — `flutter analyze` clean, **710/710** Flutter tests passing, **28/28** Firestore + Storage Emulator security tests passing, **3/3** Cloud Functions JS checks clean

### Approval requested

1. **Note the current release position:** Batch 1 security hardenings are verified locally, but live server deployment (Blaze Functions/Storage) and identity roster governance keep production clearance **OPEN**.
2. **Approve a closed, synthetic-data technical walkthrough** for code and UI review.
3. **Confirm administrative sponsorship, school IT contact, and Firebase Blaze readiness policy** before deploying Stage 2 services.

---

## 15. Appendix: module summary

| # | Module | Primary users | Status and notes (as of 27 November 2026) |
| :---: | --- | --- | --- |
| 1 | Identity, onboarding, and account access | All | `GATED` — `O04`–`O06`, `O36`, `O44` fixed locally; `O01` accepted exception, `O02` roster binding open |
| 2 | Home dashboard and navigation | All | `GATED` — Startup/suspension/cache hardened locally; depends on `O01`/`O02` and `O43` |
| 3 | Houses, standings, and spirit | Students, staff | `GATED` (`PILOT` widgets) — Spirit Reactor is visual-only; points ledger awaits server authority (`O14`–`O18`) |
| 4 | Academics | Students, teachers, admin | `GATED` — Role/index updates landed (`O42`); `O16`, `O30`, `O31`, `O34`, `O35` open |
| 5 | Claims and recognition | Students, staff, captains | `GATED` — `O08`, `O09` fixed locally; server ledger (`O14`–`O18`) & Storage deploy pending |
| 6 | Campus events | All | `GATED` — `events` index landed; grade eligibility (`O33`) awaits trusted roster (`O02`) |
| 7 | Notifications | All | `GATED` — Sender scoping & anti-spoof fixed (`O07`); FCM push (`O43`) & rule deploy pending |
| 8 | Chat and groups | Students, staff | `GATED` — Room creation (`O27`), photo schema (`O28`), stream limits fixed locally; `O29` roster link open |
| 9 | Sports and trophies | Students, staff | `GATED` — Trophy schema (`O19`) fixed; live scoring concurrency (`O20`) open |
| 10 | Elections and student leadership | Students, council, admin | `ACTIVATION` — UI fails closed cleanly; Functions (`O11`), lifecycle (`O10`), path (`O12`), secret (`O23`) open |
| 11 | School store and orders | Students, admin | `GATED` — Internal catalogue + cart editing + price bounds (`O21`) & HMAC-SHA256 claim checks (`O22`) fixed; server catalog/key removal (`O23`) open; no external site |
| 12 | Digital passes and documents | Students, staff | `PILOT` — Vector QR PDF export (`O24`) implemented; server signing (`O23`) & Wallet/NFC roadmap |
| 13 | ID scanning and behaviour evaluation | Staff, captains | `GATED` — `O09`, `O22` fixed locally; `O17` atomic revocation & `O23` server key open |
| 14 | Library | Students | `PILOT` — Sample UI active; `library-v2.js` (`O13`) awaits Blaze deploy |
| 15 | House AI assistant | Students | `PILOT` — Gemini `2.5` + header auth (`O25`) implemented; server proxy (`O26`) open |
| 16 | Administration and governance | Administrators | `GATED` — `O04`–`O06`, `O08`, `O44` fixed; `O01`, `O02`, `O10`, `O31` open |

**No module is production-cleared as of 27 November 2026.** `READY` is the target state and is not currently assigned.

*Prepared for the Administration of The Asian School, Bahrain.*  
*ASB House Hub · Version 1.0.1 (Build 2) · November 2026*
