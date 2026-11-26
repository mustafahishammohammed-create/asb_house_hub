# M5 verification — class groups & academic communication (tests 50–54)

**Date:** 2026-11-08
**Branch:** `mustafa1` (M5 work is the commit following this document)
**Method:** read of `class_group.dart`, `class_group_service.dart`, `class_group_screen.dart`, `academic_class.dart`, `hierarchy_service.dart`, `auth_service.dart`, `admin_academics_screen.dart`, `home_screen.dart`, `firestore.rules`; targeted M5 suite; full suite; `flutter analyze`; rules deployment output.
**Verdict:** M5 is **done for its stated Spark scope**. Membership is derived from the verified class placement, class teachers and assigned subject teachers are scoped by the `academic_classes` registry, student posting is a server-checked school flag, and cross-class read/write isolation is enforced in Firestore rules. Tests 50–54 pass. Class announcements do not fan out notifications until M6/test 62.

## Delivered

| Area | Status | Evidence |
|---|---|---|
| **Test 50 — auto-join on verified class** | ✅ **DONE** | `ClassGroupAccess.resolveClassId` reads the canonical `class_id` from the profile; `isVerifiedMember` additionally requires `class_verified == true`. Opening `ClassGroupScreen` resolves `class_groups/{classId}` with no join button and no membership write. `ClassGroup.defaultsFor('11D')` produces **11D Class Group**. |
| **Test 51 — class-teacher announcements** | ✅ **DONE (client + rules)** | The class teacher is the UID in `academic_classes/{classId}.class_teacher_uid`. `ClassGroupAccess.isClassTeacher` / rules `isClassTeacher` grant view, send, and moderation only for that class. A different teacher is denied. |
| **Test 52 — subject teachers assigned classes only** | ✅ **DONE (client + rules)** | Subject teachers are listed in `academic_classes/{classId}.subject_teacher_uids`. The UI composer and the rules sender helper both require the UID to be in that class's list; an unassigned subject teacher is denied, and no other class is readable or writable. |
| **Test 53 — configurable student send** | ✅ **DONE (client + rules)** | `student_posting_enabled` defaults to `false` on `AcademicClass`. Rules `isClassStudentSender` requires the verified class placement **and** the server-side flag before a `student`/`prefect` can create a message. The admin class dialog can toggle the flag and edit teacher UIDs. Class representatives and vice representatives can always post in their own class. |
| **Test 54 — cross-class isolation** | ✅ **DONE (client + rules)** | Rules `isClassViewer` gates both the group header and message reads; `isVerifiedClassMember` compares the profile `class_id` to the path, so a verified 11D student cannot read 11C even with a direct Firestore call. The UI also renders a dedicated access-denied state. |
| **New roles** | ✅ **DONE** | `class_teacher`, `subject_teacher`, `class_representative`, `vice_class_representative`, and `parent` added to `HierarchyService`, the `AuthService` staff-role list, the rules `isAdmin()` faculty list, and the `isValidUser` role whitelist. `class_teacher`/`subject_teacher` count as faculty. |
| **Categories, attachments, moderation** | ✅ **DONE** | Reuses the M4 pattern: closed categories `general`, `announcement`, `event`, `sports`; image attachments stored as Firestore data-URL strings (rules cap `900000`); pin/unpin, hide/unhide, and delete for moderators. Message updates are limited by rules to `is_pinned`, `is_hidden`, `moderated_by`, `moderated_at`. |
| **Rules** | ✅ **DEPLOYED** | `class_groups/{classId}` and `class_groups/{classId}/messages/{messageId}` matchers; helpers `isVerifiedClassMember`, `isClassTeacher`, `isClassSubjectTeacher`, `isClassRepresentative`, `isClassStudentSender`, `isClassSender`, `isClassModerator`, `isClassViewer`; validators `isValidClassGroup`, `isValidClassGroupMessage`; `isValidAcademicClass` extended with `subject_teacher_uids` and `student_posting_enabled`. Compiled and released to `cloud.firestore`. |
| **Truthful writes** | ✅ **DONE** | `sendClassMessage`, `ensureClassGroup`, pin/hide, and delete return `false` for unauthorised users, offline runtimes, simulated failures, and real Firestore denials. The UI shows a failure snackbar and does not clear the draft or attachment on failure. |
| **Admin controls** | ✅ **DONE** | `AdminAcademicsScreen` → Classes → forum icon opens **Class Group** settings: class teacher name/UID, subject teacher UIDs, and the student-posting switch. Saved through the existing admin-only `saveAcademicClass` path; rules remain the authority. |
| **UI entry points** | ✅ **DONE** | Home action card **🏫 My Class Group**, a drawer tile, and `ClassGroupScreen` with auto-join/staff banner, read-only banner, category filters and sender selector, attachment preview, moderation menu, staff class picker, and access-denied/no-class states. |

## Test evidence

`test/class_group_test.dart` — **47/47 passing**, in six groups:

- **M5a** (10): verified auto-join (50), unverified/missing placement denial, class-teacher send/moderate (51), different-teacher denial, assigned subject teacher (52), unassigned subject teacher denial, student default-deny/enabled (53), representative/vice always send, prefect flag gating, parent read-only/teacher without assignment.
- **M5b** (3): cross-class read denial for students and class teachers (54), transfer revokes the old class and grants the new one, senior-admin view/moderate but not send.
- **M5c** (6): Firestore-shaped message round-trip, invalid-category normalisation, attachment-only preview, group defaults/`copyWith`, academic-class assignment serialization, and revocation of a cleared class-teacher UID.
- **M5d** (8): student send denied before any write; enabled student scheduling still surfaces a denied write as `false`; authorised teacher denial is truthful; student moderation/delete denied; denied teacher moderation is truthful; offline reads return empty streams; students/subject teachers cannot bootstrap the header; teacher header denial is truthful.
- **M5e** (9): rules source contract for verified membership, sender helper composition, subject-teacher UID scoping, student-posting flag, read/create isolation, attachment/category validator, moderation field limit, academic-class settings validator, and the M5 role whitelist.
- **M5f** (11): student read-only UI, enabled-student composer, class-teacher composer/moderation, subject-teacher composer, representative composer/role banner, cross-class access denial, no-class state, staff class picker, pinned/hidden rendering, hidden filtering for students, category filters.

Commands run:

- `flutter test test/class_group_test.dart` → **47/47**
- `flutter test` → **547/547**
- `flutter analyze` → **0 errors, 0 warnings**, 20 pre-existing infos (unnecessary underscores and `print` in `tool/`)
- `firebase.cmd deploy --only firestore:rules` → **compiled and released**

## Honest limits / follow-ups

1. **Rules tests remain source-contract assertions.** No Firebase emulator harness was added, matching M2/M3/M4. Real denial behaviour is enforced by the deployed rules helpers and mirrored by pure client-policy tests.
2. **Attachments are Firestore data-URL strings, not Storage objects.** `attachment_url` is capped at 900,000 characters and populated from the existing compressed image picker. This avoids new Storage rules but is not a scalable media pipeline.
3. **No notification fan-out.** Class announcements do not write `users/{uid}/notifications` docs yet; M6/test 62 owns recipient fan-out and unread badges.
4. **Message streams are capped at the newest 200.** Adequate for Spark; pagination is a later scaling concern.
5. **Group header is optional.** Membership is profile-derived; a class with no header still renders the default name and feed. Only the class teacher or a senior admin can bootstrap the header.
6. **Senior admins can view/moderate across classes but cannot send.** Sending requires teacher assignment, representation, or enabled student membership, matching the rules.
7. **Moderation/delete are hard deletes.** There is no tombstone or audit collection; `moderated_by`/`moderated_at` record pin/hide actions only.
8. **Legacy class fields are not a fallback for membership.** `resolveClassId` intentionally uses only the canonical `class_id`; unverified legacy `class_level`/`division` profiles must be verified by an administrator first (M1 gate).
9. **Assignments are UID lists on the class registry.** There is no teacher-picker UI yet; admins paste Firebase Auth UIDs into the class dialog. A people-picker is an M7 admin-expansion improvement.

## Handoff

Next module: **M6 — notification engine** per `REMAINING_MODULES_REPORT.md`. Wire timetable publishes (test 60), house announcements (61), and class announcements (62) into the existing per-user notification subcollection with truthful, deduped client-side fan-out. Do not regress elections, points, sports, wallet, merch, ID scanner, behavior, 1:1 chat, account switching, A1–A6/A8, photo upload, timetable, or M4 house groups.
