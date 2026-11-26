# ASB House Hub

## Feature Catalogue & Release Readiness Review

**Application features for academics, houses, events, leadership, and administration**

---

**Prepared for:** The Administration, The Asian School, Bahrain

**Prepared by:** Mustafa Hisham

**Application version:** 1.0.1 (Build 2)

**Date:** 26 November 2026

**Document status:** Submission for administrative review — not a production release approval

---

> **Purpose of this document.** This catalogue documents what each module of ASB House Hub contains, who can use it, its current release status, and the audit findings that block production use. It describes the application and the 26 November 2026 audit outcome; it is not a production approval.

---

## Contents

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

ASB House Hub is a Flutter application for academic information, house points, events, communication, recognition, and administration. It contains **16 modules** and **28 screens**, with role-based access for students, teachers, captains and council members, and administrators.

Students at The Asian School, Bahrain do not bring mobile phones to school. Student-facing features are provided for use outside school hours on a personal device, subject to school and family policy. Staff features — attendance, scanning, approvals, event management, and academic administration — run on school-authorised devices.

> **Current release position: not cleared for production.** The deep code audit of 26 November 2026 found **23 critical/high findings** and **21 medium/low findings** still open. Identity binding, authorization, local credential storage, authoritative scoring and orders, and backend deployment require remediation. No Cloud Functions are deployed, and live rules, indexes, Storage, and production data were not verified. The build is suitable for code review and synthetic-data demonstration only. No live student, staff, medical, payment, or election data should be entered.

The app is designed around five goals; the audit found that several are not yet fully enforced:

- **Role-aware access.** What a user can see and do is intended to follow their school role and placement.
- **One account per scholar.** Students, teachers, captains, council members, and administrators use a single sign-in.
- **Visible house records.** Points, contributors, standings, badges, and recognition are stored and reviewable.
- **Staff-controlled workflows.** Claims, conduct, elections, events, and approvals follow defined staff permissions.
- **Truthful status reporting.** Sample data, previews, and services that are not active are labelled as such.

The current build implements academic, house, event, communication, recognition, and administration workflows at different levels of maturity. Capabilities that depend on school IT services — background push notifications, large-file storage, live server-verified elections, the library backend, and online payments — are marked **ACTIVATION**. Modules with open release-blocking findings are marked **GATED** and are not approved for live use.

Verification completed: **685 automated tests passing**, a clean static analysis run, **13 rules and election emulator tests**, and successful **Windows and web release builds**. These results do not clear the release. Android and iOS release builds, Storage emulator tests, physical-device testing, accessibility certification, and deployed integration tests were not completed.

> **Recommended next step:** approve a closed, synthetic-data technical review and the remediation plan in Section 10. Do not approve a live pilot until gates G1–G3 are closed and verified. The first remediation batch should address identity binding, suspension enforcement, notification and claim authorization, order pricing, and Storage ownership.

---

## 2. The app at a glance

| Item | Detail |
|---|---|
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
| **Current release position** | **Not cleared for production** — 23 critical/high findings open (26 November 2026 audit) |
| **Deployment state** | Local build only; no Cloud Functions deployed; live rules, indexes, and Storage not verified |
| **Quality evidence** | 685 automated tests passing; 13 rules/election emulator tests; static analysis clean; Windows and web release builds pass |
| **Release** | Version 1.0.1, Build 2 — November 2026 |

### Core design principles

The app is designed around these principles. Section 10 records where the current build does not yet meet them.

1. **Student-first clarity.** Important information is reachable in a few taps, with plain-language labels and clear empty states.
2. **Role-aware by design.** What a user can see and do is intended to follow their school role and placement.
3. **Truthful interfaces.** The app does not label a sample, preview, or unverified item as live or paid.
4. **Fail closed on missing data.** Academic and points actions are intended to stop rather than silently using another class, house, or scholar.
5. **Auditability.** Points, conduct, claims, elections, and administrative actions are intended to leave a reviewable record.

### Device policy and access

Students at The Asian School, Bahrain do not bring mobile phones to school. Student-facing features are for use outside school hours on a personal device, subject to school and family policy.

Staff-facing features — attendance, scanning, approvals, event management, and academic administration — run on school-authorised devices. The app does not replace classroom teaching, in-person attendance, the school's official ID, or any school-issued process.

---

## 3. What the app contains

Implemented scope is summarised below. Inclusion does not imply production clearance; every module is subject to the release gates in Section 10.

| Area | Included functions |
|---|---|
| **Academic information** | Student timetable, homework, exam schedule, report cards, attendance record, medical leave request, and circulars. |
| **House system** | House points ledger, contributor records, standings, badges, House Arena, and house group. |
| **Student leadership** | Election workspace for eligible roles, claims review for authorised captains and council members, and event tools for authorised users. |
| **Staff administration** | Class and section rosters, placement verification, promotion, timetable approval, claims and leave review, notices, events, and audit logs. |
| **Communication** | Direct messages, class groups, and house groups restricted to participants. |
| **Recognition** | Claim submission with evidence, staff review, point award, and notification. |
| **Events** | Staff event publishing, student RSVP, attendee counts, and event-wall posts. |
| **Data controls** | Protected profile fields, role-aware rules, and missing-data guards; see Section 10 for open authorization gaps. |

---

## 4. How to read the release status

Every module carries one of these labels. The labels describe implementation and release status, not marketing readiness.

| Status | Meaning |
|---|---|
| **GATED** | Implemented and locally tested, but one or more open audit findings block release. No live school data. |
| **PILOT** | Interactive demonstration using sample, local, or manual data. Not authoritative. |
| **ACTIVATION** | The app-side experience is built. A required school IT service is not deployed. |
| **ROADMAP** | Planned enhancement, not present in this build. |
| **READY** | Target state: implemented, locally tested, and no open release-blocking finding. **Not assigned to any module as of 26 November 2026.** |

> **Release note.** No module is production-cleared. The 26 November 2026 audit found 23 critical/high and 21 medium/low findings. Section 10 summarises the themes and the five gates that must close before a live pilot. The companion deep audit records the full findings and evidence.

---

## 5. Complete feature catalogue

### 5.1 Identity, onboarding, and account access

**Purpose:** Provide role-aware sign-in and account access while protecting school identity data.

**Features**

- **Branded first-run onboarding** introduces the app, the house system, and the main student services.
- **Scholar-number sign-in** lets students use their school number and password without exposing an internal email format.
- **Password reset by scholar number** sends reset instructions through the school's Firebase Authentication setup.
- **Saved accounts** let shared-device users return to an existing profile, with **verified re-authentication** before a live account switch.
- **Student registration** captures full name, age, class, division, and house, and writes an unverified student profile for staff review.
- **Reserved administrator identity protection** blocks self-registration of the protected school-administrator identifier.
- **Role-aware routing** sends students, staff, and administrators to the correct experience after sign-in.
- **Profile and house caching** keeps the interface coherent when the device briefly loses connectivity.
- **Theme preference persistence** remembers the user's light or dark choice.
- **Protected profile fields** prevent a student from rewriting their role, points, scholar number, house, grade, class, or verification status after creation; scholar ownership itself is not yet verified (O02).

**Status:** **GATED** — the account and onboarding UI is built, but the identity model is not release-safe.

> **Audit note.** Critical: an unverified token carrying the protected administrator email can obtain administrative access without a profile (O01); a new account can claim another student's scholar number and read that student's record (O02). High: suspension is not enforced consistently (O04), saved-account switching can restore stale roles (O05), and cached records are not fully cleared between accounts (O06). Do not use live accounts.

---

### 5.2 Home dashboard and navigation

**Purpose:** Provide the app's main entry point for the dashboard, store, standings, profile, notices, and service navigation.

**Features**

- **Four primary tabs:** Dashboard, Store, Standings, and Profile.
- **Role-aware navigation drawer** exposes academics, claims, events, elections, sports, notifications, scanner, AI assistant, library, and administration tools only where appropriate.
- **House-coloured greeting** with the student's name, house, points, and current standing.
- **Service cards** for the major modules, each with a clear label and status.
- **Notice ticker and notice feed** for school-wide announcements.
- **Event Wall preview** highlights recent campus activity.
- **Unread notification badges** keep attention on new items without interrupting the user.
- **Student profile modal** gives a quick view of identity, house, class, points, and recognition.
- **Cached dashboard states** keep the home screen useful when live data is temporarily unavailable.
- **Consistent empty and error states** explain what is missing instead of showing blank panels.

**Status:** **GATED** — the dashboard renders, but it depends on identity and notice feeds that are not release-safe.

> **Audit note.** Dashboard composition is locally tested. Sign-in is blocked by O01 and O02; notice content is not authenticated (O07); Firebase initialization can fall back to demo behaviour on failure (O36). Use synthetic data only.

---

### 5.3 Houses, standings, and spirit

**Purpose:** Provide house points, contributors, standings, badges, spirit screens, and house groups.

**Features**

- **Four houses** — Ruby, Sapphire, Emerald, and Topaz — each with its own colour and emblem.
- **House points ledger** records earned points by house.
- **Contributor records** show which scholars earned points and why.
- **Standings screen** presents total points, category points, sports points, podium placement, and top contributors.
- **House Arena** with a spirit gauge, spirit reactor, blitz quiz, cup oracle, badge vault, and honours.
- **Badges** for participation and achievement.
- **3D mascot stage** for each house.
- **House-specific battle chant synthesiser.**
- **Confetti and celebration effects** for points, badges, and house milestones.
- **House group chat** gives each house a private coordination space.

**Status:** **GATED** — display and house-group UI are built; the points ledger is not authoritative. The quiz, cup oracle, and spirit animations are **PILOT** engagement experiences.

> **Audit note.** Award writes are not atomic or idempotent (O14, O15); house, contributor, and user totals can diverge. Conduct revocation does not consistently reverse totals (O17), and a first demerit can produce a negative contributor value rejected by the schema (O18). Treat standings as display-only until the award ledger is server-owned.

---

### 5.4 Academics

**Purpose:** Provide student academic information and staff academic tools in one module.

**Features**

#### Structure and placement

- **Academic structure management** for grades, sections, divisions, class IDs, and rosters.
- **Placement verification** lets administrators confirm that a student belongs to the correct class.
- **Promotion tools** move students to the next academic level with an audit record.
- **Section creation and house/status/transfer controls** in the administration console.

#### Timetable

- **Student timetable view** by day and period, with subject, teacher, room, and timing.
- **Teacher timetable editor** for creating and updating periods.
- **Cross-class conflict preflight** warns about teacher or room double-booking before publishing.
- **Timetable approval workflow** supports editing permissions, approval, and rejection.
- **Timetable images and circulars** can be attached to academic records.

#### Homework and assignments

- **Assignment publishing** with title, description, subject, due date, and reference image.
- **Student submission workflow** with pending, submitted, and graded states.
- **Grading and merit awards** with role verification and reviewer-attributed point crediting, subject to the scoring gate.
- **Submission tracking per scholar** so one student's status does not overwrite another's.
- **Due-date countdown and filters** by subject and status.

#### Exams

- **Exam schedule** with paper, subject, date, time, hall, and desk allocation.
- **Syllabus revision vault** for topic checklists and revision guidance.
- **Exam hall and desk allocation** shown with each exam record.
- **Exam-in-progress indicators** and academic image attachments.

#### Report cards

- **Term report cards** with subject breakdown, marks, percentages, and overall GPA.
- **Honours and merit summaries** for academic distinction.
- **PDF export** for sharing and printing.
- **Year-aware report-card records** keep terms from different academic years distinct.

#### Attendance and leave

- **Daily attendance** with present, absent, and late states.
- **Period-level attendance breakdown** for partial-day records.
- **One shared attendance policy** across the app: `present + excused + 0.5 × late`.
- **CBSE 75% compliance indicator** with an explicit "No attendance data" state instead of a misleading 100%.
- **Medical leave requests** with reason, dates, supporting document, and admin review.
- **Leave policy clarity:** approved leave does not silently convert an absence into attendance.

#### Circulars and class communication

- **School circular composer** with title, body, audience, PDF attachment, and publish action.
- **Base64 fallback** for smaller attachments when Cloud Storage is not yet enabled.
- **Class group chat** tied to verified class placement.

**Status:** **GATED** — timetable, homework, exams, report cards, attendance, leave, and circulars are built; honours, promotion, and concurrent timetable edits are not release-safe.

> **Audit note.** Honours eligibility is client-derived (O16); promotion is sequential and partially applied on failure (O31); timetable conflict checks are read/check/write (O30); large inline attachments can exceed Firestore's document limit (O34); malformed records can fail a whole stream (O35). Large PDF attachments also require **ACTIVATION** of Cloud Storage.

---

### 5.5 Claims and recognition

**Purpose:** Record student achievement and conduct with evidence, review, points, and notifications.

**Features**

- **Claim submission** with activity title, requested points, house, and supporting certificate image or PDF.
- **Evidence upload** to Cloud Storage with an inline Base64 fallback for small files.
- **Review queue** for administrators, council members, and authorised house captains.
- **Approve or reject** with a reason, point award, and automatic student notification.
- **Approved-claims gallery** with certificate preview.
- **Immutable claim identity** — the activity, points, house, and evidence cannot be rewritten after submission.
- **AI review metadata** fields for status, confidence, markers, and summary when the Storage trigger is enabled.
- **Student conduct records** for merit and demerit entries with reasons, point ranges, evaluator identity, and revocation.
- **Conduct notifications** keep students informed of recognition or correction.

**Status:** **GATED** — the claim and conduct UI is built, but claim trust and point posting are not release-safe.

> **Audit note.** Claim creation accepts caller-supplied AI verification metadata, `auto_validated`, and a different house (O08). Storage access is broad, claim filenames are overwritable, and identity is derived from filenames (O09). Point awards are not atomic or idempotent (O14, O15). AI-assisted verification remains **ACTIVATION** and is not a signature check.

---

### 5.6 Campus events

**Purpose:** Manage staff-created events, audience eligibility, student RSVPs, and an event wall.

**Features**

- **Staff event composer** with draft, preview, publish, edit, and cancel actions.
- **Audience targeting** by whole school, individual house, or grade range.
- **Student event feed** showing published events that match the student's eligibility.
- **Event detail view** with venue, time, category, description, and organiser.
- **RSVP registration** with one response per student and live attendee counts.
- **Event Wall** for images, captions, and campus highlights.
- **Sample event mode** for training and demonstrations without touching live data.
- **Rules-enforced published, house, author, and cancellation checks**; grade eligibility still trusts caller fields (O33).

**Status:** **GATED** — event lifecycle and RSVP are built; eligibility trusts caller profile fields.

> **Audit note.** An account without a grade or profile can register for a senior-only event (O33). Event creation, house scope, and cancellation are rules-enforced, but attendee identity and eligibility need server-derived values before live use.

---

### 5.7 Notifications

**Purpose:** Deliver in-app notices and alerts with read state, priority, and per-category counts.

**Features**

- **In-app notification centre** with categories, priority, and timestamps.
- **Read and unread states**, per-category unread totals, and a dashboard badge.
- **Mark all as read** and **clear all** actions.
- **Deterministic deduplication** so retries do not create duplicate alerts.
- **Fan-out for school notices, timetable changes, house and class announcements, chat alerts, and points awards.**
- **High-priority styling** for urgent items.
- **Admin notice publishing** from the dashboard and administration tools.

**Status:** **GATED** — in-app delivery works; notice authenticity is not enforced.

> **Audit note.** Any signed-in user can create official-looking notifications for another user (O07); refresh and control messages carry equivalent risk. Background push is **ACTIVATION** and has no client token lifecycle or backend delivery (O43). Do not treat in-app notices as official until sender authorization is fixed.

---

### 5.8 Chat and groups

**Purpose:** Provide participant-only direct messages, class groups, and house groups.

**Features**

- **Direct messages** between students and authorised staff or council members.
- **Deterministic conversation rooms** so the same two users always reach the same thread.
- **Class group chats** for verified class placements.
- **House group chats** for house coordination.
- **Unread counters and read receipts.**
- **Pinned and hidden conversation moderation** for staff.
- **Chat-linked notifications** for new messages.
- **Participant-only access** enforced by Firestore rules.
- **Honest privacy labelling** — the app describes conversations as private to participants, not as end-to-end encrypted.

**Status:** **GATED** — participant-only reads are hardened, but chat creation and photo messages are blocked by current rules.

> **Audit note.** New direct-chat creation is denied because the room read precedes creation (O27). Photo messages are rejected because `attachment_url` is not in the rule whitelist (O28). Peer authorization and missing-profile role fallbacks remain client-side (O29). Existing text threads are the only chat path verified.

---

### 5.9 Sports and trophies

**Purpose:** Record fixtures, match events, tournaments, trophies, and player statistics.

**Features**

- **Fixture scheduling** with sport, house, venue, date, and time.
- **Live match HUD** with score events, match timer, MVP selection, and player statistics.
- **Tournament brackets** and championship progression.
- **Trophy cabinet** with championship and runner-up records.
- **Victory certificates** exported as PDF.
- **House points integration** for winners and accolades.
- **Sports certification tokens** for staff-operated scoring and verification.
- **Sport-specific statistics** for players and teams.

**Status:** **GATED** — fixture and match UI is built; trophy and score writes are not release-safe.

> **Audit note.** The trophy payload sends `tournament_title` where rules require `title`, so the current model fails even for an administrator (O19). Score updates use stale absolute values and can lose concurrent changes (O20); broad catches can report local success after a live failure. Server-side match authority remains **ROADMAP**.

---

### 5.10 Elections and student leadership

**Purpose:** Provide an election workspace, eligibility rules, voting, participation receipts, audit records, and certified results.

**Features**

- **Election workspace** with draft creation, candidate management, publish, close, certify, cancel, and delete-draft actions.
- **Leadership roles** including House Captain, House Vice-Captain, Head Boy, Head Girl, Class Prefect, Sports Captain, and Cultural Secretary.
- **House and grade eligibility** so the right students stand for and vote in the right elections.
- **One scholar, one vote** enforced by a server-side transaction when the election service is enabled.
- **Participation receipts** let a student confirm that their vote was recorded without revealing the choice.
- **Audit log** for election actions and integrity checks.
- **Certified results gazette** for official proclamations.
- **Winner recognition** with house points and a published outcome.
- **Admin and council management tools** for the full election lifecycle.

**Status:** **ACTIVATION** — the management, voting, receipt, audit, and gazette experiences are built, but live voting is intentionally disabled until school IT deploys and verifies the server-side election service. This prevents unverified tallies from being presented as official results.

**Device note:** Election voting is not live. Any activated voting would require a school-approved device or supervised kiosk.

> **Audit note.** No Cloud Functions are deployed (O11). The backend contains privileged direct-write fallbacks, rules still permit lifecycle mutation outside the service (O10), and the audit UI path does not match the backend path (O12). A legacy direct-vote path remains and is denied by hardened rules. Election signing secrets are embedded in the client (O23). Live voting must remain disabled.

---

### 5.11 School store and orders

**Purpose:** Provide a merchandise catalogue, cart, order request, order history, and staff-recorded collection status.

**Features**

- **Ten-item merchandise catalogue** with house variants and BHD prices.
- **Product detail sheet** with size, quantity, and house selection.
- **Cart and favourites** with local persistence.
- **Checkout and order creation** with student identity, items, total, and collection status.
- **Order history** with claim status.
- **QR collection pass** for each order.
- **Staff scanner claim flow** that records who collected an order and when.
- **Truthful payment labelling** — orders are presented as requests pending office confirmation, not as completed payments.

**Status:** **GATED** — catalogue and cart are demo-ready; order creation and fulfillment are not trustworthy.

> **Audit note.** A student can create an order marked verified with arbitrary items and a zero price (O21). Voucher redemption is read-then-update and can double-fulfill (O22). Signing secrets are in the client and do not cover all item contents (O23). Orders are display requests only; do not accept payment or release goods based on the app.

**Collection note:** Orders are requests, not payments. Collection is managed by the school office; the app records the request and claim status only.

---

### 5.12 Digital passes and documents

**Purpose:** Provide pass and receipt previews with PDF export.

**Features**

- **Three pass tabs:** Store Passes, Campus ID, and Fee Receipts.
- **Campus ID card** with scholar number, house, class, points, and access tier.
- **QR identity pass** for in-app, staff-assisted verification; exported PDFs do not yet contain a scannable QR.
- **Store order passes** linked to order records.
- **Fee receipt view** clearly labelled as a sample and not linked to a billing system.
- **PDF export** for passes and receipts, with known QR, font, and sharing limitations.
- **Local pass preview** that explains the pass stays inside ASB House Hub.

**Status:** **PILOT** — preview and limited PDF export work; the export is not a scannable pass.

> **Audit note.** PDF export renders text payloads rather than a scannable QR and lacks robust pagination, Unicode fonts, sharing, and web delivery; mobile output is temporary (O24). In-app QR display works, but the signing secret is client-held (O23). Apple Wallet, Google Wallet, NFC, and live fee billing are not claimed and remain **ROADMAP**.

**Policy note:** The digital pass is an app preview and PDF export. It is not a school-issued ID and is not required for campus entry.

---

### 5.13 ID scanning and behaviour evaluation

**Purpose:** Provide staff-operated scanning, student lookup, voucher validation, and conduct recording.

**Features**

- **Staff-operated scanner** on supported devices.
- **Camera scanning** on supported mobile devices.
- **Image upload and decoding** when a live camera is unavailable.
- **Manual scholar-number lookup** as a reliable fallback.
- **Student pass validation** with QR signature checking.
- **Order and voucher validation** with staff claim confirmation.
- **Behaviour evaluation screen** for merit and demerit entries.
- **Structured reasons and point ranges** from 1 to 100.
- **Evaluator identity and record revocation** for accountability.
- **Conduct notifications** to the affected student.

**Status:** **GATED** — staff scanning and conduct UI is built; storage ownership and voucher signing are not release-safe.

> **Audit note.** Storage rules allow broad authenticated access, claim filenames are overwritable, identity is derived from filenames, and processing is not idempotent (O09). Voucher and pass signing secrets are in the client (O23). Conduct revocation can delete before reversing totals (O17). The scanner is a staff tool; student QR passes are not a school ID or campus-entry requirement.

**Device note:** The scanner is a staff tool. Student QR passes can be exported to PDF for printing.

---

### 5.14 Library

**Purpose:** Provide a library portal with loan cards, renewal preview, and local cache while the backend service is prepared.

**Features**

- **Library portal** from the home screen.
- **Borrowed-book cards** with due-day counters and renewal counts.
- **Renewal action** that extends the displayed loan period.
- **Local cache** so the portal remains available between sessions.
- **Server-side library service** authored for transactional checkout, return, and renewal against library holdings.

**Status:** **PILOT** — the portal uses sample and legacy loan data; no end-to-end lending.

> **Audit note.** The UI retains sample and legacy loan paths while `functions/library-v2.js` uses a separate v2 schema. Missing v2 read rules, catalog provisioning, and a connected UI prevent an end-to-end lending system (O13). The transactional backend requires **ACTIVATION**. Student access is outside school hours under the device policy.

---

### 5.15 House AI assistant

**Purpose:** Provide an optional AI chat with house-aware prompts, Gemini integration, and local fallback guidance.

**Features**

- **House AI chat screen** with house-aware styling and suggested prompts.
- **Prompt shortcuts** for timetable, attendance, homework, house rank, sports, exams, and the battle chant.
- **Gemini integration** using a school-provided or user-entered API key.
- **Local fallback guidance** when no key is configured or the network is unavailable.
- **API-key settings and connection status** visible to the user.
- **Academic context** drawn from the same attendance, timetable, and house data as the rest of the app.

**Status:** **PILOT** — optional AI chat with local fallback; not approved for real student data.

> **Audit note.** Fallback model IDs are deprecated (O25). API keys are persisted locally and placed in request URLs; context can include synthetic scholar and grade values (O26). A school-provided server-side proxy is required before real use. Student access is outside school hours under the device policy.

---

### 5.16 Administration and governance

**Purpose:** Provide administration tools for academics, recognition, communication, events, and student leadership.

**Features**

#### Academic administration

- **Class and section creation.**
- **Roster placement verification.**
- **Student promotion.**
- **Timetable approval and rejection.**
- **House, status, and transfer controls.**
- **Administrative audit log.**

#### Claims and conduct administration

- **Pending claims queue** with evidence review.
- **Medical leave queue** with approval, rejection, and remarks.
- **Approved-claims gallery.**
- **Roster management and role assignment.**
- **Student conduct records** with revocation history.

#### Communication and campus life

- **Notice and circular composer** with audience targeting and publish action.
- **Campus event lifecycle management.**
- **Election management, audit, and gazette tools.**
- **Sports fixture, result, and trophy administration.**

#### Governance and access control

- **Role-aware hierarchy** for super administrators, senior administrators, faculty, captains, council members, and students.
- **Rules-level authorisation** for administrative collections.
- **Protected profile fields after creation** and roster self-provisioning checks; scholar ownership remains open (O02).
- **Audited points and conduct changes.**
- **Fail-closed academic and points writes** when class, house, or scholar data is missing.
- **Separate staff and student experiences** from the same app.

**Status:** **GATED** — administration UI is built; authority and record integrity are not release-safe.

> **Audit note.** Administrative authority still depends on the accepted bootstrap exception (O01) and scholar self-provisioning (O02). Suspension is not enforced centrally (O04); role definitions differ across hierarchy, Firestore, Storage, and membership provisioning (O44). Promotion is partial (O31); election fallbacks remain (O10). Named administrator accounts, MFA, and server-side roster authority are **ROADMAP**.

---

## 6. Role-based experience

The matrix describes intended permissions. The audit found role definitions differ across layers (O44), suspension is not centrally enforced (O04), and scholar identity is not bound to a trusted roster (O02). Treat the matrix as a design target, not verified production access control.

| Capability | Student | Teacher / Faculty | Captain / Council | Administrator |
|---|:---:|:---:|:---:|:---:|
| Branded dashboard and notices | ✓ | ✓ | ✓ | ✓ |
| Timetable, homework, exams, report cards | ✓ | ✓ | ✓ | ✓ |
| Attendance record and medical leave | View / request | Review | Review | ✓ |
| House standings and contributors | ✓ | ✓ | ✓ | ✓ |
| Submit a house-point claim | ✓ | — | ✓ | ✓ |
| Review and approve claims | — | ✓ | ✓ | ✓ |
| Publish events and notices | — | ✓ | Scoped | ✓ |
| RSVP to campus events | ✓ | ✓ | ✓ | ✓ |
| Direct and group chat | ✓ | ✓ | ✓ | ✓ |
| Live sports scoring and trophies | View | ✓ | ✓ | ✓ |
| Stand for election | ✓ | — | ✓ | — |
| Vote in an election (activation-dependent) | ✓ | — | ✓ | — |
| Manage election lifecycle | — | — | Scoped | ✓ |
| Student conduct evaluation | View own | ✓ | ✓ | ✓ |
| Staff scan passes and claim orders | — | ✓ | ✓ | ✓ |
| View or export own pass | ✓ | ✓ | ✓ | ✓ |
| Academic administration and promotion | — | — | — | ✓ |
| Role assignment and audit review | — | — | — | ✓ |

*Student access to the app is outside school hours. Election voting is not live and would require a school-approved device or supervised kiosk if activated. Scoped means the action is limited to the user's house, class, or delegated capability.*

---

## 7. Student-facing capabilities

Student accounts provide the following implemented functions. They are available outside school hours on a personal device, subject to school and family policy. This is not a production service; several paths are blocked by the audit findings noted below.

### Account and profile

- Branded onboarding.
- Scholar-number sign-in and password reset.
- Saved accounts with re-authentication before a live account switch.
- Profile view with house, class, points, and recognition.
- Light and dark theme preference.

### Academics

- Timetable by day and period.
- Homework list, submission, and status.
- Exam schedule, hall and desk allocation, and revision checklist.
- Term report cards with GPA, honours, and PDF export.
- Attendance record and CBSE 75% indicator.
- Medical leave request with supporting document.
- Circulars and class group.

### Houses

- House points, standing, contributor list, and badges.
- House Arena and house group.

### Recognition and conduct

- Claim submission with supporting evidence.
- Claim status and approved-claims gallery.
- Notifications for points and conduct decisions.
- Own conduct record.

### Events and communication

- Event feed, RSVP, and event wall.
- Direct messages, class groups, and house groups.

### Services

- Merchandise catalogue, cart, order request, and order status.
- Pass and receipt preview with PDF export.
- Library portal with sample data in the pilot.
- Optional AI assistant.
- Election screens where the server service is activated; not live today.

### Known limits

- New direct-chat creation and photo messages are rejected by current rules (O27, O28).
- Pass PDF export is text-based and not a scannable QR; web export is unsupported (O24).
- Order totals are not server-verified (O21).
- AI keys are stored locally and are not approved for real student data (O26).
- Election screens are not live.
- No module is production-cleared as of 26 November 2026.

### Not provided

- No campus-entry pass.
- No in-app payment.
- No live election result.
- No official library transaction during the pilot.
- No Apple Wallet, Google Wallet, or NFC support.

---

## 8. Design, accessibility, and platform support

### Visual design

- **House-led colour system** across screens.
- **Light and dark themes.**
- **Cards, badges, and status pills** for status and information.
- **Motion** for celebrations, transitions, and progress indicators.
- **School branding and house mascots.**
- **Responsive layouts** for mobile screens, desktop windows, and web.

### Accessibility (implemented, not certified)

- **Semantic labels** for key controls, tabs, cards, and status indicators.
- **Minimum 48 dp touch targets** for primary actions.
- **Large-font checks** for critical action rows.
- **Keyboard and focus support** for desktop and web use.
- **Clear empty, loading, and error states** instead of silent failure.
- **No raw exception text** exposed to students in the global error screen.
- **Reduced reliance on colour alone** for important status information.

Accessibility has not been certified or tested with assistive technology. Localization and RTL coverage are incomplete (O41).

### Supported platforms

| Platform | Support |
|---|---|
| **Android** | Student access outside school hours; staff scanner and notification centre on supported devices |
| **iOS** | Student access outside school hours; staff scanner and notification centre on supported devices |
| **Windows** | Desktop access to the app |
| **Web** | Browser access to the app |

Platform support describes where the app can run. Student access remains outside school hours.

Windows and web release builds pass. Android and iOS release builds were not produced; Android release configuration still uses debug signing and the iOS deployment target is below the installed FlutterFire pod requirements (O38). Camera, notifications, and scanning therefore remain unverified on physical mobile devices.

---

## 9. Security design and open findings

The code applies a **role-aware, least-privilege** model, but the 26 November 2026 audit found critical and high-severity gaps. This section describes the intended controls and the audit position. It is not a security assurance.

| Area | Implemented control | Audit position |
|---|---|---|
| **Identity** | Firebase Authentication; protected administrator identifier; re-authentication before account switching. | **Critical:** unverified bootstrap administrator path (O01); scholar numbers are not bound to a trusted roster (O02). **High:** suspension (O04), stale roles (O05), cache isolation (O06). |
| **Authorization** | Role-based rules for students, faculty, captains, council, and administrators. | **High:** forged notifications (O07); caller-supplied claim verification (O08); role definitions differ across layers (O44). |
| **Storage** | Staff and administrator write restrictions for exam schedules and circulars. | **High:** broad authenticated reads, overwritable claim filenames, filename-derived identity, non-idempotent processing (O09). |
| **Elections** | Direct client writes to counts and participation are denied. | **High:** no deployed service (O11); privileged backend fallbacks (O10); legacy vote path and client signing secret (O23). **Medium:** audit path mismatch and batch limit (O12). |
| **Scoring and conduct** | Points, contributors, and conduct entries carry reviewer identity. | **High:** non-atomic and non-idempotent awards (O14, O15); client-derived honours (O16); incomplete revocation (O17). **Medium:** negative contributor edge case (O18). |
| **Orders and vouchers** | Unsigned legacy order payloads are rejected; orders are labelled requests. | **High:** zero-price verified orders (O21); double redemption (O22); client signing secret and incomplete payload binding (O23). |
| **Sports and timetable** | Fixture, score, trophy, and approval workflows are built. | **High:** trophy schema mismatch (O19); lost concurrent score updates (O20). **Medium:** timetable conflict race (O30). |
| **Chat** | Participant-only room and message reads; read receipts require participation. | **Medium:** new-room creation denied (O27); photo message schema rejected (O28); peer policy client-side (O29). |
| **Platform** | Firebase Authentication, Firestore, and Storage integration. | **High:** implicit demo fallback on initialization failure (O36); no App Check client (O37); debug signing and iOS target (O38). |

### Privacy posture

- Chat is described as **private to participants**, not as end-to-end encrypted.
- Fee receipts are clearly labelled as samples and are not presented as paid billing records.
- Store orders are labelled as unverified requests until the school confirms payment.
- Digital passes are local previews and are not presented as Apple Wallet, Google Wallet, NFC credentials, or a campus-entry requirement.
- Library loans are labelled as sample data during the pilot.
- AI keys and prompts are not approved for real student data (O26).
- Student access is outside school hours.

### What is not claimed

- No production security certification, penetration test, or accessibility certification.
- No end-to-end encryption.
- No official election result.
- No payment, wallet, NFC, or campus-entry credential.
- No claim that passing tests close the audit findings.

---

## 10. Audit results, quality, and release gates

### Current release decision

**Not cleared for production.** The deep code audit dated 26 November 2026 covered baseline `9d0a559` and produced local repair commit `0beb87b` on branch `mustafa1`. It repaired 12 independently reproducible faults locally (F01–F12), but **23 critical/high findings** and **21 medium/low findings** remain open. No Cloud Functions are deployed. Live Firestore rules, indexes, Storage, billing, and production data were not verified. The build is suitable for code review and synthetic-data demonstration only.

> **Release rule.** No live student, staff, medical, payment, or election data should be entered until gates G1–G3 are closed and independently verified. Passing analysis, tests, and desktop builds do not make this a production release.

### Verification results

| Check | Result |
|---|---|
| Flutter static analysis | No issues |
| Flutter test suite | **685 of 685 passing** |
| Firestore rules and election handler emulator suite | **13 of 13 passing** |
| Backend JavaScript syntax | 3 modules pass |
| Windows release build | Pass |
| Web release build | Pass; CupertinoIcons font warning remains |
| npm dependency audit | 10 moderate, 0 high, 0 critical (including development dependencies) |
| Live Cloud Functions | **None deployed** |
| Android and iOS release builds | Not produced |
| Storage, App Check, and deployed integration tests | Not completed |

**Verification limits.** No physical-device testing, accessibility certification, penetration test, Storage emulator suite, or deployed HTTP/Auth/App Check integration test was completed. Backend tests ran on host Node 24; deployment is pinned to Node 22, whose parity is unverified. Flutter dependency inspection found 71 outdated entries; no current advisory, retracted, or discontinued flags were observed, but outdated is not the same as safe.

### Remaining findings by theme

| Theme | References | Release effect |
|---|---|---|
| Identity and account access | O01–O06, O44 | Critical administrator bootstrap and scholar impersonation; suspension, stale roles, cache isolation. |
| Trusted notifications, claims, and files | O07–O09 | Forged notices; self-asserted claim verification; broad Storage access and overwritable evidence. |
| Authoritative scoring and conduct | O14–O18 | Non-atomic awards; no idempotency; honours and revocation inconsistencies. |
| Elections | O10–O12, O23 | No deployed service; privileged fallbacks; legacy vote path; path mismatch; client secret. |
| Orders, vouchers, and passes | O21–O24 | Zero-price orders; double redemption; client signing secret; non-scannable PDF export. |
| Sports and timetable | O19, O20, O30 | Trophy schema mismatch; lost concurrent updates; timetable reservation race. |
| Client and platform security | O03, O23, O25, O26, O36–O38 | Embedded secrets; local AI keys; implicit demo fallback; debug signing; iOS target mismatch. |
| Chat, events, and data limits | O27–O29, O32–O35, O40, O41 | Broken chat paths; event eligibility; pagination and document-size limits; malformed decoding; accessibility and localization. |
| Backend and operations | O11–O13, O37, O39, O42, O43 | No Functions, Storage setup, App Check, index manifest, FCM delivery, or complete CI gate. |

The companion [deep audit](ASB_HOUSE_HUB_DEEP_AUDIT_2026-11-26.md) records each finding, source entry point, severity, evidence, and required follow-up. Synthetic probes confirmed several authorization gaps and also rejected legitimate chat, photo-message, and trophy payloads; the probe results are diagnostic, not passing security assertions.

### Release gates

| Gate | Scope | Exit criteria | Status |
|---|---|---|---|
| **G1 — Identity and access** | O01–O06, O44 | Remove the bootstrap bypass; bind scholar identity to a trusted enrollment roster; enforce suspension centrally; purge scoped caches; publish one role contract. | **OPEN** |
| **G2 — Trusted records** | O07–O11, O14–O23 | Server-own notification, claim, Storage, award, order, voucher, and election authority; make transitions atomic and idempotent; remove local-success fallbacks. | **OPEN** |
| **G3 — Backend deployment** | O11–O13, O25, O37, O42, O43 | Deploy Functions on Node 22 and verify parity; initialize Storage; publish rules and indexes; stage App Check; verify FCM; run live integration tests. | **OPEN** |
| **G4 — Client and platform** | O03, O23–O26, O36–O38 | Move secrets to platform-backed storage; remove embedded signing keys; configure release signing and iOS targets; complete export and sharing or withdraw the claim. | **OPEN** |
| **G5 — Verification and operations** | O32–O35, O39–O41, O44 | Add pagination and aggregate limits; isolate corrupt records; run emulator and transport tests in CI; complete accessibility and localization review; add monitoring, backups, and dependency review. | **OPEN** |

### What the audit does not change

The feature inventory in Section 5 remains useful for review: it shows what has been built. The audit changes the release decision, not the description of the screens. A module marked **GATED** may be demonstrated with synthetic data, but it is not approved for live school data.

---

## 11. Deployment readiness and phased rollout

### Current deployment state

| Component | State |
|---|---|
| Cloud Functions | **None deployed** (read-only inventory) |
| Firestore rules | Hardened locally; not published or verified live |
| Storage | Bucket not initialized; rules not emulator-tested |
| Indexes | No committed manifest (O42) |
| App Check | No client integration (O37) |
| Push delivery | No FCM token lifecycle or backend delivery (O43) |
| Payments | Not enabled |
| Android and iOS release builds | Not produced; signing and target issues open (O38) |

### Stage 0 — Current: local build and synthetic demonstration

**Goal:** Review the feature set and reproduce audit findings without live data.

**Allowed:** local builds, synthetic emulator data, code review, and a UI walkthrough.

**Not allowed:** live student, staff, medical, payment, or election data; production deployment; official notices or results.

### Stage 1 — Remediation and closed evaluation (G1–G2)

**Goal:** Close the identity and trusted-record gates.

**Work:** identity binding, suspension enforcement, cache isolation, notification and claim authorization, Storage ownership, atomic scoring, order and voucher authority, election fallback removal, and chat, sports, and timetable schema fixes.

**Exit:** adversarial emulator tests pass; no critical/high finding remains open; the administration reviews the evidence.

### Stage 2 — Backend deployment and verification (G3)

**Goal:** Make the hardened model operational.

**Work:** deploy Functions on Node 22; initialize Storage; publish rules and indexes; stage App Check; configure FCM; run live integration tests; confirm monitoring and backups.

**Exit:** the live environment is verified with synthetic accounts; callable services respond; rules, indexes, and Storage are confirmed.

### Stage 3 — Supervised pilot (conditional)

**Goal:** Validate staff workflows and out-of-school student access with a representative group. This stage may begin only after G1–G3 are closed and verified.

**Included:** identity, dashboard, academics, houses, claims, events, in-app notifications, chat, staff scanner, digital pass previews, and administration consoles.

**Device policy:** student participation is outside school hours; staff use school-authorised devices.

**School IT actions:**

1. Confirm administrator and staff accounts under the approved role contract.
2. Seed the pilot roster, classes, timetable, and house allocations.
3. Confirm the deployed rules, Functions, Storage, and indexes remain verified.
4. Provide a named IT contact and an administrative sponsor.

**Success looks like:** staff can publish and review records; students can access their academic and house information outside school hours; the administration can review participation data without manual spreadsheets.

### Stage 4 — Activated services and scale (G4–G5)

**Goal:** Strengthen client, verification, and operational assurance, then enable optional services.

| Capability | Dependency |
|---|---|
| Large circular and claim attachments | Firebase Cloud Storage bucket |
| Live server-verified elections on school-approved devices | Deployed election Cloud Function |
| Library checkout, return, and renewal | Deployed library Cloud Function |
| Background push notifications | Firebase Cloud Messaging |
| Online merchandise payment | Approved payment gateway |
| Secure AI proxy | Server-side Gemini proxy |
| Server-authoritative notifications | Cloud Function fan-out |

**Scale work:** release signing and iOS targets, platform-backed secret storage, App Check enforcement, pagination and aggregate limits, accessibility and localization review, CI with emulator and transport tests, monitoring, backups, and dependency review.

---

## 12. Proposed pilot and success measures (conditional)

A live pilot is **conditional on gates G1–G3**. Until those gates close, only a closed, synthetic-data walkthrough is proposed. No student or staff should use the app with live school records before then.

### Pilot shape

| Item | Proposal |
|---|---|
| **Prerequisites** | G1–G3 closed and verified; no critical/high finding open; administration sign-off |
| **Duration** | Four school weeks |
| **Participants** | One grade and one house, plus the staff who support them |
| **Device policy** | Student participation is outside school hours; staff use school-authorised devices. |
| **Administrative sponsor** | A member of senior leadership |
| **Technical contact** | School IT or the app maintainer |
| **Training** | One staff orientation session and written student/family guidance; no device use during school hours |
| **Support** | In-app guidance, a shared feedback form, and a weekly review |

### Suggested success measures

| Measure | Target |
|---|---|
| Weekly active students in the pilot group (outside school hours) | 70% or higher |
| Students viewing timetable or homework each week (outside school hours) | 90% or higher |
| Claims submitted and reviewed | At least 50 with a median review time under 2 school days |
| Event RSVP conversion | 80% of eligible students respond to at least one event |
| Attendance visibility | 95% of pilot students can access a current attendance record |
| Support requests | Fewer than 2% of pilot users per week |
| Student satisfaction | 4 out of 5 or higher |
| Staff satisfaction | 4 out of 5 or higher |

### Decision gate

At the end of the pilot, the administration reviews out-of-school usage, feedback, support load, and the Stage 4 activation checklist. A wider rollout is recommended only after the pilot targets are met and gates G4–G5 are closed.

---

## 13. Product roadmap

The roadmap starts with the audit gates. Feature additions follow only after the release-blocking work is complete.

| Priority | Work | Gate or dependency |
|---|---|---|
| 1 | Remove the bootstrap bypass; bind scholar identity to a trusted roster; enforce suspension; purge scoped caches | G1 |
| 2 | Server-own notifications, claims, Storage, awards, orders, vouchers, and election authority; make transitions atomic and idempotent | G2 |
| 3 | Align chat, sports, timetable, honours, promotion, and conduct schemas; remove local-success fallbacks | G2 |
| 4 | Deploy Functions on Node 22; initialize Storage; publish rules and indexes; stage App Check; verify FCM | G3 |
| 5 | Configure Android release signing and iOS deployment targets; move secrets to platform-backed storage; complete pass export and sharing | G4 |
| 6 | Add pagination, aggregate document limits, corrupt-record isolation, and error reporting | G5 |
| 7 | Add emulator and transport tests to CI; complete accessibility and localization review | G5 |
| 8 | Add monitoring, backups, recovery testing, budget alerts, and dependency review | G5 |
| 9 | Run the conditional supervised pilot for one grade and one house | After G1–G3 |
| 10 | Deploy the library service and replace sample loans | After pilot |
| 11 | Enable background push notifications and a secure AI proxy | After pilot |
| 12 | Add online payment or an official pay-at-office flow | After pilot |
| 13 | Introduce named administrator accounts, MFA, and server-side roster authority | Governance phase |
| 14 | Enable official elections on school-approved devices, if adopted | Election service verified |

---

## 14. Submission pack and approval request

### Documents in this submission

1. **ASB House Hub — Feature Catalogue & Release Readiness Review** (this document)
2. **Deep Code Audit, 26 November 2026** — 12 local repairs (F01–F12), 44 open findings (O01–O44), evidence, and synthetic probe results
3. **Source code** — Flutter application, Firebase rules, Cloud Functions, and automated tests
4. **Verification summary** — static analysis, 685 automated tests, 13 emulator tests, Windows and web builds, and dependency audit
5. **Release gate and remediation plan** — the gates and staged rollout described in Sections 10 and 11

### Approval requested

The administration is invited to:

1. **Note the current release position:** the application is not approved for production or live school data.
2. **Approve a closed, synthetic-data technical walkthrough** for code review and feature demonstration.
3. **Nominate an administrative sponsor and a technical contact.**
4. **Approve the remediation plan and gate reviews** in Section 10.
5. **Authorize school IT to prepare deployment only after G1 and G2 close.** No live pilot should begin until G1–G3 are verified.

### What the school receives

- The application and its automated test suite.
- A feature catalogue that states what is built, what is gated, and what needs activation.
- The deep audit, including reproducible evidence and known-gap probes.
- A release gate plan with explicit exit criteria.
- A conditional pilot framework with measurable success criteria.
- A roadmap that starts with remediation, not feature expansion.

---

## 15. Appendix: module summary

| # | Module | Primary users | Status and open references |
|---|---|---|---|
| 1 | Identity, onboarding, and account access | All | **GATED** — O01–O06, O44 |
| 2 | Home dashboard and navigation | All | **GATED** — O01, O02, O07, O36 |
| 3 | Houses, standings, and spirit | Students, staff | **GATED** — O14–O18 |
| 4 | Academics | Students, teachers, admin | **GATED** — O16, O30, O31, O34, O35 |
| 5 | Claims and recognition | Students, staff, captains | **GATED** — O08, O09, O14–O18 |
| 6 | Campus events | All | **GATED** — O33 |
| 7 | Notifications | All | **GATED** — O07, O43 |
| 8 | Chat and groups | Students, staff | **GATED** — O27–O29 |
| 9 | Sports and trophies | Students, staff | **GATED** — O19, O20 |
| 10 | Elections and student leadership | Students, council, admin | **ACTIVATION** — O10–O12, O23 |
| 11 | School store and orders | Students, admin | **GATED** — O21–O23 |
| 12 | Digital passes and documents | Students, staff | **PILOT** — O23, O24 |
| 13 | ID scanning and behaviour evaluation | Staff, captains | **GATED** — O09, O17, O23 |
| 14 | Library | Students | **PILOT** — O13 |
| 15 | House AI assistant | Students | **PILOT** — O25, O26 |
| 16 | Administration and governance | Administrators | **GATED** — O01, O02, O04, O10, O31, O44 |

**No module is production-cleared as of 26 November 2026.** **READY** is the target state and is not currently assigned.

---

*Prepared for the Administration of The Asian School, Bahrain.*

*ASB House Hub · Version 1.0.1 (Build 2) · November 2026*
