# M6 verification — in-app notification engine (tests 60–62)

**Date:** 2026-11-09 (Hardened)
**Branch:** `mustafa1`
**Method:** read of `app_notification.dart`, `notification_service.dart`, `notification_center_screen.dart`, `home_screen.dart`, `timetable_service.dart`, `teacher_timetable_editor_screen.dart`, `admin_academics_screen.dart`, `house_group_service.dart`, `class_group_service.dart`, `house_group_screen.dart`, `class_group_screen.dart`, `firestore.rules`; targeted M6 suite; full suite; `flutter analyze`; rules deployment output.
**Verdict:** M6 is **fully complete for its stated Spark scope**. Timetable publishes (60), teacher substitution assignments (60), one-day overrides (60), house announcements (61), and class announcements (62) trigger deduped, client-side fan-out into `users/{uid}/notifications`. Tap navigation deep-links notifications to their relevant screens (Academics/Timetable, House Group, Class Group), single-item delete (button + swipe-to-dismiss) and bulk clear-all are supported, retries never overwrite read states, and partial failures — including roster-lookup errors and substitution fan-out errors — are reported truthfully across all publishers. Tests 60–62 pass.

## Delivered

| Area | Status | Evidence |
|---|---|---|
| **Test 60 — Timetable publish fan-out** | ✅ **DONE** | `NotificationService.notifyTimetablePublished` is called on successful `publishTimetable`. Targets all verified members of the canonical `class_id` with high priority. Structural dedupe key `timetable_<versionId>` (fallback `tt_<classId>_<dayOfWeek>_v<version>` when the version has no id). Passes `roomId: classId` for deep linking. |
| **Test 60 — Substitution fan-out** | ✅ **DONE** | `NotificationService.notifyTimetableSubstitution` is triggered in `TimetableService.saveTimetableOverride` for every slot with `hasSubstitute`. Targets the verified class members AND the assigned substitute teacher (`substituteTeacherUid`). Dedupe key `tt_sub_<classId>_<yyyy-mm-dd>_p<periodNumber>`. Incomplete substitution results are surfaced through `TimetableService.lastNotificationResult` for publisher warnings. |
| **Test 60 — One-day override alerts** | ✅ **DONE** | `notifyTimetablePublished` supports `overrideDate`. When published, emits type `timetable_override`, alerts students of the temporary dated schedule, and dedupes on `tt_override_<classId>_<yyyy-mm-dd>_v<version>` with the version id (or a deterministic fallback) as `source_id`. |
| **Test 61 — House announcement fan-out** | ✅ **DONE** | `NotificationService.notifyHouseAnnouncement` is hooked into `HouseGroupService.sendHouseMessage` for `category == 'announcement'`. Targets members of the matching `house_name`, strictly excluding the sender. Structural dedupe key `house_<houseId>_<messageId>`. Passes `roomId: houseId` for deep linking. |
| **Test 62 — Class announcement fan-out** | ✅ **DONE** | `NotificationService.notifyClassAnnouncement` is hooked into `ClassGroupService.sendClassMessage` for `category == 'announcement'`. Targets members of the canonical `class_id` (`class_verified == true`), strictly excluding the sender. Structural dedupe key `class_<classId>_<messageId>`. Passes `roomId: classId` for deep linking. |
| **Tap Navigation / Deep Linking** | ✅ **DONE** | Tapping an unread notification marks it as read and routes the user directly to the relevant destination: Timetable → `AcademicsScreen(initialTab: 'timetable')`, House → `HouseGroupScreen(initialHouseId)`, Class → `ClassGroupScreen(initialClassId)`. Supported by customizable test callback `onNotificationTap`. |
| **Single Delete & Bulk Clear All** | ✅ **DONE** | `NotificationService.deleteNotification` and `clearAll` remove notifications. UI provides a per-tile delete icon, swipe-to-delete, and a "Clear all" button. Swipe deletion uses `confirmDismiss`; a failed delete snaps the row back and shows an error instead of leaving a dismissed row over still-present data. Rules enforce `allow delete: if isOwner(userId) || isAdmin()`. |
| **Truthful Warning Feedback** | ✅ **DONE** | `NotificationFanOutResult` tracks `total`, `sent`, `failed`, `skipped`, and `error`; `isComplete` is false when `hasError`. A failed roster/profile lookup returns an explicit error result rather than a phantom complete zero-recipient fan-out. Timetable publishers (`TeacherTimetableEditorScreen`, `AdminAcademicsScreen`), House Group, and Class Group all check `fanOut.warning != null` (not just `failed > 0`). `submitTimetable`/`saveTimetableOverride` clear stale results, and incomplete substitution results replace the publish result so their warning is visible. |
| **Deduplication & Read State Protection** | ✅ **DONE** | Document IDs are deterministic: `${dedupeKey}_${recipientUid}`, sanitized for Firestore and capped at 300 chars. Creation payloads omit `is_read` and writes use `SetOptions(merge: true)`, so fan-out retries can never reset an already-read notification back to unread. Missing `is_read` defaults to unread (`isRead == false`). |
| **Rules Enforcement** | ✅ **DEPLOYED** | Matcher `/users/{userId}/notifications/{notificationId}`: read is restricted to owner or admin; create is open to authenticated senders under `isValidNotification`; update is restricted to owner toggling `is_read`, or dedupe retries with identical `dedupe_key`/`source_id` whose `affectedKeys()` excludes `is_read`; delete is owner or admin. Compiled and released to `cloud.firestore`. |
| **Notification Center UI** | ✅ **DONE** | `NotificationCenterScreen` displays the reactive stream, unread indicators, category/priority badges, mark-as-read on tap, "Mark all read", "Clear all", per-item delete, and swipe-to-delete with failure snap-back. |
| **Home Entry Points** | ✅ **DONE** | `HomeScreen` AppBar features a bell icon with a dynamic unread badge (`home_notifications_badge`), and the drawer includes a dedicated notification tile. The unread-count stream is cached per signed-in UID and refreshed on account switching rather than resubscribed on every rebuild. |

## Test evidence

`test/notification_test.dart` — **42/42 passing**, in six groups:

- **M6a** (7): model round-trip, missing `is_read` defaults to unread, category/priority normalization, unread count computation, fan-out payload omits `is_read`, deterministic dedupe doc IDs, fan-out result warning helpers.
- **M6b** (5): test 60 verified-class timetable targeting, test 61 house targeting excluding sender, test 62 verified-class announcement targeting, invalid/empty scope handling, recipient UID deduplication.
- **M6c** (7): offline fan-out reported as skipped, denied fan-out reports failures truthfully, empty roster returns complete without Firestore calls, **failed roster lookup is not reported as complete**, read state omitted from fan-out payload, `deleteNotification` fails truthfully when offline/denied, `clearAll` handles empty and offline states.
- **M6d** (8): test 60 timetable event helper, test 61 house announcement helper, test 62 class announcement helper, `publishTimetable` fan-out invocation, substitution targeting class + substitute teacher, override notification formatting, `saveTimetableOverride` substitution fan-out, **substitution fan-out failure surfaced on `lastNotificationResult`**.
- **M6e** (4): rules source contract for validator fields, owner-only read marking, dedupe retry read-state immutability, signed-in creation guard.
- **M6f** (11): notification center rendering with priority chips, mark single as read, already-read tap no-op, mark-all-read batching, empty state, failed read-marking error, tap navigation deep link, delete button callback, successful swipe delete, **failed swipe delete keeps the row visible with an error**, clear-all callback.

Commands run:

- `flutter test test/notification_test.dart` → **42/42**
- `flutter test` → **623/623**
- `flutter analyze --no-pub` → **No issues found** (6.0s; `analysis_options.yaml` excludes `tool/**`)
- `firebase.cmd deploy --only firestore:rules` → **compiled successfully; latest version already up to date; released**

## Honest limits / follow-ups

1. **Client-side fan-out, not Cloud Functions.** On the Firebase Spark free plan, fan-out runs in a client write loop. Rosters are capped at 500 lookups per event and writes chunk into batches of 400. If the client disconnects mid-batch, unsent notifications are skipped; a server-side background trigger remains Blaze-deferred.
2. **No push notifications (FCM).** In-app notifications are persisted to Firestore and consumed via local reactive streams; mobile OS push notifications require Cloud Functions or external server keys.
3. **Creation permission is broad in rules.** Any authenticated user can create a notification under `isValidNotification`, necessary because teachers and captains write to other users' `notifications` subcollections during fan-out. Scoping creation by sender role in rules would require cross-document lookups for every recipient.
4. **Message cap.** The notification stream is capped at the newest 100 notifications per user to stay within Spark read quotas.
5. **Rules tests remain source-contract assertions.** No Firebase emulator harness was added, matching previous modules.
6. **Roster-lookup failures are reported, not retried automatically.** A failed profile query now produces an error result and a warning, but the publisher must retry the action; fan-out is best-effort per batch. A mid-batch disconnect can leave later recipients unreached unless that batch itself fails.
7. **Substitution fan-out is warning-only.** The timetable override write succeeds first; notification failure never rolls back the timetable change, and the warning is surfaced through the shared `lastNotificationResult`.
