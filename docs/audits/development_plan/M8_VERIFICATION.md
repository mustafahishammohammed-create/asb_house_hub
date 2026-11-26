# M8 verification — dashboard, profile polish, and §11 acceptance

**Date:** 2026-11-10
**Last verified:** 2026-11-11 (grade targeting and stream-error banner wording)
**Branch:** `mustafa1`
**Baseline:** `15aa7c3` (M7 hardening), plus the M8 and follow-up batches through `71a1afb`, plus the campus-events lifecycle and grade-targeting batches.
**Method:** first-hand implementation and test runs; read of `home_screen.dart`, `notification_service.dart`, `app_notification.dart`, `academic_class.dart`, `teacher_timetable_editor_screen.dart`, `school_circular_composer.dart`, `school_notice.dart`, `firestore.rules`, `storage.rules`, the M2–M7 verification files, and the full test suite. No claim below is copied from an earlier report without being re-checked.

## Verdict

M8 is **delivered for its stated Spark scope**, with an honest acceptance score of **64 PASS · 0 PARTIAL · 0 MISSING** across the 64 spec §11 tests. The previously open rows 5, 22, 24, and 25 are closed by direct evidence; no row is counted as passing on inspection alone.

A follow-up campus-events batch closes the remaining non-Blaze gaps from `ACADEMIC_CHANGE_PROPOSAL.md`: staff drafts, preview, publication, editing, and cancellation; student house filtering; honest lifecycle rendering; and real student registration with staff-visible participant records. It does not change the 64-row acceptance count, which measures spec §11 rather than the whole product.

## Delivered

| Area | Evidence |
|---|---|
| **Verified-class dashboard** | `home_screen.dart` renders a verified/unverified class strip on the dashboard and profile. Verified classes show `Verified Class · <classId>` and the class teacher from `academic_classes/{classId}` (live stream with verified cached fallback). Unverified profiles show `Class not verified` and never render a timetable. |
| **Today's published timetable** | `_buildTodayTimetableCard` reads `TimetableService.getActiveTimetableStream` for the verified `class_id` only. Shows all 8 teaching periods plus a `BRK` row, a `Now` / `Next` / `Break` chip row, the day label, the period count, and truthful empty/weekend states. Published versions only. |
| **Unread breakdown** | `NotificationUnreadBreakdown` + `NotificationService.getUnreadBreakdownStream` count unread class/house/timetable notifications. The dashboard card shows the total and per-category pills and opens `NotificationCenterScreen`. The bell badge remains the total unread count. |
| **Younger-student simplification** | `AcademicStructure.isPrimaryGrade` covers LKG/UKG + Grades 1–5. Younger students do not see the council arena, sports league, AI companion, event wall, election, 1:1 chat, or certificate-claim cards. The class timetable, class group, house group, account switching, and wallet remain. |
| **Responsive layout** | Dashboard padding increases to 96 px at widths ≥ 900 px; the timetable/period rows use flexible layouts. A 360×740 overflow test passes. |
| **Moving-break acceptance fix** | The teacher editor now has `break_after_period_button`; `_moveBreakAfter` regenerates every period start sequentially from Period 1 and recalculates the 30-minute break window. Acceptance test 14 is closed by a widget test. |
| **P0 rules fix** | `isSuperAdmin()` no longer accepts `(?i)^admin@.*` or `(?i)^11209@.*`; only the exact bootstrap emails, claims, `admin_roster`, `users.role`, and `school_members.role` remain. Assertions in `test/widget_test.dart` fail if a prefix regex returns. |
| **Acceptance matrix** | `development_plan/ACCEPTANCE_MATRIX.md` has exactly 64 rows, one per spec test, with implementation, automated evidence, rules evidence, status, and limitation. `test/acceptance_matrix_test.dart` enforces row count, IDs, summary counts, cited-file existence, and key rules contracts. |
| **Truthful event publishing** | `AuthService.createCampusEvent`, `updateCampusEvent`, `cancelCampusEvent`, and `setEventRegistration` treat the live Firestore write as authoritative: a permission denial or any other write failure returns `false` and claims nothing. Local/demo mode caches published events and labels the result device-only; private drafts are rejected offline rather than written to the shared device cache. `test/campus_event_test.dart` covers local caching, id synthesis, live denial, drafts, updates, cancellation, and RSVP denial. |
| **Campus-event lifecycle** | `CampusEvent` carries `draft` / `published` / `cancelled` status, house scope, audit fields, and `isOngoingAt`, `isConcludedAt`, and `isLiveAt` derivations. `events_screen.dart` renders `DRAFT`, `UPCOMING`, `LIVE NOW`, `CONCLUDED`, and `CANCELLED` badges, closes registration after cancellation or conclusion, and stores and displays the optional cancellation reason. The manual `is_live` flag only highlights an event inside its own start/end window; it cannot keep an event live forever. |
| **Staff composer, house scope, and grade range** | Staff entry points are gated to `HierarchyService.isSuperAdmin || isTeacherOrFaculty`, matching the Firestore `isAdmin()` write gate. The composer validates title, venue, category, house scope, optional grade range, and start-before-end; offers preview-before-publish, private draft save, edit, and cancel-with-reason; and uses server timestamps for `created_at` / `updated_at`. The list exposes an All/School-wide/Ruby/Sapphire/Emerald/Topaz filter. A "Limit to a grade range" switch adds From/To grade dropdowns (LKG/UKG = 0, Grade 1–12 = 1–12); house scope and grade range apply together. Students only see published school-wide or own-house events that also match their grade. |
| **Student registration and participant lists** | Registration is written to `events/{eventId}/registrations/{uid}` with the signed-in UID, event id, optional name/scholar number, and server timestamp. Students can create/delete only their own record; staff can read the participant list. Local sample events do not pretend to collect attendees. Widget tests assert a student sees no staff publish action, a staff member can open the composer, and house filtering removes unrelated events. |

## Campus-events completion and grade-targeting batches

The following gaps from `ACADEMIC_CHANGE_PROPOSAL.md` row **Events** are closed for Spark scope:

1. **Staff publisher.** `events_screen.dart` has a staff-only composer with preview, publish, private draft, edit, and cancel-with-reason. The compose button is hidden from students and guarded again inside the composer.
2. **Draft privacy.** Drafts are stored only in Firestore and are readable by staff; they are never written to the shared device cache, and local mode rejects draft creation with an explicit message.
3. **House scope.** The rules allow students to read only `status == 'published'` events where `house_scope == 'all'` or `isSameHouse(...)`. The screen adds an All/School-wide/per-house filter. Stored house values are normalized to lower-case canonical names. The live stream merges the two scoped queries by replacing each query's previous result, so an event that is cancelled or unpublished disappears from the student list rather than lingering in the merged map.
4. **Lifecycle truth.** Status is derived from `status` plus the start/end window. Cancelled and concluded events cannot accept registrations. The old indefinite manual `is_live` behaviour is gone; `isLiveAt` requires both the flag and the active window.
5. **Server timestamps and validation.** Writes use `created_at` / `updated_at` server timestamps. Model and rules both enforce title, description length, category, venue, house scope, non-zero duration, and start-before-end.
6. **Registration records.** `setEventRegistration` writes a self-owned document under `events/{eventId}/registrations/{uid}` in live mode and uses a device-local registered set only in local mode. The rules also read the parent event and require it to still be `published`, before its `end_time`, and either school-wide, in the student's house, or accessed by staff. A denied write returns `false`; the UI never shows a confirmed RSVP after a failure.
7. **Participant lists.** Staff see the event's attendee stream with names and scholar numbers (up to 25 shown plus a count). Local sample events explicitly state that participant records require Firebase.
8. **Honest copy.** Removed claims that card actions insert a device-calendar entry, that the live panel streams audio, that cheering earns spirit points, and that event attendance automatically awards points. The stream-error banner now says "Live campus schedule unavailable. Showing previously loaded events." instead of implying a real device-calendar feature.
9. **Grade targeting.** Staff can optionally publish to a grade band via "Limit to a grade range" with From/To grade dropdowns. `grade_min` / `grade_max` are stored on the event (`0` = LKG/UKG, `1–12` = Grade 1–12, `0–12` = all grades). `users.grade` is backfilled from `class_level`. Because Firestore rules are not filters, list queries remain scoped by status and house and the grade band is applied client-side for the list; direct document reads and registration creates are grade-gated in the rules with `isGradeEligibleFor(...)`. Missing grade fields fail open for legacy documents, and an invalid or reversed range is rejected client-side and by the rules.

Rules were compiled and released to `cloud.firestore` on 2026-11-10. There is still no authenticated end-to-end Firebase test or emulator harness, so denial behaviour is verified by unit tests plus the deployed rules source contract, not by an executed denied request.

## Test evidence (actual runs)

| Command | Result |
|---|---|
| `flutter test test/dashboard_profile_test.dart` | **6/6 passed** |
| `flutter test test/teacher_timetable_editor_test.dart` | **15/15 passed** (includes the moving-break, multi-class picker, and time-picker tests) |
| `flutter test test/acceptance_matrix_test.dart` | **7/7 passed** |
| `flutter test test/circular_composer_test.dart` | **9/9 passed** |
| `flutter test test/campus_event_test.dart` | **27/27 passed** (lifecycle, serialization, validation, drafts, updates, cancellation reason, grade targeting, scoped streams, registration, attendees, rules contracts, staff/student UI) |
| `flutter test` (full suite) | **684/684 passed** |
| `flutter analyze --no-pub` | **No issues found** |
| `firebase.cmd deploy --only firestore:rules` | **compiled successfully; released to `cloud.firestore`** |
| `firebase.cmd deploy --only storage` | **blocked:** Firebase Storage is not initialized on `asb-house-hub`; see D9 in `BLAZE_REQUIRED_FEATURES.md` |
| `flutter build windows --release` | **built** `build\windows\x64\runner\Release\asb_house_hub.exe` |

### Release artifact

| Artifact | Size | Timestamp |
|---|---|---|
| `build\windows\x64\runner\Release\data\app.so` | 13,616,008 bytes | 2026-11-11 15:22:13 |
| `build\windows\x64\runner\Release\asb_house_hub.exe` | 16,165,888 bytes | 2026-11-11 14:49:26 |

The Dart snapshot was rebuilt after the circular, timetable-rules, campus-events, cancellation-reason, grade-targeting, and stream-merge changes. The desktop launchers (`Launch_ASB_House_Hub.bat`, `Run_ASB_House_Hub.bat`) run this Release executable.

## Acceptance status

| Status | Count | Tests |
|---|---|---|
| **PASS** | 64 | All rows 1–64 |
| **PARTIAL** | 0 | — |
| **MISSING** | 0 | — |

The four previously open rows were closed by direct evidence in this batch:

1. **Test 5 — another class's timetable.** `timetable_versions` reads now scope students to `isVerifiedClassMember(resource.data.class_id)`; the broad signed-in published clause and `resource == null` list branches were removed. Staff keep published/submitted cross-class reads for the M3 conflict check and M7 approval queue. `test/timetable_engine_test.dart` asserts the contract, and the rules compiled and deployed.
2. **Test 22 — multi-class editor picker.** `test/teacher_timetable_editor_test.dart` opens the picker, selects a class, and asserts navigation plus the class-specific editor.
3. **Tests 24–25 — per-period time pickers.** Direct widget tests open the P1 and P8 time pickers, enter new times, and assert the derived 45-minute end while other periods stay unchanged.

## Honest limits (Spark / project convention)

1. **Rules tests are source-contract assertions.** No Firebase emulator harness exists. Firestore rules are compiled and deployed; the key contracts are asserted in the suite. Evaluated denial is not claimed beyond that convention. Campus-event list queries stay status/house-scoped because rules are not filters; per-event grade bands are applied client-side for lists and enforced by rules on direct document reads and registration creates.
2. **Firebase Storage is not initialized.** `firebase deploy --only storage` fails with *"Firebase Storage has not been set up on project 'asb-house-hub'"*. Circular PDFs therefore use the inline Base64 fallback up to 700 KB; larger files fail with an explicit Storage-required error. See D9 in `election_audit/BLAZE_REQUIRED_FEATURES.md`.
3. **No Cloud Functions or FCM.** Notification fan-out is client-side, capped at 500 roster lookups, 400 writes per batch, and 100 streamed notifications.
4. **P1-01 secrets remain a documented residual risk.** The release was built without `--dart-define` values, so it uses the development fallbacks. A production build must pass `ELECTION_HMAC_SALT`, `VAULT_SECRET`, `GAMIFICATION_HMAC_SECRET`, and `SPORTS_CERT_SECRET`. Removing the fallbacks without supplying the defines would break live account switching, elections, gamification, and sports signatures.
5. **Client-side conflict detection is not transactional.** Two editors can publish conflicting timetables concurrently; server-side validation at scale is Blaze-deferred.
6. **Suspension does not revoke an already-issued Firebase Auth token.** Full revocation requires the Admin SDK on Blaze.

## Files in this batch

- `firestore.rules` — exact bootstrap admin emails; student-scoped timetable reads; circular notice validator and attachment limit.
- `storage.rules` — `circulars/{noticeId}/{fileName=**}` PDF path (authored; Storage not initialized).
- `lib/models/academic_class.dart` — `isPrimaryGrade`.
- `lib/models/app_notification.dart` — `NotificationUnreadBreakdown`.
- `lib/models/school_notice.dart` — circular/notice model, publish result, inline-size ceiling.
- `lib/services/notification_service.dart` — unread breakdown stream + widget-test override.
- `lib/models/campus_event.dart` — status/audit fields, cancellation reason, grade range (`grade_min` / `grade_max`) and registration DTO.
- `lib/services/auth_service.dart` — truthful circular publish/upload, notice cache, foundational events/notices, grade-aware event streams, profile grade backfill, and registration/cancellation writes.
- `lib/screens/home_screen.dart` — M8 dashboard, circular feed/composer, attachment opening, cache controls.
- `lib/screens/events_screen.dart` — staff composer with grade-range controls, lifecycle badges, grade badges, honest stream-error banner, registration, and cached fallback.
- `lib/screens/teacher_timetable_editor_screen.dart` — moving-break control and period time pickers.
- `lib/widgets/school_circular_composer.dart` — title/details/category/audience/PDF composer with truthful errors.
- `test/dashboard_profile_test.dart` — 6 dashboard/profile tests.
- `test/teacher_timetable_editor_test.dart` — moving-break, multi-class picker, and time-picker tests.
- `test/circular_composer_test.dart` — 9 circular service/composer/rules tests.
- `test/campus_event_test.dart` — 27 campus-event lifecycle, grade-targeting, registration, stream, rules-contract, and widget tests.
- `test/acceptance_matrix_test.dart` — 7 matrix/rules guards.
- `test/timetable_engine_test.dart`, `test/timetable_m3_test.dart` — student timetable read-scoping contracts.
- `test/widget_test.dart` — P0 regex-absence assertions.
- `development_plan/ACCEPTANCE_MATRIX.md` — 64-row acceptance matrix, all PASS.
- `development_plan/PROJECT_PROBLEMS.md` — prioritized problem register (P1-04 fixed).
- `development_plan/MASTER_GAP_ANALYSIS.md`, `development_plan/REMAINING_MODULES_REPORT.md` — truth pass.
- `election_audit/BLAZE_REQUIRED_FEATURES.md` — Storage initialization, Blaze scope, and client fallbacks.

## Definition of done check

- [x] Verified-class dashboard with today/Now/Next/Break and all 8 periods + BRK.
- [x] Class-teacher display and verified badge on dashboard/profile.
- [x] Unread class/house/timetable counts.
- [x] Younger-student simplification.
- [x] Responsive narrow/wide layouts; no overflow in tests.
- [x] 64-row acceptance matrix + enforceable harness.
- [x] Exact bootstrap admin emails; no prefix elevation.
- [x] Full suite green (684/684), analyzer clean, Firestore rules deployed, release rebuilt.
- [x] Campus events: staff composer with preview/publish/edit/cancel, private drafts, house filtering, optional grade-range targeting, server timestamps, venue/category/time validation, concluded/cancelled rendering, registration records, and participant lists.
- [x] Zero partials: tests 5, 22, 24, and 25 closed by direct evidence.
- [x] Circular PDF composer with title/details/category/audience, truthful upload failures, and local-only warning.
