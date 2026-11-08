# M7 verification — Admin Command Center expansion (tests 36–37, 55–59, 63–64)

**Date:** 2026-11-08
**Branch:** `mustafa1`
**Method:** comprehensive review of `academic_class.dart`, `auth_service.dart`, `timetable_service.dart`, `admin_academics_screen.dart`, `firestore.rules`; targeted M7 suite; full test suite; `flutter analyze`; Firestore rules live compilation and deployment.
**Verdict:** M7 is **done for its stated Spark scope**. Central administrative control is established across sections (LKG–12), verification, transfers, house assignments, academic year promotions, timetable approval queues, append-only audit logs, and account status/blocking. Every admin action is server-gated by Firestore rules and protected from non-staff tampering. Tests 36–37, 55–59, 63–64 pass.

## Delivered Acceptance Requirements

| Test | Status | Evidence |
|---|---|---|
| **Test 55 — Manage grades LKG–12** | ✅ **DONE** | `AcademicStructure.gradeLevels` covers all 14 grade levels from LKG to Grade 12 in strict educational hierarchy. `AcademicStructure.nextGrade` accurately computes progressive promotions: LKG → UKG → Grade 1 → ... → Grade 12 → null (graduated). |
| **Test 56 — Section management (create/activate/deactivate)** | ✅ **DONE** | `saveAcademicClass` registers canonical sections. `setClassActive` toggles active/inactive status without destructive deletion. `updateClassTimetablePermissions` and `updateClassCommunicationSettings` control assigned educators and student posting permissions. |
| **Test 57 — Approve class assignments & transfers** | ✅ **DONE** | `verifyStudentClass` approves pending scholar class placements with notification. `transferStudentClass` moves scholars to target class, updates `class_id`, `class_level`, and `division`, and preserves house membership strictly intact. |
| **Test 58 — Manage house assignments** | ✅ **DONE** | `assignStudentHouse` updates a scholar's house membership across Ruby, Sapphire, Emerald, Topaz. Class identity and verification remain completely untouched, enforcing full independence between house and class. |
| **Test 59 — Academic year promotion (Spec §9.5)** | ✅ **DONE** | `promoteScholar` advances individual students to next grade; `promoteClassSection` performs sequential batch promotion of class rosters. **CRITICAL SPEC §9.5 RULE:** Every student's `house_name` is strictly preserved and never mutated during promotion. Truthful reporting via `PromotionResult`. |
| **Test 36 — Timetable approval queue** | ✅ **DONE** | `getSubmittedTimetableQueueStream` streams pending timetable submissions. Admin "Approve & Publish" runs cross-class conflict checks (M3), publishes schedule, fans out notifications to students (M6), and logs audit. "Reject" dialog records a mandatory reason (1–500 chars) and marks version rejected. |
| **Test 37 — Timetable override & restore** | ✅ **DONE** | `saveTimetableOverride` creates date-scoped temporary schedules. `restoreTimetableVersion` creates a new version linking to the target via `supersedesId`, keeping all historical versions immutable. |
| **Test 63 — Privileged audit log viewer** | ✅ **DONE** | `getAllTimetableAuditsStream` streams append-only audit records with class and action filters (`publish`, `approve`, `reject`, `submit`, `restore`, `override`, `copy`, `substitute`, `promotion`, `transfer`). Rules enforce `allow update, delete: if false` and `read: if isAdmin()`. |
| **Test 64 — User status & unauthorized blocking** | ✅ **DONE** | `setUserStatus` updates account status (`active`, `suspended`, `deactivated`). Non-staff roles see access denied lock screen on `AdminAcademicsScreen`. Rules strictly forbid owners from modifying `status`, `role`, `class_id`, or `class_verified`, and restrict administrative collections to `isAdmin()`. |

## Test Evidence

`test/admin_command_center_test.dart` — **28/28 passing**, covering:
- Test 55 (3): grade hierarchy, nextGrade progression, nextClassId section preservation.
- Test 56 (3): section creation, active toggle without deletion, timetable permissions update.
- Test 57 (3): placement verification, transfer with class update & house preservation, invalid id rejection.
- Test 58 (2): house assignment preserving class placement, invalid house rejection.
- Test 59 (3): scholar promotion preserving house, section batch promotion truthful result, invalid class rejection.
- Test 36 (4): submitted queue stream, publish approval with audit, rejection with reason, invalid reason rejection.
- Test 37 (2): one-day override schedule, version restore preserving history.
- Test 63 (2): audit stream with action filtering, rules append-only source contract.
- Test 64 (6): status update, invalid status rejection, unauthorized UI lock screen, authorized 6-tab mounting, rules class write gate, rules user status immutability.

Commands verified:
- `flutter test test/admin_command_center_test.dart` → **28/28 passed**
- `flutter test` (entire project suite) → **605/605 passed**
- `flutter analyze --no-pub` → **0 errors, 0 warnings** (20 pre-existing infos)
- `firebase.cmd deploy --only firestore:rules` → **compiled successfully and released live to cloud.firestore**

## Honest Scope & Limits (Spark vs Blaze)

1. **Sequential batch promotion on Spark.** Without Cloud Functions or callable transactions, section-wide promotion runs sequential client writes in a loop with individual error catching. A truthful `PromotionResult` is returned to the user reporting total, promoted, and failed counts. The atomic cross-collection transaction remains documented in `BLAZE_REQUIRED_FEATURES.md`.
2. **Audit logs query limits.** The live audit viewer query caps results to the newest 100 entries to prevent exceeding Spark read quotas.
3. **Account suspension enforcement.** User documents store `status: 'active' | 'suspended' | 'deactivated'`. UI surfaces badge indicators and blocks actions; full revocation of Firebase Auth session tokens requires the Firebase Admin SDK on Blaze.

## Handoff

Next module: **M8 — Dashboard & profile polish + full 64-test acceptance suite** per `REMAINING_MODULES_REPORT.md`.
