# M8 verification — dashboard, profile polish, and §11 acceptance

**Date:** 2026-11-09
**Branch:** `mustafa1`
**Baseline:** `15aa7c3` (M7 hardening). M8 and the P0/P1/P2 fixes are the working batch documented here.
**Method:** first-hand implementation and test runs; read of `home_screen.dart`, `notification_service.dart`, `app_notification.dart`, `academic_class.dart`, `teacher_timetable_editor_screen.dart`, `firestore.rules`, the M2–M7 verification files, and the full test suite. No claim below is copied from an earlier report without being re-checked.

## Verdict

M8 is **delivered for its stated Spark scope**, with an honest acceptance score of **60 PASS · 4 PARTIAL · 0 MISSING** across the 64 spec §11 tests. The four partials are documented in `ACCEPTANCE_MATRIX.md` and are **not** counted as passing.

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

## Test evidence (actual runs)

| Command | Result |
|---|---|
| `flutter test test/dashboard_profile_test.dart` | **6/6 passed** |
| `flutter test test/teacher_timetable_editor_test.dart` | **12/12 passed** (includes the new moving-break test) |
| `flutter test test/acceptance_matrix_test.dart` | **6/6 passed** |
| `flutter test test/dashboard_profile_test.dart test/teacher_timetable_editor_test.dart test/acceptance_matrix_test.dart` | **24/24 passed** |
| `flutter test` (full suite) | **638/638 passed** |
| `flutter analyze --no-pub` | **No issues found** |
| `firebase.cmd deploy --only firestore:rules` | **compiled successfully; released to `cloud.firestore`** |
| `flutter build windows --release` | **built** `build\windows\x64\runner\Release\asb_house_hub.exe` |

### Release artifact

| Artifact | Size | Timestamp |
|---|---|---|
| `build\windows\x64\runner\Release\data\app.so` | 13,239,176 bytes | 2026-11-09 14:14:16 |
| `build\windows\x64\runner\Release\asb_house_hub.exe` | 16,165,888 bytes | 2026-11-06 15:36:00 (stable runner shell) |

The previous `app.so` was stale at `2026-11-09 13:22:39`, before the M7 commit. The rebuilt Dart snapshot is newer than the `15aa7c3` baseline and contains this batch. The desktop launchers (`Launch_ASB_House_Hub.bat`, `Run_ASB_House_Hub.bat`) run this Release executable.

## Acceptance status

| Status | Count | Tests |
|---|---|---|
| **PASS** | 60 | All rows except the four below |
| **PARTIAL** | 4 | 5, 22, 24, 25 |
| **MISSING** | 0 | — |

The partials are **not** counted as passing:

1. **Test 5 — another class's timetable.** The dashboard and student timetable scope to the verified class, but `timetable_versions` rules still allow broad signed-in published reads and cannot field-scope list queries. Documented as **P1-04** in `PROJECT_PROBLEMS.md`. A path-scoped timetable migration is required for strict backend denial.
2. **Test 22 — multi-class editor picker.** The picker is implemented; there is no dedicated widget test that selects a class from the dialog. Single-class selection and the unassigned-teacher denial are tested.
3. **Tests 24–25 — per-period time pickers.** The start-minute model, auto end times, validation, and standard-timing recalculation are tested; direct interaction with every period's `showTimePicker` is not automated.

## Honest limits (Spark / project convention)

1. **Rules tests are source-contract assertions.** No Firebase emulator harness exists. Rules are compiled and deployed; the key contracts are asserted in the suite.
2. **No Cloud Functions or FCM.** Notification fan-out is client-side, capped at 500 roster lookups, 400 writes per batch, and 100 streamed notifications.
3. **P1-01 secrets remain a documented residual risk.** The release was built without `--dart-define` values, so it uses the development fallbacks. A production build must pass `ELECTION_HMAC_SALT`, `VAULT_SECRET`, `GAMIFICATION_HMAC_SECRET`, and `SPORTS_CERT_SECRET`. Removing the fallbacks without supplying the defines would break live account switching, elections, gamification, and sports signatures.
4. **P1-04 timetable read scoping is open.** Do not claim strict cross-class backend denial until the path-scoped migration lands.
5. **Client-side conflict detection is not transactional.** Two editors can publish conflicting timetables concurrently; server-side validation at scale is Blaze-deferred.
6. **Suspension does not revoke an already-issued Firebase Auth token.** Full revocation requires the Admin SDK on Blaze.

## Files in this batch

- `firestore.rules` — exact bootstrap admin emails; P0-01.
- `lib/models/academic_class.dart` — `isPrimaryGrade`.
- `lib/models/app_notification.dart` — `NotificationUnreadBreakdown`.
- `lib/services/notification_service.dart` — unread breakdown stream + widget-test override.
- `lib/screens/home_screen.dart` — M8 dashboard, verified strip, timetable card, unread card, younger simplification, responsive padding, deterministic clock.
- `lib/screens/teacher_timetable_editor_screen.dart` — moving-break control.
- `test/dashboard_profile_test.dart` — 6 dashboard/profile tests.
- `test/teacher_timetable_editor_test.dart` — moving-break test.
- `test/acceptance_matrix_test.dart` — 6 matrix/rules guards.
- `test/widget_test.dart` — P0 regex-absence assertions.
- `development_plan/ACCEPTANCE_MATRIX.md` — 64-row acceptance matrix.
- `development_plan/PROJECT_PROBLEMS.md` — prioritized problem register (P1-04 added).
- `development_plan/MASTER_GAP_ANALYSIS.md`, `development_plan/REMAINING_MODULES_REPORT.md` — truth pass.

## Definition of done check

- [x] Verified-class dashboard with today/Now/Next/Break and all 8 periods + BRK.
- [x] Class-teacher display and verified badge on dashboard/profile.
- [x] Unread class/house/timetable counts.
- [x] Younger-student simplification.
- [x] Responsive narrow/wide layouts; no overflow in tests.
- [x] 64-row acceptance matrix + enforceable harness.
- [x] Exact bootstrap admin emails; no prefix elevation.
- [x] Full suite green (638/638), analyzer clean, rules deployed, release rebuilt.
- [x] Four partials documented and not counted as passing.
