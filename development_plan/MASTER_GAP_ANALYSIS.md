# ASB Digital Campus — Master Spec Gap Analysis & Build Plan

Input: `MASTER DEVELOPMENT PROMPT — ASB DIGITAL CAMPUS` (12-section spec, attached 2026-11-08).
Method: first-hand inspection of the current codebase (spec §12 requirement) before any implementation.
Baseline: HEAD `1f426c2` (academics P0/P1 remediations landed: A1–A6, A8). `flutter analyze` = 20 infos / 0 errors; `test/academics_security_test.dart` 28/28; full suite green. Firebase **Spark** (no Blaze) — see `election_audit/BLAZE_REQUIRED_FEATURES.md`.

Legend: **EXISTS** (keep) · **PARTIAL** (extend) · **MISSING** (build) · **CONFLICT** (spec contradicts current code).

---

## 1. Academic classification (spec §1)

- **PARTIAL** — Signup captures grade + section + house: `signup_screen.dart:38` `_grades = ['6'..'12']`, `:39` `_divisions = ['A'..'F']`, `:142-144` passes `classLevel`, `division`, `houseName` to `signUp`.
- **CONFLICT** — Grades only 6–12. Spec requires **LKG, UKG, Grades 1–12**.
- **CONFLICT** — Sections are a fixed client list A–F. Spec: admin-managed, variable count per grade, create/rename/activate/deactivate.
- **CONFLICT** — Timetable/academics are keyed by `class_level` = `'Grade N'` only (e.g. `classes/Grade 10/timetable`). `division` is stored on the profile but **not used to scope timetables** → every section of a grade shares one timetable. Spec §2.6 demands per-section (9A ≠ 9D).
- **MISSING** — Admin verification/approval of a student's requested class; class-roster view; transfers; promotion; deactivation. No `classes`/`classMemberships` registry collection (the `classes/{id}` docs are implicit containers, not managed entities).

## 2. Timetable (spec §2) — the centerpiece

- **PARTIAL** — `TimetablePeriod` model + Timetable tab + `AuthService` CRUD + photo upload (shipped). Period card, weekday selector (Sun–Thu), current/next highlighting exist.
- **CONFLICT** — No fixed structure. `periodNumber` is arbitrary, `timeSlot` is a free string with a "custom timing" option, break is an `isBreak` flag on a period. Spec mandates **exactly 8 teaching periods × 45 min + exactly one 30-min break**, break not counted as a period, durations immutable by teachers.
- **CONFLICT** — Not per-section (see §1).
- **MISSING** — Auto end-time calculation from a start time; chronological/overlap validation; teacher & room double-booking detection; draft→publish + approval modes; per-day copy/apply-to-week; temporary one-day overrides; version history/restore; substitution; change notifications; school operating-hours config; transition gaps.
- **EXISTS to reuse** — `saveTimetablePeriod`/`deleteTimetablePeriod` are truthful (server-first); rules `classes/{id}/timetable` admin-write only (`firestore.rules:758-761`); staff UI gates now aligned (A5/A6 fixed).

## 3. House communication groups (spec §3)

- **MISSING** — No house group/channel. `chat_service.dart` is **1-to-1 private rooms** (`chats` collection, `participants arrayContains uid`, `getOrCreateChatRoom(otherUserId)`), council/admin oriented. `house_ai_chat_screen.dart` is an AI bot, not a group.
- **EXISTS to reuse** — chat infrastructure (`chat_service`, `chat_room_screen`, `chat_list_screen`), house membership on profile (`AuthService.extractHouse`), role engine (`HierarchyService`).
- **MISSING** — auto-membership by house; role-restricted send (captains/vice/sports/head-boy/head-girl/staff send, students read-only); categories; pin/moderate; backend send rules. Roles for senders already exist in `HierarchyService.isCaptain`/`isCouncil` (head_boy, head_girl, sports_captain, sports_vice_captain).

## 4. Class groups / academic communication (spec §4)

- **MISSING** — No per-class group or class announcement channel. Assignments/exams exist but no class-scoped discussion/announcement feed.
- **Depends on** §1 (verified class identity) and §3 (group machinery).

## 5. Notification engine (spec §5)

- **MISSING** — No unified notifications. Grep hits for "unread/notification" are chat-message unread counts only. No `notifications` collection, no read/unread engine, no FCM (`firebase_messaging` not in use).
- **Spark note** — In-app notifications (Firestore `notifications` + client stream) work on Spark. Server fan-out via Cloud Functions needs Blaze → deferred; client-side fan-out on publish is the Spark path.

## 6. Admin Command Center (spec §6)

- **PARTIAL** — `admin_claims_screen.dart` (point claims + medical reports), admin gates in `home_screen.dart`. Election/gamification admin surfaces exist.
- **MISSING** — academic management (grades/sections/rosters/transfers/promotion), teacher management, timetable management/approval queue, house management, group/communication management, notification management, audit-log viewer, user verification/suspension.

## 7. Roles / RBAC (spec §9.3)

- **EXISTS** — `hierarchy_service.dart`: super_admin; teacher/faculty/principal/staff/faculty_advisor/teacher_lead; captain/vice_captain/house_captain/house_vice_captain; council (head_boy, head_girl, deputy_*, sports_captain, sports_vice_captain, cultural_secretary, head_of_activities); prefect/student_rep/grade_prefect. Rules helpers mirror these.
- **PARTIAL** — head_boy/head_girl/sports_captain exist (as council). **MISSING** distinct class_teacher / subject_teacher / class_representative / vice_class_representative / parent roles and per-class teaching assignments.
- **CONFLICT (known, fixed for academics)** — client `isTeacherOrFaculty` admits faculty_advisor/teacher_lead; rules historically didn't (A6 — addressed in `1f426c2`; keep lists synced).

## 8. Student profile / dashboard (spec §7)

- **PARTIAL** — profile has scholar_no, full_name, class_level, division, house, role, age. `home_screen.dart` adapts tiles by role/house.
- **MISSING** — class-teacher field; verified-class badge; dashboard "today's 8 periods / current / next / break" driven by the published (section) timetable; unread class/house announcement counts.

---

## Cross-cutting conflicts to resolve first

1. **Class identity must include section.** Introduce a canonical class id (e.g. `11D` = grade 11 + section D) used by timetable, groups, announcements, notifications. Migrate `classes/Grade N/...` → `classes/{grade}{section}/...` (or add a `section` scope). This is the foundation everything else keys on.
2. **Timetable structure is mandated, not free-form.** 8×45 + one 30-min break; durations fixed; start times customizable; end times computed. The current free-form model must be constrained/extended, not replaced wholesale (preserve photo upload, truthful saves, gates).
3. **Verification gate.** Students must not self-assign permanently; admin approval before class-scoped access (spec §1.3, §9.4).

## Preserve (do not break)

Elections, gamification/points, sports, wallet, merch, ID scanner, behavior evaluation, existing chat, auth/account-switching, all shipped academics security fixes (A1–A6, A8) and the photo-upload feature. Existing rules helpers and truthful-write patterns.

---

## Phased build plan (logical, connected modules)

Each module: model + service + rules + UI + tests, deployed and verified before the next. All Spark unless noted.

- **M1 — Academic foundation. ✅ DELIVERED 2026-11-08.** Grade enum LKG–G12; admin-managed sections; canonical class id; `academic_classes` registry; signup grade/section update; admin verification/approval + roster + transfer. Rules: students read own class only; writes admin. *(Unblocks everything.)*
  - Implementation note: registry collection is `academic_classes` (not `classes`, which already holds grade-keyed academics subcollections). Membership lives on the user profile (`class_id`, `class_verified`) instead of a separate `classMemberships` collection — rosters query `users` by canonical `class_id` with legacy `class_level`+`division` fallback. `class_teacher` is stored only on the registry (single source of truth), not denormalized onto profiles.
  - Files: `lib/models/academic_class.dart`, `lib/services/auth_service.dart` (registry + verification methods), `lib/screens/signup_screen.dart` (LKG–12, age 4+), `lib/screens/admin_academics_screen.dart` (Verify/Classes/Rosters tabs, entry via Admin Portal → Administrative Tools), `firestore.rules` (isValidUser extension, signup `class_verified=false` gate, owner-immutable class fields, `academic_classes` matcher + validator), `test/academic_structure_test.dart` (29 tests).
- **M2 — Mandated timetable engine. ✅ DELIVERED 2026-11-08.** 8×45 + 30-min break structure; start-time editor with auto end-time; validation (count/duration/overlap/chronology); per-section + per-day; publish/draft; rules scoped to verified class. *(Spec centerpiece; depends on M1.)* V1–V4 fixed; V5 notification fan-out stays M6; V6/V7 non-blocking; rules tests are source contract (V8). See `M2_VERIFICATION.md`.
- **M3 — Timetable advanced. ✅ DELIVERED FOR SCOPE 2026-11-08.** Client-side double-booking detection (teacher/room, tests 18–19), copy-to-selected-days (31–32), temporary one-day overrides (33), substitution markers, version history/restore already in M2. Server-side conflict validation at scale stays Blaze-deferred; substitution notification fan-out stays M6; admin approval queue stays M7. See `M3_VERIFICATION.md`.
- **M4 — House communication groups.** Auto-membership; role-restricted send (students read-only) enforced in rules; categories; pin/moderate; reuse chat infra. *(Depends on M1 house identity; independent of M2/M3.)*
- **M5 — Class groups & academic communication.** Per-class channel; teacher/subject-teacher/class-rep permissions; configurable student send; class announcements. *(Depends on M1 + M4 machinery.)*
- **M6 — Notification engine (in-app, Spark).** `notifications` collection + stream; read/unread; priority; dedupe; timetable/class/house change alerts. Blaze server fan-out deferred. *(Depends on M2/M4/M5 events.)*
- **M7 — Admin Command Center expansion.** Academic/teacher/house/group/user management, timetable approval queue, audit logs, promotion. *(Depends on M1–M6.)*
- **M8 — Dashboard & profile polish + acceptance.** Verified-class dashboard (today/current/next/break), class-teacher field, full spec §11 acceptance suite (roles × frontend × backend). *(Capstone.)*

**Blaze-deferred (add to BLAZE_REQUIRED_FEATURES.md):** server-side notification fan-out, atomic cross-collection promotion/transfer transactions, server timetable conflict validation at scale.

## Acceptance mapping

Spec §11 tests 1–64 map to modules: 1–8 → M1; 9–20 → M2; 21–38 → M2/M3; 39–49 → M4; 50–54 → M5; 55–64 → M6/M7. Every restriction tested via UI **and** direct rules denial (project convention).

## Recommended starting point

**M1 (academic foundation)** — the section-aware class identity and verification gate are prerequisites for the timetable, groups, and notifications. Building the timetable first would key it on the wrong (grade-only) identity and force a migration later.