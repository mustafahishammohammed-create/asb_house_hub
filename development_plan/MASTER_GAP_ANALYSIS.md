# ASB Digital Campus — Master Spec Gap Analysis & Build Plan

Input: `MASTER DEVELOPMENT PROMPT — ASB DIGITAL CAMPUS` (12-section spec, attached 2026-11-08).
Method: first-hand inspection of the current codebase (spec §12 requirement) before any implementation.
Baseline: `mustafa1` at `15aa7c3`, plus the M8/P0 and follow-up batches through `b09a57d` (2026-11-10). M1-M7 are delivered; M8 dashboard/acceptance is delivered with **64/64 acceptance rows PASS and zero partials** (tests 5, 22, 24, 25 closed). `flutter analyze --no-pub` = **No issues found**; full suite **662/662**. Firebase **Spark** (no Blaze) - see `election_audit/BLAZE_REQUIRED_FEATURES.md` and `ACCEPTANCE_MATRIX.md`.

Legend: **EXISTS** (keep) · **PARTIAL** (extend) · **MISSING** (build) · **CONFLICT** (spec contradicts current code).

---

## 1. Academic classification (spec §1) — ✅ DELIVERED (M1)

- **DELIVERED** — `AcademicStructure` covers **LKG, UKG, Grades 1–12** (14 levels), canonical class ids (`11D`, `LKG-A`), `gradeLevels`, `nextGrade`, and `nextClassId`.
- **DELIVERED** — Admin-managed `academic_classes` registry: create/rename/activate/deactivate sections, class teacher, subject teacher UIDs, student posting, timetable permissions. Identity fields are immutable; transfers create a new placement.
- **DELIVERED** — Signup captures grade + section + house and writes `class_id`; `class_verified` starts `false`. Admin verification/approval, roster view, transfer, house assignment, and academic-year promotion are in the M7 Admin Command Center.
- **DELIVERED** — Timetable and groups are keyed by canonical `class_id`, so 9A and 9D are distinct.
- **KNOWN LIMIT** — Rules tests are source-contract assertions, not emulator denials. See `M7_VERIFICATION.md` and `ACCEPTANCE_MATRIX.md` tests 1–8.

## 2. Timetable (spec §2) — ✅ DELIVERED (M2/M3, M8 test 14)

- **DELIVERED** — Mandated structure: exactly 8 teaching periods × 45 minutes plus one separate 30-minute break, default break after Period 4. Durations are derived, not teacher-editable; start times are customizable and end times computed.
- **DELIVERED** — Per-section/per-day versioned timetables with draft → submit → publish, immutable published versions, restore-as-new-version, effective dates, one-day overrides, substitution markers, version history and audit.
- **DELIVERED** — Validation for period count, numbering, missing starts, chronology, overlaps, break placement, Friday rejection, and timetable-mismatched override dates; the editor blocks save/publish on errors.
- **DELIVERED** — Client-side cross-class teacher/room double-booking detection with a blocking conflict dialog (tests 18–19). It is not transactional; concurrent publishes can race, and server-side validation at scale remains Blaze-deferred.
- **DELIVERED** — Copy-to-selected-days (tests 31–32), temporary one-day schedules (33), and the M8 moving-break recalculation control (test 14).
- **DELIVERED** — Student timetable reads are scoped to the verified class by Firestore rules; the broad signed-in published clause was removed (P1-04 fixed, acceptance test 5 PASS). Staff retain published/submitted cross-class reads for conflict checks and approval by design.

## 3. House communication groups (spec §3) — ✅ DELIVERED (M4, 2026-11-08)

- **DELIVERED** — `house_groups/{houseId}` + `messages` subcollection, rendered by `HouseGroupScreen` and reachable from Home. The pre-existing `chat_service.dart` remains **1-to-1 private rooms** (`chats` collection, `participants arrayContains uid`, `getOrCreateChatRoom(otherUserId)`), council/admin oriented; `house_ai_chat_screen.dart` remains an AI bot, not the group.
- **DELIVERED** — auto-membership from the verified profile house (no self-asserted join/membership document); role-restricted send (captains/vice/sports/head-boy/head-girl/council/staff send; regular students and prefects read-only); categories (`general`, `announcement`, `event`, `sports`); pin/hide/delete moderation; backend send/read isolation in `firestore.rules`.
- **DELIVERED** — cross-house isolation and transfer semantics are profile-derived: changing `house_name` revokes the old group and grants the new one while preserving the academic `class_id`.
- **KNOWN LIMITS** — attachments are compressed image data URLs in the `attachment_url` field (no Storage pipeline); notification fan-out for house announcements stays M6/test 61; rules tests are source-contract assertions. See `M4_VERIFICATION.md`.

## 4. Class groups / academic communication (spec §4)

- **DELIVERED 2026-11-08** — per-class channel `class_groups/{classId}` + messages. Membership derives from verified `class_id` + `class_verified` on the profile (no join document); the class teacher and assigned subject teachers are scoped by `academic_classes` (`class_teacher_uid`, `subject_teacher_uids`); class representatives/vice always send; ordinary students/prefects send only when the school enables `student_posting_enabled`; senior admins view/moderate across classes but do not send. Categories, image data-URL attachments, and pin/hide/delete moderation reuse M4. Read/write isolation is enforced in `firestore.rules`.
- **KNOWN LIMITS** — class announcements do not fan out notifications until M6/test 62; attachments are Firestore data-URL strings, not Storage; message streams are capped at 200; rules tests are source-contract assertions. See `M5_VERIFICATION.md`.

## 5. Notification engine (spec §5)

- **DELIVERED 2026-11-08, HARDENED 2026-11-09** — unified in-app notification engine under `users/{uid}/notifications`. Deduplicated client-side fan-out on timetable publishes (test 60), substitutions/overrides (60), house announcements (61), and class announcements (62). Stream list, unread badges on the home AppBar and drawer, priority badges, mark-as-read on tap, and mark-all-read. Deterministic document IDs prevent duplicates, creation payloads omit `is_read` to protect read state, and rules restrict read updates to the recipient. Roster-lookup failures return an explicit error result instead of a phantom complete fan-out; substitution failures surface through `lastNotificationResult`; failed swipe deletes snap back with an error.
- **KNOWN LIMITS** — fan-out runs in a client-side roster loop on Spark (Cloud Functions server fan-out stays Blaze-deferred); no mobile OS push notifications (FCM); notification streams cap at 100 newest items; roster lookups cap at 500 and batch writes at 400; no automatic retry after a roster-lookup failure; rules tests are source-contract assertions. See `M6_VERIFICATION.md`.

## 6. Admin Command Center (spec §6) — ✅ DELIVERED (M7)

- **DELIVERED** — `AdminAcademicsScreen` six-tab command center: academics/sections, verification queue, rosters, transfers, house assignment, promotion, timetable approval queue, audit log viewer, and user status/suspension.
- **DELIVERED** — `admin_claims_screen.dart` (point claims + medical reports) and admin gates in `home_screen.dart` remain. Election/gamification admin surfaces exist.
- **DELIVERED** — Every admin action is server-gated by rules; live denials return `false` without phantom cache entries. Batch promotion reports total/promoted/failed and distinguishes a roster-read error from an empty roster. Audit writes are best-effort and never roll back a successful primary action.
- **KNOWN LIMITS** — Sequential batch promotion (not transactional), cached queue fallback can be stale, suspension does not revoke an already-issued Auth token, rules tests are source contract. See `M7_VERIFICATION.md` and acceptance tests 55–59/63–64.

## 7. Roles / RBAC (spec §9.3)

- **EXISTS** — `hierarchy_service.dart`: super_admin; teacher/faculty/principal/staff/faculty_advisor/teacher_lead; captain/vice_captain/house_captain/house_vice_captain; council (head_boy, head_girl, deputy_*, sports_captain, sports_vice_captain, cultural_secretary, head_of_activities); prefect/student_rep/grade_prefect. Rules helpers mirror these, and M4 extended the `isValidUser` role whitelist with the council/head/deputy/activity roles used by house-group senders.
- **DELIVERED (M5)** — `class_teacher`, `subject_teacher`, `class_representative`, `vice_class_representative`, and `parent` roles added client-side and to the rules role whitelist; `class_teacher`/`subject_teacher` count as faculty, and per-class teaching assignments live on `academic_classes`. A people-picker for those UIDs is an M7 admin-expansion improvement.
- **CONFLICT (known, fixed for academics)** — client `isTeacherOrFaculty` admits faculty_advisor/teacher_lead; rules historically didn't (A6 — addressed in `1f426c2`; keep lists synced).

## 8. Student profile / dashboard (spec §7) — ✅ DELIVERED (M8)

- **DELIVERED** — Profile has scholar_no, full_name, class_level, division, class_id, class_verified, house, role, age. `home_screen.dart` adapts tiles by role/house and simplifies the UI for younger students (LKG–UKG, Grades 1–5).
- **DELIVERED** — Verified-class badge and class-teacher display in both the dashboard and profile tabs, reading `academic_classes/{classId}` live with a verified cached fallback.
- **DELIVERED** — Dashboard "today's timetable / Now / Next / Break" card driven by the **published section timetable**, with all eight periods plus the BRK row, published-only data, and a verified-class gate. Unverified profiles render a truthful notice instead of another class's schedule.
- **DELIVERED** — Unread class/house/timetable counts from the M6 notification stream, opening the notification centre.
- **DELIVERED** — Responsive dashboard padding at desktop widths; younger students do not see council/sports/AI/event-wall clutter or election/chat/claim cards.
- **DELIVERED** — The dashboard/timetable UI scopes to the verified class and Firestore rules deny students another class's timetable; staff cross-class published/submitted reads remain for conflict checks and approval (P1-04 fixed, acceptance test 5 PASS).

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
- **M4 — House communication groups. ✅ DELIVERED 2026-11-08.** Profile-derived auto-membership; role-restricted send (students/prefects read-only) enforced in rules; categories; pin/hide/delete moderation; cross-house isolation and transfer semantics. *(Depends on M1 house identity; independent of M2/M3.)* See `M4_VERIFICATION.md`.
- **M5 — Class groups & academic communication. ✅ DELIVERED FOR SCOPE 2026-11-08.** Verified-class auto-membership; class-teacher and assigned-subject-teacher send; class representative/vice send; configurable `student_posting_enabled` (default read-only); categories, data-URL attachments, pin/hide/delete moderation; cross-class isolation in rules. *(Depends on M1 + M4 machinery.)* Class notification fan-out stays M6/test 62; rules tests are source contract. See `M5_VERIFICATION.md`.
- **M6 — Notification engine (in-app, Spark). ✅ DELIVERED 2026-11-08.** Unified in-app notifications; timetable publish (test 60), house announcement (61), class announcement (62) fan-out; deterministic dedupe doc IDs; priority badges; unread badge counter; mark-read/mark-all-read; rules-enforced read-state protection. *(Depends on M2/M4/M5 events.)* See `M6_VERIFICATION.md`.
- **M7 — Admin Command Center expansion. ✅ DELIVERED 2026-11-08, HARDENED 2026-11-09.** Academic/section management (LKG–12), verification, transfers, house assignment, academic year promotion (houses strictly preserved), timetable approval queue (approve/reject/audit), one-day override/restore, append-only audit log viewer, and user status management / unauthorized access blocking. Live write denials return `false` without phantom cache entries; batch promotion distinguishes roster-read errors from an empty roster and counts missing scholar numbers as failures; secondary notifications are best-effort. See `M7_VERIFICATION.md`.
- **M8 — Dashboard & profile polish + acceptance. ✅ DELIVERED 2026-11-10, all 64 rows PASS.** Verified-class dashboard (today/current/next/break), class-teacher field, unread breakdown, younger-student simplification, responsive layout, and the full 64-row spec §11 acceptance matrix. Tests 5, 22, 24, and 25 are closed by direct rules/widget evidence. See `M8_VERIFICATION.md` and `ACCEPTANCE_MATRIX.md`.

**Blaze-deferred (add to BLAZE_REQUIRED_FEATURES.md):** server-side notification fan-out, atomic cross-collection promotion/transfer transactions, server timetable conflict validation at scale.

## Acceptance mapping

Spec §11 tests 1–64 map to modules: 1–8 → M1; 9–20 → M2; 21–38 → M2/M3; 39–49 → M4; 50–54 → M5; 55–64 → M6/M7. The row-by-row evidence, status, and limitation is in `ACCEPTANCE_MATRIX.md` and enforced by `test/acceptance_matrix_test.dart`.

**Current honest score:** 64 PASS · 0 PARTIAL · 0 MISSING. Test 5 (student timetable cross-class reads) is closed by class-scoped Firestore rules; tests 22, 24, and 25 are closed by direct widget tests.

## Next work (post-M8)

1. **P1-01 secrets** — build the production release with all four `--dart-define` secrets and remove reliance on the development fallbacks.
2. **Firebase Storage initialization** — enable Storage, deploy `storage.rules`, and verify >700 KB circular PDF uploads (D9 in `BLAZE_REQUIRED_FEATURES.md`).
3. **Blaze-deferred** — server-side notification fan-out, atomic promotion/transfer transactions, and server-side timetable conflict validation at scale.