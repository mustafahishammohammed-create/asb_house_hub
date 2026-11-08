# ASB Digital Campus — Remaining Modules Handoff Report

**Purpose:** one self-contained file describing every module still to build, exactly what each must do, what is already done vs. not done, and the robustness bar (security, rules, validation, tests) each must meet. Written so work can resume later with minimal re-exploration.

**Date:** 2026-11-08
**Baseline HEAD:** `d5ce809` (M1 academic foundation, committed + pushed).
**Uncommitted work in tree:** `lib/models/class_timetable.dart` + `test/class_timetable_test.dart` (M2a model, 18/18 tests pass — see §M2).
**Authoritative inputs:** the 12-section *MASTER DEVELOPMENT PROMPT — ASB DIGITAL CAMPUS* (64 acceptance tests in §11); the user's pasted *TEACHER-MANAGED RECURRING WEEKLY TIMETABLE SYSTEM* spec (M2 detail); `development_plan/MASTER_GAP_ANALYSIS.md` (module map M1–M8).

> Read this top-to-bottom once. Each module section is independent: Goal → Depends on → Current state → Requirements → Data/Service/Rules/UI → Tests → Robustness → Definition of done. The acceptance-test map (§Acceptance) and standing constraints (§Constraints) apply to all modules.

---

## 0. Current state snapshot

| Module | Status | Evidence |
|---|---|---|
| **M1 — Academic foundation** | ✅ **DONE** (committed `d5ce809`, pushed; rules deployed) | `lib/models/academic_class.dart`, `admin_academics_screen.dart`, registry + verification methods in `auth_service.dart`, `academic_classes` rules matcher, `test/academic_structure_test.dart` (29 tests) |
| **M2a — Timetable version model** | 🟡 **DRAFTED + TESTED, UNCOMMITTED** | `lib/models/class_timetable.dart`, `test/class_timetable_test.dart` (18/18 pass). Not wired to service/rules/UI yet. |
| **M2b–M2f — Timetable engine** | ❌ **NOT STARTED** | permissions, service, rules, UI, acceptance/deploy |
| **M3 — Timetable advanced** | ❌ **NOT STARTED** | double-booking, copy-to-days, temporary overrides, substitution |
| **M4 — House groups** | ❌ **NOT STARTED** | role-restricted send, students read-only |
| **M5 — Class groups** | ❌ **NOT STARTED** | per-class channel + announcements |
| **M6 — Notification engine** | ❌ **NOT STARTED** | in-app notifications (Spark) |
| **M7 — Admin Command Center expansion** | ❌ **NOT STARTED** | academic/teacher/house/group/user mgmt, approval queue, audit viewer, promotion |
| **M8 — Dashboard/profile + acceptance** | ❌ **NOT STARTED** | verified-class dashboard, full §11 suite |

**Separate, pre-existing workstreams (not part of M1–M8 but must not regress):**
- **Academics security audit:** P0 + P1 **CLOSED** (A1–A6, A8, and A4 *interim* hardening). P2 **OPEN** (A7 hygiene items P2-1..P2-5, A9 items P2-6/P2-7). A4 *end-state* (atomic merit claim) deferred to Blaze **D5**. See `academics_audit/REMEDIATION_ROADMAP.md`.
- **Elections / gamification / sports:** client + rules interim hardening **DONE and verified**; live server authority deferred to Blaze **D1–D5**. See `election_audit/BLAZE_REQUIRED_FEATURES.md`, `gamification_audit/REMEDIATION_ROADMAP.md`.

---

## Constraints (standing — apply to every module)

1. **Firebase Spark (free) only.** No Blaze. `firebase deploy --only functions` fails on Spark. Anything needing Cloud Functions / server transactions / server fan-out is **deferred**, not built now. Rules + Storage-rules deploy is free and allowed. Track every Blaze-only item in `election_audit/BLAZE_REQUIRED_FEATURES.md` (D1–D5 + the M6/M7 server items noted below).
2. **Medical leave NEVER excuses attendance.** A scholar with a submitted *or* approved leave is still marked **absent**. The "leave → excused-attendance automation" idea is **cancelled** — do not build it. (User-confirmed 2026-11-08.)
3. **Preserve working functionality.** Do not break elections, gamification/points, sports, wallet, merch, ID scanner, behavior evaluation, existing 1-to-1 chat, auth/account-switching, shipped academics fixes (A1–A6, A8), or the photo-upload feature. Extend, don't replace wholesale.
4. **No fake data, no placeholder/non-functional buttons, no frontend-only permissions.** Every restriction enforced in **Firestore rules** AND tested via direct rules denial, not just UI hiding. (Spec §12.)
5. **Secret handling:** never reproduce secret values (`ELECTION_HMAC_SALT`, `VAULT_SECRET`, `GAMIFICATION_HMAC_SECRET`, `SPORTS_CERT_SECRET`, `firebase_options` keys, OAuth tokens). Reference existence only. Release builds fail closed without secrets by design.
6. **Truthful writes:** server-first, check `firestoreFailureSimulated`, return `false` on denial, cache write-through only after ack. No `catch (_) {}` swallowing a Firestore write.
7. **Autonomous execution** (project `agents.md`): run shell/git/build/test/edit without asking permission; verify with tests + static analysis; commit and push; report outcome. (This report was explicitly requested as a file.)
8. **Verify-claims workflow:** when handed a "fix report," independently verify every claim against code/tests/rules; document not-done/false claims with solutions in a `NOT_DONE_AND_FALSE_CLAIMS.md`-style file. Audits are read-only unless changes are explicitly requested.

---

## M2 — Teacher-managed recurring weekly timetable engine (the centerpiece)

**Goal:** a *persistent, recurring, versioned* weekly timetable per verified class — not a daily entry form. Exactly **8 teaching periods × 45 min + one 30-min break**; teachers edit **start times**, the system **auto-calculates end times**; durations are immutable. Six-day week **Saturday–Thursday (no Friday)**. Each day configured **independently** (never auto-copied). Effective-date versioning with history + restore. Draft/publish with optional admin approval. Per-class teacher permissions. Audit log. Auto-sync + notifications to affected students/teachers on publish.

**Depends on:** M1 (canonical `class_id`, verification gate, `academic_classes` registry). ✅ available.

### Current state
- **M2a model DONE (uncommitted):** `lib/models/class_timetable.dart` (~430 lines) + `test/class_timetable_test.dart` (**18/18 pass**). Contents:
  - `kTimetableWeekDays = ['Saturday','Sunday','Monday','Tuesday','Wednesday','Thursday']` (`:8`); constants `kTeachingPeriodCount=8`, `kTeachingPeriodMinutes=45`, `kBreakMinutes=30` (`:20-22`), default break after P4, `kMinutesPerDay=1440`.
  - `TimetableStatus` {draft, submitted, published, rejected}; `timetableDayForWeekday(int)` (Fri→Saturday fallback).
  - `TimetableSlot` (`:62`): `periodNumber, subject, teacherName, teacherUid, room, startMinute(-1 default), imageUrl, notes`; `endMinute => startMinute + 45` (`:86`, derived/fixed); `formatMinute`→`HH:MM`; `timeSlot` getter; toMap/fromMap/copyWith.
  - `ClassTimetableVersion` (`:155`): `id, classId, dayOfWeek, status, effectiveFrom, version, breakAfterPeriod, breakStartMinute, slots, createdByUid/Name, publishedAt, approvedByUid/Name, supersedesId, createdAt`; `breakEndMinute => breakStart + 30` (`:193`); `.template(...)` lays out 8×45 with a 30-min break (`:211-216`); `toPeriods()` renders P1..P4, BREAK, P5..P8 reusing `TimetablePeriod`; `validate()` (`:270`) checks count==8, numbering 1..8, break placement, start presence, chronology/no-overlap, day bounds; `activeForDate(versions, date)` (`:316`) picks greatest published `effectiveFrom ≤ date`, tie-break by version; toMap/fromMap (tolerates Timestamp/DateTime/ISO-string)/fromFirestore/copyWith.
- **M2b–M2f NOT STARTED.** Nothing is wired to the service, rules, or UI yet. The live timetable still uses the **legacy grade-keyed** path (see below).

### Legacy surface to reconcile (do not break)
- `lib/screens/academics_screen.dart`: `kBahrainSchoolDays = ['Sunday'..'Thursday']` (**5 days**, `:19`); `TimetableTab` (`:266`); `_effectiveClass = widget.classLevel ?? profile.class_level ?? 'Grade 10'` (`:295`); staff gate `isTeacherOrAdmin` (`:343`); `StreamBuilder` on `getTimetableStream` (`:357`); `_standardTimings` (`:1153`); `_showAddEditPeriodModal` (`:1247`). Legacy editor keys: `add_period_button`, `empty_add_period_button`, `empty_load_cbse_button`, `save_period_button`, `edit_period_N`, `delete_period_N`, `populate_cbse_button`.
- `lib/services/auth_service.dart`: `cacheTimetable` (`:575`), `getCachedTimetable` (`:599`), `getTimetableStream` (`:652`, reads `classes/{classLevel}/timetable`), `saveTimetablePeriod` (`:687`), `deleteTimetablePeriod` (`:741`), `clearTimetableForDay` (`:784`), `populateDefaultCBSEWeeklyTimetable` (`:823`, Sun–Thu hardcoded). These are **truthful + gated** (A5 fixed) — keep them.
- `firestore.rules`: `match /timetable/{periodId}` under `classes/{classId}` (`:792`) — read `isSignedIn`, write `isAdmin`, **no validator, no section scoping**.
- **Tests that must stay green:** legacy staff editor widget test (`test/widget_test.dart` ~`:9040`), student read-only test (`test/academics_security_test.dart` ~`:579`). **Test 4** in `widget_test.dart` (~`:4320`) loops 5 days Sun–Thu → must be updated to the 6-day Sat–Thu week when the student view migrates.

> **⚠ Spec conflict to resolve in M2e:** the user's M2 spec mandates **Saturday–Thursday (6 days, no Friday)**; legacy code uses **Sunday–Thursday (5 days)**. M2a already chose Sat–Thu per the user's explicit spec. Migrate the student/teacher week selector + `kBahrainSchoolDays` usage + Test 4 to 6 days. Keep legacy grade-keyed CRUD intact for non-section contexts (it runs with no `class_id`, so the new engine simply doesn't activate for it).

### Layer breakdown (build in this order)

**M2b — Class identity + permissions + role helper.**
- Extend `AcademicClass` (`lib/models/academic_class.dart`) with: `classTeacherUid` (today only a name is stored), `timetableEditorUids` (list), `timetableEditingEnabled` (bool), `timetableRequiresApproval` (bool). Keep `class_teacher` name as display; add the uid as the authority.
- Add `HierarchyService.canEditTimetable(profile, classId)` — true only for super admin, the class teacher uid, or a uid in `timetableEditorUids` **when editing is enabled**. No global teacher access. (Spec §9.2, test 35.)
- Rules helper `isTimetableEditor(classId)` mirroring the above; `isSeniorAdmin()` for override/restore/approval.
- Admin UI (M7 will host the full queue, but M2 needs the grant/revoke controls): grant/revoke per-class editors, toggle editing-enabled, toggle requires-approval.

**M2c — Timetable service (versioned).** New methods in `auth_service.dart` (or a `timetable_service.dart`):
- `saveTimetableDraft(version)` / `submitTimetable(version)` / `publishTimetable(version)` / `rejectTimetable(version, reason)` — truthful writes to a new `timetable_versions` collection keyed by canonical `classId` + `dayOfWeek`.
- `getActiveTimetableStream(classId, dayOfWeek, date)` — resolves `ClassTimetableVersion.activeForDate` from published versions; `.handleError` → cache fallback.
- `getTimetableHistory(classId, dayOfWeek)` + `restoreTimetableVersion(oldVersion, newEffectiveFrom)` — restore creates a **new** version (never overwrites history; `supersedesId` links it).
- `writeTimetableAudit(...)` — append-only audit on every privileged action (create/edit/submit/publish/reject/restore/override).
- On publish: client-side fan-out notifications to the class roster (M6 engine; on Spark this is a client write loop — see M6 Blaze note) + sync to affected student/teacher streams.
- Cache keys must be **section-aware** (`class_id` + day + version), distinct from legacy grade-keyed cache.

**M2d — Firestore rules.**
- `isValidTimetableVersion(data, classId)`: closed whitelist; `classId` binds to path; `dayOfWeek in kTimetableWeekDays`; **exactly 8 slots**, numbered 1..8; each `endMinute == startMinute + 45` (or store start only and derive); break exactly 30; `status in TimetableStatus.all`; `effectiveFrom`/`version` types; chronology/no-overlap (rules can check monotonic starts); immutable core fields on update; size caps on strings/notes/imageUrl.
- `isValidTimetableAudit(data)`: append-only (`create` only, no update/delete), closed whitelist, actor uid bound to `request.auth.uid`.
- Matchers: `timetable_versions/{versionId}` read = class member (verified) || editor || admin; write = `isTimetableEditor` for draft/submit, `isSeniorAdmin` (or editor when approval not required) for publish; `timetable_audit/{id}` create = privileged, read = admin, **no update/delete**.
- Keep the legacy `classes/{classId}/timetable` matcher working (don't delete) until migration is proven.

**M2e — UI (teacher editor + student view migration).**
- **Teacher editor:** six-day selector (Sat–Thu); per-day independent config; "Edit Day / Add Subjects / Assign Teachers / Assign Classrooms / Customise Period Timings / Configure Break / Preview / Save as Draft / Publish / View Previous Versions / Restore" actions (user spec). Start-time picker per period → **auto end-time display** (read-only, +45). Break position + start configurable, end auto (+30). Live validation errors from `ClassTimetableVersion.validate()`. Full-week preview before publish. Effective-from date picker. History list + restore. Approval-mode banner when `timetableRequiresApproval`.
- **Student view:** migrate `TimetableTab` to six-day selector + `getActiveTimetableStream` (published version for the selected date), with **legacy fallback** when no `class_id`/published version exists. Read-only (no edit affordances — preserve A5 gate). Current/next/completed/break indicators (spec §10.5). Update `kBahrainSchoolDays` usage + Test 4 to 6 days.
- Preserve photo upload on period cards (shipped feature).

**M2f — Tests, verify, deploy, commit/push.**
- Unit: model (18 exist) + service truthful-write/failure-simulation + effective-date resolution + restore-creates-new-version.
- Rules-contract: editor vs non-editor vs unassigned teacher (test 35); student read-only; publish gating; audit append-only; validator rejects wrong count/duration/overlap.
- Widget: teacher editor golden path (edit start → auto end → preview → draft → publish); student six-day read-only; legacy editor + student read-only tests stay green; Test 4 migrated to 6 days.
- `flutter analyze` 0 errors; full suite green; `firebase deploy --only firestore:rules` then re-run says "already up to date"; commit + push.

### Robustness checklist (M2)
- [ ] Durations enforced **server-side in rules**, not just UI (8×45 + 30 break).
- [ ] No overlap / chronological order validated in rules + model.
- [ ] Per-class editor permission enforced in rules (test 35 denial).
- [ ] Students cannot write any timetable version (rules denial test).
- [ ] History immutable; restore creates a new version; audit append-only.
- [ ] Truthful writes + `.handleError` cache fallback on all streams.
- [ ] Section-aware cache keys; legacy grade-keyed path preserved.
- [ ] Six-day Sat–Thu week; each day independent (no auto-copy).
- [ ] Publish triggers roster sync + notifications (M6).

### Definition of done (M2)
Acceptance tests **9–30, 34–38** pass via UI **and** direct rules denial; rules deployed; full suite green; committed + pushed. (Tests 31–33 copy/temporary belong to M3 — see below.)

---

## M3 — Timetable advanced

**Goal:** scheduling conveniences + conflict detection on top of the M2 engine.
**Depends on:** M2.
**Current state:** ❌ not started.

**Requirements:**
- **Double-booking detection** (spec §11.2 tests 18–19): detect a teacher assigned to two classes at overlapping times, and a room double-booked. On Spark this is a **client-side cross-class query + validation** at edit/publish time (server-side conflict validation at scale is Blaze-deferred). Surface clear errors; block publish on conflict.
- **Copy-to-selected-days / apply-to-week** (tests 31–32): copy a day's timing configuration to *selected* days only — never silently overwrite unrelated days/classes. Explicit confirmation + preview of what will change.
- **Temporary one-day overrides** (test 33): a date-specific override that does **not** alter the recurring weekly timetable. Model as a separate override version with a single effective date; `activeForDate` must prefer the override for that date only. (Extends M2a's effective-date resolution.)
- **Substitution updates** (spec §8, §10.2): mark a period's teacher as substituted for a date; show "substitute teacher" indicator; notify affected class.
- **Transition gaps** (spec §10.5): optional gaps between periods; model already accepts gaps (validate allows non-contiguous starts as long as no overlap).

**Data/Service/Rules/UI:** extend `ClassTimetableVersion` (or add `TimetableOverride`) with `overrideDate`/`isTemporary`; service conflict-check query across the teacher's/room's classes; rules validator for override shape; UI conflict warnings + copy-day dialog + substitution marker.
**Tests:** double-booking denial (teacher + room); copy-to-selected-days leaves other days untouched; temporary override resolves for its date only and leaves the recurring version intact; substitution indicator + notification.
**Robustness:** conflicts blocked server-side where rules can express them; copy/override never mutate unrelated days (immutability tests); all writes truthful.
**Definition of done:** tests **18–19, 31–33** + substitution pass via UI and rules; suite green; deployed; committed.

---

## M4 — House communication groups

**Goal:** per-house group where **authorised leaders + staff send** and **students read-only** (cannot send, cannot upload attachments). Auto-membership by house; cross-house access denied; transfer revokes old / grants new.
**Depends on:** M1 house identity (profile `house`), existing chat infra. Independent of M2/M3.
**Current state:** ❌ not started. `chat_service.dart` is **1-to-1 private rooms** (`chats`, `participants arrayContains uid`); `house_ai_chat_screen.dart` is an AI bot, not a group.

**Requirements (spec §3, tests 39–49):**
- Auto-join the house group on verified house assignment (Ruby → Ruby House Group).
- **Send permission:** house captain, vice-captain, sports captain, sports vice-captain, head boy, head girl, authorised staff. **Students: read-only** (no send, no attachment upload). Roles already exist in `HierarchyService.isCaptain`/`isCouncil`.
- Categories, pin, moderate (delete/hide) for authorised roles.
- Cross-house isolation: a Ruby student cannot read Sapphire messages (test 48).
- Transfer: lose old house group, gain new (test 49) — membership/permissions update automatically (spec §9.5), house change must **not** change academic class.
- **Backend send rules** — not frontend filtering.

**Data/Service/Rules/UI:** new `house_groups/{houseId}` + `messages` subcollection (reuse `chat_room_screen`/`chat_list_screen` patterns); membership derived from profile house (no separate self-asserted join); rules: read = same-house member, create/send = `isHouseSender(houseId) && sameHouse`, attachment upload restricted to senders; moderate = leader/staff. Service: `getHouseGroupStream`, `sendHouseMessage` (truthful), auto-membership resolution.
**Tests (39–49):** each via UI **and** direct rules denial — student send denied, student attachment denied, cross-house read denied, each authorised role can send, transfer revokes/grants.
**Robustness:** send restriction in rules (the core security property); house membership read from verified profile, never self-asserted; truthful sends; no frontend-only gating.
**Definition of done:** tests 39–49 pass UI + rules; deployed; committed.

---

## M5 — Class groups & academic communication

**Goal:** per-class channel + class announcements; class teacher / subject teacher / class rep permissions; configurable student send; class-scoped isolation.
**Depends on:** M1 (verified `class_id`) + M4 group machinery.
**Current state:** ❌ not started. Assignments/exams exist but no class discussion/announcement feed.

**Requirements (spec §4, tests 50–54):**
- Verified students auto-join their class group (test 50).
- Class teachers publish class announcements (51); subject teachers communicate with **assigned** classes only (52).
- Student send permission is **configurable by the school** (53) — default read-only unless enabled.
- No access to another class's private channel (54).
- New roles needed: `class_teacher`, `subject_teacher`, `class_representative`, `vice_class_representative` (and `parent`) — currently missing (gap analysis §7). Add to `HierarchyService` + rules + per-class teaching assignments.

**Data/Service/Rules/UI:** `class_groups/{classId}` + messages/announcements; membership from verified `class_id`; rules read = verified class member, send = class teacher / assigned subject teacher / class rep / (students if enabled); teaching assignments stored per class (extends M2b `AcademicClass`). Reuse M4 UI.
**Tests (50–54):** auto-join, class-teacher publish, subject-teacher assigned-only, configurable student send, cross-class denial — UI + rules.
**Robustness:** class membership verified (M1 gate); subject-teacher scoping enforced in rules; student send is a server-checked flag, not UI; truthful writes.
**Definition of done:** tests 50–54 pass UI + rules; new roles synced client↔rules; deployed; committed.

---

## M6 — Notification engine (in-app, Spark)

**Goal:** unified in-app notifications with read/unread, priority, dedupe; alerts for timetable/class/house changes.
**Depends on:** M2/M4/M5 events.
**Current state:** ❌ not started. Existing "unread" hits are chat-message counts only. A per-user `users/{userId}/notifications/{id}` subcollection + `isValidNotification` validator **already exists** in rules (`:368`, closed whitelist `[title,body,timestamp,is_read,type,room_id]`, create = `isSignedIn`) — reuse/extend it.

**Requirements (spec §5, tests 60–62):**
- `notifications` stream + read/unread engine; priority; dedupe (idempotency key per event).
- Timetable publish → notify affected class (60); house announcement → notify correct house (61); class announcement → notify correct class (62).
- **Spark path:** client-side fan-out — on publish, the client writes a notification doc per recipient (roster loop). The existing rules allow any signed-in user to create a notification in another user's subcollection, which enables this. **Blaze-deferred:** server-side fan-out via Cloud Functions (scalable, atomic). Track in BLAZE_REQUIRED_FEATURES.md.
- No FCM push required for Spark (in-app only); `firebase_messaging` not in use.

**Data/Service/Rules/UI:** extend the existing notification subcollection + validator (add `priority`, `dedupe_key`, `category`); service `getNotificationsStream`, `markRead`, `fanOutToRoster` (truthful, batched); UI notification center + unread badges on dashboard (M8).
**Tests (60–62):** publish/announcement produces exactly the right recipients' notifications; dedupe prevents doubles; read/unread toggles; rules validator rejects malformed docs.
**Robustness:** fan-out is truthful (partial failure surfaced, not phantom success); dedupe idempotent; recipient scoping correct (no cross-house/class leakage); validator closed whitelist.
**Definition of done:** tests 60–62 pass; in-app engine works on Spark; Blaze fan-out documented as deferred; deployed; committed.

---

## M7 — Admin Command Center expansion

**Goal:** central admin control over academics, teachers, houses, groups, users, timetable approvals, audit logs, promotion.
**Depends on:** M1–M6.
**Current state:** 🟡 partial. `admin_claims_screen.dart` (point claims + medical reports), `admin_academics_screen.dart` (M1: Verify/Classes/Rosters), admin gates in `home_screen.dart`, election/gamification admin surfaces exist.

**Requirements (spec §6, §10.4, tests 55–59, 63–64):**
- Academic management: grades LKG–12 (55), sections create/rename/activate/deactivate (56), approve class assignments (57), house assignments (58), **promotion to next academic year** (59).
- Teacher management + per-class teaching assignments + timetable editor permissions (extends M2b).
- **Timetable approval queue** (test 36): approve/reject submitted versions when approval required; override/restore (37).
- House management; group/communication management; notification management.
- **Audit-log viewer** (63): surface the append-only `timetable_audit` (M2) + other privileged-action logs.
- User verification/suspension/deactivation; unauthorised users blocked from all admin actions (64).
- **Blaze-deferred:** atomic cross-collection promotion/transfer transactions (Spark path = sequential truthful client writes with clear failure surfacing; document the atomicity gap).

**Data/Service/Rules/UI:** extend `admin_academics_screen.dart` / Admin Portal → Administrative Tools; promotion service (update `class_id`/grade, keep house unchanged — spec §9.5); approval queue UI reading `submitted` versions; audit viewer reading `timetable_audit`; rules: all admin actions gated `isAdmin`/`isSeniorAdmin`, promotion preserves house.
**Tests (55–59, 63–64):** grade/section management, approval, house assignment, promotion (house unchanged), audit entries exist + append-only, non-admin denial — UI + rules.
**Robustness:** every admin action server-gated + audited; promotion/transfer never changes the other membership (class↔house independent); non-admin denial tested directly; truthful writes.
**Definition of done:** tests 55–59, 63–64 pass UI + rules; approval queue + audit viewer functional; deployed; committed.

---

## M8 — Dashboard & profile polish + full acceptance

**Goal:** verified-class student dashboard + the complete spec §11 acceptance suite across roles × frontend × backend.
**Depends on:** M1–M7 (capstone).
**Current state:** 🟡 partial. Profile has scholar_no/full_name/class_level/division/house/role/age; `home_screen.dart` adapts tiles by role/house.

**Requirements (spec §7, §10.1, §10.5–10.6):**
- Dashboard "today's 8 periods / current / next / break" driven by the **published section timetable** (M2 active version).
- Verified-class badge; class-teacher field on profile/dashboard.
- Unread class/house announcement counts (M6).
- Age-appropriate simpler interface for younger students (LKG–UKG/primary) — no admin clutter.
- Responsive: desktop/laptop/tablet/mobile.
- **Full §11 acceptance suite (1–64)** run with separate test accounts per role, every restriction tested via **UI and direct backend/rules denial**.

**Data/Service/Rules/UI:** dashboard widgets reading M2 active version + M6 unread counts; profile verified-class badge + class teacher; responsive layouts; acceptance test harness.
**Tests:** all 64 acceptance tests green; role × frontend × backend matrix.
**Robustness:** dashboard reflects only the verified class's published timetable (no other class leakage); younger-student UI hides admin functionality server-side too; responsive verified.
**Definition of done:** all 64 acceptance tests pass; dashboard/profile complete; suite green; committed.

---

## Acceptance — spec §11 tests 1–64 mapped to modules

Every test must pass via **UI and direct rules/backend denial** (project convention).

**§11.1 Academic classification (1–8) → M1 ✅ DONE**
1 register Grade 11D · 2 verification · 3 11D membership on approval · 4 auto 11D timetable access · 5 cannot retrieve another class's timetable · 6 admin transfer 11D→11B · 7 info/timetable/group update · 8 house unchanged.
> Note: tests 4–5 (timetable access scoping) are only fully satisfied once **M2** ships the section-scoped timetable; M1 delivered the identity/verification/transfer foundation.

**§11.2 Standard timetable (9–20) → M2 (18–19 double-booking → M3)**
9 exactly 8 teaching periods · 10 each 45 min · 11 exactly one break · 12 break 30 min · 13 default break after P4 · 14 moving break recalculates · 15 changing start recalculates all · 16 prevent wrong durations · 17 prevent overlaps · **18 double-booked teachers → M3** · **19 double-booked rooms → M3** · 20 publish updates every affected student.

**§11.3 Teacher custom timing (21–38) → M2 (31–33 → M3)**
21 authorised teacher opens editor · 22 select assigned class · 23 select day · 24 customise P1 start · 25 customise P2–8 independently · 26 auto end times · 27 each 45 min · 28 break 30 min · 29 save drafts · 30 preview before publish · **31 apply to one day without changing others → M3** · **32 copy configs to selected days → M3** · **33 temporary one-day schedule → M3** · 34 prevent overlaps/invalid · 35 prevent unauthorised teacher editing unassigned class · 36 admin approve/reject when required · 37 admin override/restore · 38 published changes sync to students/teachers.

**§11.4 House communication (39–49) → M4**
39 Ruby student auto-joins Ruby group · 40 read Ruby announcements · 41 cannot send · 42 cannot upload attachments · 43 house captain sends · 44 vice-captain sends · 45 sports captain/vice send · 46 head boy/girl send · 47 authorised staff publish · 48 other-house student cannot access · 49 transfer loses old / gains new.

**§11.5 Class communication (50–54) → M5**
50 verified students auto-join class group · 51 class teachers publish · 52 subject teachers communicate with assigned classes · 53 students only configured permissions · 54 no access to another class's channel.

**§11.6 Administration & notifications (55–64) → M6/M7**
55 manage grades LKG–12 · 56 create/manage sections · 57 approve class assignments · 58 manage house assignments · 59 promote to next year · **60 timetable change notifications → M6** · **61 house announcement notifications → M6** · **62 class announcement notifications → M6** · 63 admin changes in audit logs · 64 unauthorised users blocked from admin actions.

---

## Blaze-deferred (do NOT build on Spark) — summary of D1–D5

Full detail in `election_audit/BLAZE_REQUIRED_FEATURES.md`. Nothing here is broken/forgotten — parked until `asb-house-hub` upgrades to Blaze.

- **D1 — Deploy Cloud Functions** (master switch): `schoolElection` (live election backend), `schoolLibrary` (circulation), `verifyCertificateSignature` (Cloud Vision AI scan). All authored + syntax-checked, none live until deploy.
- **D2 — Live election end-to-end smoke test** (needs D1).
- **D3 — App Check enforcement** for mobile/web (needs D1; Windows desktop stays on compensating controls).
- **D4 — Gamification/points server authority:** `schoolGamification` callable (server validation, cooldowns, atomic awards, idempotency, nonce store, audit) + sports certification callable. Interim no-Blaze hardening **done**; student live awards fail closed until this ships.
- **D5 — Academics server authority:** atomic honours merit claim (A4 end-state, rides on D4) + live academics smoke test.
- **M6/M7 server items (add to the file when reached):** server-side notification fan-out; atomic cross-collection promotion/transfer transactions; server timetable conflict validation at scale.

**Go-live build reminder:** release builds fail closed without secrets — supply `ELECTION_HMAC_SALT`, `VAULT_SECRET`, `GAMIFICATION_HMAC_SECRET`, `SPORTS_CERT_SECRET` via `--dart-define` (values never reproduced here).

---

## Open academics hygiene (P2) — small, no-Blaze, do alongside/after M2

From `academics_audit/REMEDIATION_ROADMAP.md` P2 (A7 + A9). LOW severity, admin-only surfaces mostly; quick wins:

- **P2-1 (A7):** remove hardcoded leave identity fallbacks (`2310910` / `Mohammed Ayaan` / `ruby`) — block submit with "Profile not loaded" when unresolved. (`academics_screen.dart` leave submit ~`:6927-6929`.)
- **P2-2 (A7):** collision-free leave IDs — auto-ID or `med_${sNo}_${millis}` (today `med_${millis}`, `auth_service.dart` ~`:6440`).
- **P2-3 (A7):** `isValidAttendance` bind `scholar_no` to `{scholarNo}` path + validate `date` (`firestore.rules` ~`:508-522`).
- **P2-4 (A7):** keep the "excused attendance" comment honest — leave approval never excuses attendance (policy). Comment already corrected; no automation.
- **P2-5 (A7/A1/A3):** `.handleError` cache fallbacks on `getMedicalLeavesStream` + `getReportCardsStream` (async permission errors currently bypass cache).
- **P2-6 (A9):** empty publisher defaults — teacher (`Mr. Sharma` ~`:2339`), paper title/syllabus (`Mid-Term Assessment Paper 1` / `Chapters 1 to 5 Revision` ~`:3516-3518`) → empty controllers + hints; keep genuine defaults (hall/duration/marks).
- **P2-7 (A9):** `isValidHomework` attachments per-item cap — each item `is string && size() <= 2000` (`firestore.rules` ~`:397`).

> Line numbers above are from the audit docs and may have shifted; re-grep before editing. Each needs a rules-contract or unit test per the roadmap "Verify" column.

---

## Recommended build order (when credits allow)

1. **Commit M2a** (model + 18 tests) so the drafted work isn't lost — it's currently untracked.
2. **M2b → M2c → M2d → M2e → M2f** (the engine; spec centerpiece). Reconcile the 5-day→6-day week conflict in M2e; keep legacy tests green.
3. **M3** (advanced scheduling) — completes timetable acceptance tests 18–19, 31–33.
4. **M4** (house groups) — independent of M2/M3; high security value (read-only students).
5. **M5** (class groups) — reuses M4 machinery + new roles.
6. **M6** (notifications) — wires M2/M4/M5 events.
7. **M7** (admin expansion) — approval queue, audit viewer, promotion.
8. **M8** (dashboard + full 64-test acceptance) — capstone.
9. **P2 academics hygiene** (A7/A9) — slot in anywhere; small.
10. **Blaze D1–D5** — only after the user upgrades; never on Spark.

**Per-module ritual (every time):** model → service → rules → UI → tests; `flutter analyze` 0 errors; full suite green; `firebase deploy --only firestore:rules` (+ immediate re-run = "already up to date"); commit + push; update this report's status table and `MASTER_GAP_ANALYSIS.md`.

---

## Verification protocol (for whoever resumes)

- Treat any "done" claim as unverified until checked against **code + tests + deployed rules**. Run the named test file; grep the named symbol; confirm the rules matcher exists and denies the right roles.
- A feature is **not done** if its screen exists but the database write/permission/workflow isn't real (spec §11 preamble). Test the actual persistence + denial, not just the UI.
- Document not-done/false claims with solutions in a `NOT_DONE_AND_FALSE_CLAIMS.md`-style file (project convention).
- Never reproduce secret values. Never build the cancelled leave→attendance automation. Never enable Blaze-only paths on Spark.