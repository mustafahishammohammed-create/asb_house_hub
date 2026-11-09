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
| **M2 — Teacher-managed recurring timetable engine (M2a–M2f)** | ✅ **DONE for scope** (V1–V4 fixed 2026-11-08). V5 is owned by M6; V6/V7 are non-blocking follow-ups; V8 remains a source-contract caveat. | Engine + UI + rules. V1: all 8 slots, period order, overlap, break placement validated in rules. V2: `rejection_reason` round-trips and is whitelisted; reject is truthful. V3: published versions are immutable for everyone. V4: editor button is gated by `canEditTimetable`, no `'10A'` fallback, editor blocks unauthorized writes. See [`M2_VERIFICATION.md`](M2_VERIFICATION.md). |
| **M3 — Timetable advanced** | ✅ **DONE for scope** (2026-11-08). Client-side double-booking, copy-to-selected-days, one-day overrides, substitution markers. Notification fan-out stays in M6. See [`M3_VERIFICATION.md`](M3_VERIFICATION.md). | double-booking, copy-to-days, temporary overrides, substitution |
| **M4 — House groups** | ✅ **DONE for scope** (2026-11-08, commit `4caeae5`; rules deployed). See [`M4_VERIFICATION.md`](M4_VERIFICATION.md). | profile-derived membership, rules-enforced sender roles, categories, pin/hide/delete moderation, cross-house isolation/transfer |
| **M5 — Class groups** | ✅ **DONE for scope** (2026-11-08, rules deployed). See [`M5_VERIFICATION.md`](M5_VERIFICATION.md). | verified-class auto-membership, class-teacher/subject-teacher/representative send, configurable student posting, cross-class isolation |
| **M6 — Notification engine** | ✅ **DONE for scope** (2026-11-08, hardened 2026-11-09; rules deployed). See [`M6_VERIFICATION.md`](M6_VERIFICATION.md). | timetable publish (60), house announcement (61), class announcement (62), deterministic dedupe, priority, mark-all-read, truthful lookup/substitution failure reporting |
| **M7 — Admin Command Center expansion** | ✅ **DONE for scope** (2026-11-08, hardened 2026-11-09; rules deployed). See [`M7_VERIFICATION.md`](M7_VERIFICATION.md). | academic/teacher/house/group/user mgmt, approval queue, audit viewer, promotion, truthful live-write and promotion failure reporting |
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
Verified 2026-11-08 after V1–V4 remediation: **complete for scope**. The original independent check of `23a87cd` found the engine real but the robustness claims overclaimed; those findings and their fixes are in [`M2_VERIFICATION.md`](M2_VERIFICATION.md). V5 (publish notifications) remains M6 work. V6 (audit truthfulness) and V7 (admin grant/revoke UI) remain non-blocking follow-ups.

- **M2a–M2f present in tree, not fully verified:**
  - **M2a Model:** [`lib/models/class_timetable.dart`](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/models/class_timetable.dart) (~440 lines) + [`test/class_timetable_test.dart`](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/test/class_timetable_test.dart) (**18/18 pass**). Implements 6 school days Sat–Thu, 8 periods × 45 min + 30 min break, `validate()`, `activeForDate()`, and ISO-8601 serializable cache maps.
  - **M2b Identity & Permissions:** [`lib/models/academic_class.dart`](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/models/academic_class.dart) and [`lib/services/hierarchy_service.dart`](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/hierarchy_service.dart) implement `classTeacherUid`, `timetableEditorUids`, `timetableEditingEnabled`, `timetableRequiresApproval`, `HierarchyService.isSeniorAdmin`, and `HierarchyService.canEditTimetable` (enforces Acceptance Test 35 denial for unassigned teachers).
  - **M2c Versioned Timetable Service:** [`lib/services/timetable_service.dart`](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/services/timetable_service.dart) implements truthful writes (`firestoreFailureSimulated` support), section-aware caching (`timetable_active_${classId}_${dayOfWeek}` and `timetable_history_${classId}_${dayOfWeek}`), `saveTimetableDraft`, `submitTimetable`, `publishTimetable`, `rejectTimetable`, `restoreTimetableVersion` (creates a new version, linking `supersedesId`), and append-only audits.
  - **M2d Firestore Rules:** [`firestore.rules`](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/firestore.rules) implements `isTimetableEditor(classId)`, `canPublishTimetable(classId)`, `isValidTimetableSlot(slot)`, `hasOrderedTimetableSlots(slots)`, `isValidTimetableBreakPlacement(...)`, `isValidTimetableVersion(data, classId)`, and `isValidTimetableAudit(data)`. All 8 slots, period numbers `1..8`, 45-minute non-overlap, midnight bounds, and break placement are validated. `rejection_reason` is whitelisted. The update rule freezes any document whose current status is `published` for everyone, including senior admins. Matchers for `/timetable_versions/{versionId}` and `/timetable_audit/{auditId}` (`allow update, delete: if false;`). Deployed to `cloud.firestore`.
  - **M2e UI (Teacher Editor & Student View):** [`lib/screens/teacher_timetable_editor_screen.dart`](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/teacher_timetable_editor_screen.dart) provides 6-day Sat–Thu selector, standard 07:45 preset, start time pickers with auto +45 end time, break configuration (+30 auto end), live validation card, effective date picker, draft/publish/submit actions, full week preview dialog, and history restoration modal. It computes `canEditTimetable` and renders an authorization screen without Save/Publish for unassigned teachers. [`lib/screens/academics_screen.dart`](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/lib/screens/academics_screen.dart) migrated `TimetableTab` to 6 days Sat–Thu, streams from `TimetableService`, falls back to the legacy timetable when no section version exists, and only offers the editor for classes where `canEditTimetable` is true (explicit picker for multiple classes; no `'10A'` fallback).
  - **M2f Tests & Analysis:**
    - [`test/timetable_engine_test.dart`](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/test/timetable_engine_test.dart): **22/22 pass** (includes V1–V3 source-contract checks and truthful reject denial)
    - [`test/teacher_timetable_editor_test.dart`](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/test/teacher_timetable_editor_test.dart): **11/11 pass** (includes V4 unassigned/assigned editor tests)
    - [`test/class_timetable_test.dart`](file:///C:/Users/User/OneDrive/Desktop/asb_house_hub_flutter/test/class_timetable_test.dart): **19/19 pass** (includes rejection-reason round-trip)
    - Full suite: **440/440 tests pass** cleanly
    - `flutter analyze`: **0 errors, 0 warnings** (20 pre-existing infos)
    - `firebase deploy --only firestore:rules`: compiled and released.

### Legacy surface to reconcile (do not break)
- `lib/screens/academics_screen.dart`: `kBahrainSchoolDays` is now the **6-day Sat–Thu** week; `TimetableTab`; `_effectiveClass = widget.classLevel ?? profile.class_level ?? 'Grade 10'`; staff gate `isTeacherOrAdmin`; the new `editableClasses` / `canManageTimetable` gate for the recurring editor; `StreamBuilder` on `getTimetableStream`; `_standardTimings`; `_showAddEditPeriodModal`. Legacy editor keys remain: `add_period_button`, `empty_add_period_button`, `empty_load_cbse_button`, `save_period_button`, `edit_period_N`, `delete_period_N`, `populate_cbse_button`.
- `lib/services/auth_service.dart`: `cacheTimetable` (`:575`), `getCachedTimetable` (`:599`), `getTimetableStream` (`:652`, reads `classes/{classLevel}/timetable`), `saveTimetablePeriod` (`:687`), `deleteTimetablePeriod` (`:741`), `clearTimetableForDay` (`:784`), `populateDefaultCBSEWeeklyTimetable` (`:823`, Sun–Thu hardcoded). These are **truthful + gated** (A5 fixed) — keep them.
- `firestore.rules`: `match /timetable/{periodId}` under `classes/{classId}` (`:792`) — read `isSignedIn`, write `isAdmin`, **no validator, no section scoping**.
- **Tests that must stay green:** legacy staff editor widget test (`test/widget_test.dart` ~`:9040`), student read-only test (`test/academics_security_test.dart` ~`:579`). Both pass. The legacy widget test still loops five weekdays; extend it to assert Saturday when it is next touched.

> **Spec note (resolved):** the user's M2 spec mandates **Saturday–Thursday (6 days, no Friday)**. M2a and M2e use that week. Legacy grade-keyed CRUD remains available for non-section contexts (no `class_id`), so the section engine simply does not activate there.

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
- Widget: teacher editor golden path (edit start → auto end → preview → draft → publish); student six-day read-only; legacy editor + student read-only tests stay green. The legacy weekday loop still covers Sunday–Thursday and passes; extending it to assert Saturday is a cleanup, not a blocker.
- `flutter analyze` 0 errors; full suite green; `firebase deploy --only firestore:rules`; commit + push. Verified 2026-11-08: 440/440, rules deployed.

### Robustness checklist (M2)
- [x] Durations and break placement enforced **server-side in rules**, not just UI. All 8 slots, period order, 45-minute non-overlap, midnight bounds, and break-vs-period placement are validated (V1 fixed).
- [x] No overlap / chronological order validated in rules + model. Both enforce it (V1 fixed).
- [x] Per-class editor permission enforced in rules (`isTimetableEditor`) **and** the Edit button/editor are gated by `HierarchyService.canEditTimetable` (V4 fixed).
- [x] Students are not `isTimetableEditor` (requires `isAdmin()`). The denial is covered by source-contract assertions only; no emulator test exists (V8 caveat).
- [x] History immutable. Restore creates a new version; audit create-only is real; published versions can no longer be updated in place by anyone, including senior admins (V3 fixed).
- [x] Version and reject writes return false on simulated Firestore failure; streams use `.handleError`; reject no longer caches a denied write (V2 fixed).
- [ ] Audit write truthfulness. `writeTimetableAudit` still caches and returns `true` on a real denial (V6, non-blocking follow-up).
- [x] Section-aware cache keys; legacy grade-keyed path preserved.
- [x] Six-day Sat–Thu week; each day independent (no auto-copy). Copy-to-days is M3.
- [ ] Publish triggers roster sync + notifications. Active-version stream syncs listeners. No notification docs (V5, owned by M6 / test 60).

### Definition of done (M2)
✅ **Done for its scope (2026-11-08).** V1–V4 are fixed and tested: rules validate all eight slots, ordering, overlap and break placement; `rejection_reason` persists; published versions are immutable; the editor is class-gated with no `'10A'` fallback. Tests 9–15, 21–30, 34 (client), and 38 (stream) keep their UI/unit coverage; tests 16–17 and 34 now have explicit source-contract assertions. Test 35 is enforced on the screen teachers open. Test 36 reject persists when allowed and fails truthfully when denied. Test 37 no longer permits in-place senior edits. Notifications (V5) stay in M6; audit truthfulness (V6) and admin grant/revoke UI (V7) are non-blocking follow-ups; “direct rules denial” remains source-contract only (V8). Full suite re-run: **440/440**. Tests 31–33 stay in M3.

---

## M3 — Timetable advanced

**Goal:** scheduling conveniences + conflict detection on top of the M2 engine.
**Depends on:** M2.
**Current state:** ✅ **Done for its scope (2026-11-08).** See [`M3_VERIFICATION.md`](M3_VERIFICATION.md).

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

✅ **Done for its scope (2026-11-08).** Tests 18–19 are enforced client-side in `TimetableService.findTimetableConflicts` and block `publishTimetable` by default (pure detector + publish-denial tests). Tests 31–32 copy only selected target days into new drafts and never mutate the source day. Test 33 is a date-specific override version (`override_date`) that wins only on its exact date; the recurring version is untouched. Substitution is stored on the override version only, shown in the teacher editor and student banner, and audited as `substitute`. Transition gaps are still permitted by the M2 validator (`accepts transition gaps between periods`). **Caveats kept honest:** conflict detection is a client-side query at publish (no transaction; concurrent publishes can race, and server-side validation at scale stays Blaze-deferred); rules tests are source-contract assertions, not emulator denials; substitution notification fan-out is M6/test 60, so M3 only writes the audit entry. Verification: M3 suite **23/23**, full suite **463/463**, `flutter analyze` 0 errors / 0 warnings (20 pre-existing infos), rules deployed, commit on `mustafa1`.

---

## M4 — House communication groups

**Goal:** per-house group where **authorised leaders + staff send** and **students read-only** (cannot send, cannot upload attachments). Auto-membership by house; cross-house access denied; transfer revokes old / grants new.
**Depends on:** M1 house identity (profile `house`), existing chat infra. Independent of M2/M3.
**Current state:** ✅ **Done for its scope (2026-11-08).** See [`M4_VERIFICATION.md`](M4_VERIFICATION.md). A dedicated `house_groups/{houseId}/messages` channel now sits alongside the existing 1-to-1 chat; `house_ai_chat_screen.dart` remains an AI bot, not the group.

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

✅ **Done for its scope (2026-11-08).** Membership is derived entirely from the verified `users/{uid}.house_name` (no join or membership collection), so a house transfer revokes the old group and grants the new one without migration. Tests 39–47 cover auto-join, same-house read, student/prefect read-only, attachment denial, captain/vice/sports/head/council send, and staff/faculty send. Test 48 is enforced in `firestore.rules` via `isSameHouse`; test 49 is profile-derived and preserves `class_id`. Categories are the closed set `general`/`announcement`/`event`/`sports`; moderators can pin/hide/delete, and rules make message text/authorship immutable. **Caveats kept honest:** attachments are compressed image data URLs stored in the `attachment_url` Firestore field (no Storage path change); house announcements do not fan out notifications until M6/test 61; message streams are capped at 200; rules tests remain source-contract assertions. Verification: M4 suite **37/37**, full suite **500/500**, `flutter analyze` 0 errors / 0 warnings (20 pre-existing infos), rules deployed, commit on `mustafa1`.

---

## M5 — Class groups & academic communication

**Goal:** per-class channel + class announcements; class teacher / subject teacher / class rep permissions; configurable student send; class-scoped isolation.
**Depends on:** M1 (verified `class_id`) + M4 group machinery.
**Current state:** ✅ **DONE for scope (2026-11-08).** Live per-class channel with verified auto-membership, rules-scoped senders, configurable student posting, categories/attachments/moderation, and cross-class isolation. See [`M5_VERIFICATION.md`](M5_VERIFICATION.md).

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
**Delivered 2026-11-08:** targeted `test/class_group_test.dart` **47/47**, full suite **547/547**, analysis 0 errors/0 warnings, rules compiled and released. Commit follows `M5_VERIFICATION.md`; notification fan-out for class announcements stays M6/test 62.

---

## M6 — Notification engine (in-app, Spark)

**Goal:** unified in-app notifications with read/unread, priority, dedupe; alerts for timetable/class/house changes.
**Depends on:** M2/M4/M5 events.
**Current state:** ✅ **DONE for scope (2026-11-08; hardened 2026-11-09).** Unified in-app notifications with deterministic dedupe IDs, priority chips, unread count stream, and mark-read controls. Hardening adds truthful roster-lookup failure reporting, substitution fan-out warnings, failure-safe swipe deletion, and a cached per-user unread stream. See [`M6_VERIFICATION.md`](M6_VERIFICATION.md).

**Requirements (spec §5, tests 60–62):**
- `notifications` stream + read/unread engine; priority; dedupe (idempotency key per event).
- Timetable publish → notify affected class (60); house announcement → notify correct house (61); class announcement → notify correct class (62).
- **Spark path:** client-side fan-out — on publish, the client writes a notification doc per recipient (roster loop). The existing rules allow any signed-in user to create a notification in another user's subcollection, which enables this. **Blaze-deferred:** server-side fan-out via Cloud Functions (scalable, atomic). Track in BLAZE_REQUIRED_FEATURES.md.
- No FCM push required for Spark (in-app only); `firebase_messaging` not in use.

**Data/Service/Rules/UI:** extend the existing notification subcollection + validator (add `priority`, `dedupe_key`, `category`); service `getNotificationsStream`, `markRead`, `fanOutToRoster` (truthful, batched); UI notification center + unread badges on dashboard (M8).
**Tests (60–62):** publish/announcement produces exactly the right recipients' notifications; dedupe prevents doubles; read/unread toggles; rules validator rejects malformed docs.
**Robustness:** fan-out is truthful (partial failure surfaced, not phantom success); dedupe idempotent; recipient scoping correct (no cross-house/class leakage); validator closed whitelist.
**Definition of done:** tests 60–62 pass; in-app engine works on Spark; Blaze fan-out documented as deferred; deployed; committed.
**Delivered 2026-11-08:** targeted `test/notification_test.dart` **30/30**, full suite **577/577**, analysis 0 errors/0 warnings, rules compiled and released. Hooks wired into `timetable_service`, `house_group_service`, `class_group_service`; notification center screen and home bell/badge integrated.

---

## M7 — Admin Command Center expansion

**Goal:** central admin control over academics, teachers, houses, groups, users, timetable approvals, audit logs, promotion.
**Depends on:** M1–M6.
**Current state:** ✅ **DONE for scope (2026-11-08; hardened 2026-11-09).** 6-tab Admin Command Center with section management, transfers, house assignment, academic year promotion (houses preserved), timetable approval queue, and append-only audit log viewer. Hardening adds truthful live-write failures, roster-error reporting for batch promotion, missing-scholar-number failures, and best-effort secondary notifications. See [`M7_VERIFICATION.md`](M7_VERIFICATION.md).

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
**Delivered 2026-11-08; hardened 2026-11-09:** targeted `test/admin_command_center_test.dart` **30/30** plus `test/academic_section_auto_assign_test.dart` **3/3** (33/33), full suite **625/625**, analysis no issues, rules compiled and already live. See [`M7_VERIFICATION.md`](M7_VERIFICATION.md).

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

1. **Close M2 blockers V1–V4** in [`M2_VERIFICATION.md`](M2_VERIFICATION.md) (rules slot/overlap/break, reject field, published immutability, editor gate). M2a is already in `f8095fd`; the 6-day week is already in the student tab.
2. **M3** only after that commit is pushed — tests 18–19, 31–33.
4. **M4** (house groups) — independent of M2/M3; high security value (read-only students).
5. **M5** (class groups) — ✅ delivered 2026-11-08; reuses M4 machinery + new roles. See [`M5_VERIFICATION.md`](M5_VERIFICATION.md).
6. **M6** (notifications) — ✅ delivered 2026-11-08; wires M2/M4/M5 events. See [`M6_VERIFICATION.md`](M6_VERIFICATION.md).
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