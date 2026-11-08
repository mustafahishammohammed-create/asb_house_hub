# M6 verification — in-app notification engine (tests 60–62)

**Date:** 2026-11-08 (Audited & Extended)
**Branch:** `mustafa1`
**Method:** read of `app_notification.dart`, `notification_service.dart`, `notification_center_screen.dart`, `home_screen.dart`, `timetable_service.dart`, `teacher_timetable_editor_screen.dart`, `admin_academics_screen.dart`, `house_group_service.dart`, `class_group_service.dart`, `house_group_screen.dart`, `class_group_screen.dart`, `firestore.rules`; targeted M6 suite; full suite; `flutter analyze`; rules deployment output.
**Verdict:** M6 is **fully complete for its stated Spark scope**. Timetable publishes (60), teacher substitution assignments (60), one-day overrides (60), house announcements (61), and class announcements (62) trigger deduped, client-side fan-out into `users/{uid}/notifications`. Tap navigation deep-links notifications to their relevant screens (Academics/Timetable, House Group, Class Group), single-item delete (button + swipe-to-dismiss) and bulk clear-all are supported, retries never overwrite read states, partial failures report warnings truthfully across all publishers (including the timetable editor), rules allow owner-only read/delete updates, and tests 60–62 pass.

## Delivered

| Area | Status | Evidence |
|---|---|---|
| **Test 60 — Timetable publish fan-out** | ✅ **DONE** | `NotificationService.notifyTimetablePublished` is called on successful `publishTimetable`. Targets all verified members of the canonical `class_id` with high priority. Structural dedupe key `tt_pub_${classId}_${dayOfWeek}_v${version}_${cleanDate}`. Passes `roomId: classId` for deep linking. |
| **Test 60 — Substitution fan-out** | ✅ **DONE** | `NotificationService.notifyTimetableSubstitution` is triggered in `TimetableService.saveTimetableOverride` for every slot with `hasSubstitute`. Targets the verified class members AND the assigned substitute teacher (`substituteTeacherUid`). Dedupe key `tt_sub_${classId}_${date}_p${periodNumber}`. |
| **Test 60 — One-day override alerts** | ✅ **DONE** | `notifyTimetablePublished` supports `overrideDate`. When published, marks notification type as `timetable_override`, alerts students of temporary dated schedule, and dedupes on the date and version. |
| **Test 61 — House announcement fan-out** | ✅ **DONE** | `NotificationService.notifyHouseAnnouncement` is hooked into `HouseGroupService.sendHouseMessage` for `category == 'announcement'`. Targets all verified members of the matching `house_name`, strictly excluding the sender. Structural dedupe key `house_ann_${houseId}_${messageId}`. Passes `roomId: houseId` for deep linking. |
| **Test 62 — Class announcement fan-out** | ✅ **DONE** | `NotificationService.notifyClassAnnouncement` is hooked into `ClassGroupService.sendClassMessage` for `category == 'announcement'`. Targets all verified members of the canonical `class_id` (`class_verified == true`), strictly excluding the sender. Structural dedupe key `class_ann_${classId}_${messageId}`. Passes `roomId: classId` for deep linking. |
| **Tap Navigation / Deep Linking** | ✅ **DONE** | Tapping an unread notification marks it as read and routes the user directly to the relevant destination: Timetable → `AcademicsScreen(initialTab: 'timetable')`, House → `HouseGroupScreen(initialHouseId)`, Class → `ClassGroupScreen(initialClassId)`. Supported by customizable test callback `onNotificationTap`. |
| **Single Delete & Bulk Clear All** | ✅ **DONE** | `NotificationService.deleteNotification` and `clearAll` allow users to remove notifications. UI provides per-tile delete icon, `Dismissible` swipe-to-delete, and "Clear all" button in the notification center. Rules enforce `allow delete: if isOwner(userId) || isAdmin()`. |
| **Truthful Warning Feedback** | ✅ **DONE** | `NotificationFanOutResult` tracks `total`, `sent`, `failed`, and `skipped`. Timetable publishers (`TeacherTimetableEditorScreen`, `AdminAcademicsScreen`), House Group, and Class Group all inspect `lastNotificationResult` and display orange warning SnackBars whenever partial failures occur. |
| **Deduplication & Read State Protection** | ✅ **DONE** | Document IDs are deterministic: `notif_${dedupeKey}_${recipientUid}`. Creation payloads omit `is_read` so fan-out retries can never reset an already-read notification back to unread. Missing `is_read` defaults to unread (`isRead == false`). |
| **Rules Enforcement** | ✅ **DEPLOYED** | Matcher `/users/{userId}/notifications/{notificationId}`: read is restricted to owner or admin; create is open to authenticated senders under `isValidNotification`; update is restricted to owner toggling `is_read`, or dedupe retries with identical `dedupe_key`/`source_id` whose `affectedKeys()` excludes `is_read`; delete is owner or admin. Compiled and released to `cloud.firestore`. |
| **Notification Center UI** | ✅ **DONE** | `NotificationCenterScreen` displays reactive stream, unread indicators, category/priority badges, mark-as-read on tap, "Mark all read" button, "Clear all" button, per-item delete button, and swipe-to-delete. |
| **Home Entry Points** | ✅ **DONE** | `HomeScreen` AppBar features a bell icon with dynamic unread badge count (`home_notifications_badge`), and drawer includes a dedicated notification tile. |

## Test evidence

`test/notification_test.dart` — **39/39 passing**, in six groups:

- **M6a** (7): model round-trip, missing `is_read` defaults to unread, category/priority normalization, unread count computation, fan-out payload omits `is_read`, deterministic dedupe doc IDs, fan-out result warning helpers.
- **M6b** (5): test 60 verified-class timetable targeting, test 61 house targeting excluding sender, test 62 verified-class announcement targeting, invalid/empty scope error handling, recipient UID deduplication.
- **M6c** (6): offline fan-out reported as skipped, denied fan-out reports failures truthfully, empty roster returns complete without Firestore calls, read state omitted from fan-out payload, `deleteNotification` fails truthfully when offline/denied, `clearAll` handles empty and offline states.
- **M6d** (7): test 60 timetable event helper, test 61 house announcement helper, test 62 class announcement helper, `publishTimetable` fan-out invocation, test 60 teacher substitution notification targets class + substitute teacher, test 60 timetable override notification formatting, `saveTimetableOverride` with publish triggers substitution notification.
- **M6e** (4): rules source contract for validator fields, owner-only read marking, dedupe retry read-state immutability, signed-in creation guard.
- **M6f** (10): notification center rendering with priority chips, mark single notification as read on tap, already-read tap no-op, mark-all-read batching, empty state rendering, failed read-marking error feedback, tap navigation deep link callback, per-item delete icon callback, dismissible swipe delete callback, clear all button callback.

Commands run:

- `flutter test test/notification_test.dart` → **39/39**
- `flutter test` → **614/614**
- `flutter analyze --no-pub` → **0 errors, 0 warnings**, 20 pre-existing infos
- `firebase.cmd deploy --only firestore:rules` → **compiled and released**

## Honest limits / follow-ups

1. **Client-side fan-out, not Cloud Functions.** On the Firebase Spark free plan, fan-out runs in a client write loop. Large rosters (>400) chunk into multiple batches. If the client disconnects mid-batch, unsent notifications are skipped; a server-side background trigger remains Blaze-deferred.
2. **No push notifications (FCM).** In-app notifications are persisted to Firestore and consumed via local reactive streams; mobile OS push notifications require Cloud Functions or external server keys.
3. **Creation permission is broad in rules.** Any authenticated user can create a notification under `isValidNotification`, necessary because teachers and captains write to other users' `notifications` subcollections during fan-out. Scoping creation by sender role in rules would require cross-document lookups for every recipient.
4. **Message cap.** Notification stream is capped at the newest 100 notifications per user to stay within Spark read quotas.
5. **Rules tests remain source-contract assertions.** No Firebase emulator harness was added, matching previous modules.
