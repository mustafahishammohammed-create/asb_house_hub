# M8 verification — dashboard, profile polish, and §11 acceptance

**Date:** 2026-11-10
**Branch:** `mustafa1`
**Baseline:** `15aa7c3` (M7 hardening), plus the M8 and follow-up batches through `b09a57d`.
**Method:** first-hand implementation and test runs; read of `home_screen.dart`, `notification_service.dart`, `app_notification.dart`, `academic_class.dart`, `teacher_timetable_editor_screen.dart`, `school_circular_composer.dart`, `school_notice.dart`, `firestore.rules`, `storage.rules`, the M2–M7 verification files, and the full test suite. No claim below is copied from an earlier report without being re-checked.

## Verdict

M8 is **delivered for its stated Spark scope**, with an honest acceptance score of **64 PASS · 0 PARTIAL · 0 MISSING** across the 64 spec §11 tests. The previously open rows 5, 22, 24, and 25 are closed by direct evidence; no row is counted as passing on inspection alone.

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
| **Truthful event publishing** | `AuthService.createCampusEvent` now treats the live Firestore write as authoritative: a permission denial or any other write failure returns `false` and caches nothing. The previous implementation cached locally and returned `true`, which made `events_screen.dart` claim the event was broadcast while nothing was written. Local/demo mode still caches and labels the result as device-only. `test/campus_event_test.dart` covers local caching, id synthesis, live denial, preservation of existing cache, and the no-app case. |

## Test evidence (actual runs)

| Command | Result |
|---|---|
| `flutter test test/dashboard_profile_test.dart` | **6/6 passed** |
| `flutter test test/teacher_timetable_editor_test.dart` | **15/15 passed** (includes the moving-break, multi-class picker, and time-picker tests) |
| `flutter test test/acceptance_matrix_test.dart` | **7/7 passed** |
| `flutter test test/circular_composer_test.dart` | **9/9 passed** |
| `flutter test test/campus_event_test.dart` | **5/5 passed** |
| `flutter test` (full suite) | **662/662 passed** |
| `flutter analyze --no-pub` | **No issues found** |
| `firebase.cmd deploy --only firestore:rules` | **compiled successfully; released to `cloud.firestore`** |
| `firebase.cmd deploy --only storage` | **blocked:** Firebase Storage is not initialized on `asb-house-hub`; see D9 in `BLAZE_REQUIRED_FEATURES.md` |
| `flutter build windows --release` | **built** `build\windows\x64\runner\Release\asb_house_hub.exe` |

### Release artifact

| Artifact | Size | Timestamp |
|---|---|---|
| `build\windows\x64\runner\Release\data\app.so` | 13,550,472 bytes | 2026-11-10 19:17:13 |
| `build\windows\x64\runner\Release\asb_house_hub.exe` | 16,165,888 bytes | 2026-11-10 06:24:13 (stable runner shell) |

The Dart snapshot was rebuilt after the circular, timetable-rules, and acceptance changes. The desktop launchers (`Launch_ASB_House_Hub.bat`, `Run_ASB_House_Hub.bat`) run this Release executable.

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

1. **Rules tests are source-contract assertions.** No Firebase emulator harness exists. Firestore rules are compiled and deployed; the key contracts are asserted in the suite. Evaluated denial is not claimed beyond that convention.
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
- `lib/services/auth_service.dart` — truthful circular publish/upload, notice cache, foundational events/notices.
- `lib/screens/home_screen.dart` — M8 dashboard, circular feed/composer, attachment opening, cache controls.
- `lib/screens/teacher_timetable_editor_screen.dart` — moving-break control and period time pickers.
- `lib/widgets/school_circular_composer.dart` — title/details/category/audience/PDF composer with truthful errors.
- `test/dashboard_profile_test.dart` — 6 dashboard/profile tests.
- `test/teacher_timetable_editor_test.dart` — moving-break, multi-class picker, and time-picker tests.
- `test/circular_composer_test.dart` — 9 circular service/composer/rules tests.
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
- [x] Full suite green (662/662), analyzer clean, Firestore rules deployed, release rebuilt.
- [x] Zero partials: tests 5, 22, 24, and 25 closed by direct evidence.
- [x] Circular PDF composer with title/details/category/audience, truthful upload failures, and local-only warning.
