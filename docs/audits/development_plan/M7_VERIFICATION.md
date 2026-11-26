# M7 verification — Admin Command Center expansion (tests 36–37, 55–59, 63–64)

**Date:** 2026-11-09 (Hardened)
**Branch:** `mustafa1`
**Method:** comprehensive review of `academic_class.dart`, `auth_service.dart`, `timetable_service.dart`, `admin_academics_screen.dart`, `firestore.rules`; targeted M7 suite plus section auto-assign tests; full test suite; `flutter analyze`; Firestore rules live compilation and deployment.
**Verdict:** M7 is **done for its stated Spark scope**. Central administrative control is established across sections (LKG–12), verification, transfers, house assignments, academic year promotions, timetable approval queues, append-only audit logs, and account status/blocking. Every admin action is server-gated by Firestore rules and protected from non-staff tampering. Live write denials are reported truthfully, batch promotion distinguishes a failed roster read from a genuinely empty roster, and best-effort secondary writes no longer turn successful primary actions into reported failures. Tests 36–37, 55–59, 63–64 pass.

## Delivered Acceptance Requirements

| Test | Status | Evidence |
|---|---|---|
| **Test 55 — Manage grades LKG–12** | ✅ **DONE** | `AcademicStructure.gradeLevels` covers all 14 grade levels from LKG to Grade 12 in strict educational hierarchy. `AcademicStructure.nextGrade` accurately computes progressive promotions: LKG → UKG → Grade 1 → ... → Grade 12 → null (graduated). |
| **Test 56 — Section management (create/activate/deactivate)** | ✅ **DONE** | `saveAcademicClass` registers canonical sections, `setClassActive` toggles active state without destructive deletion, and `updateClassTimetablePermissions` / `updateClassCommunicationSettings` control assigned educators and student posting. A live Firestore denial now returns `false` and leaves the cache untouched; local-cache fallback applies only when Firebase is not live (demo/offline path). Auto-linking matching scholars is best-effort and logged. |
| **Test 57 — Approve class assignments & transfers** | ✅ **DONE** | `verifyStudentClass` approves pending scholar class placements; `transferStudentClass` moves scholars to the target class, updates `class_id`, `class_level`, and `division`, and preserves house membership. The primary user update is authoritative; a failed follow-up notification is logged but does not turn the completed update into a reported failure. |
| **Test 58 — Manage house assignments** | ✅ **DONE** | `assignStudentHouse` updates a scholar's house membership across Ruby, Sapphire, Emerald, Topaz. Class identity and verification remain untouched, enforcing full independence between house and class. |
| **Test 59 — Academic year promotion (Spec §9.5)** | ✅ **DONE** | `promoteScholar` advances individual students; `promoteClassSection` sequentially promotes verified rosters. Every student's `house_name` is strictly preserved. `PromotionResult` reports `total`, `promoted`, `failed`, and `failedScholarNumbers`, plus an `error`/`hasError` signal when the roster read fails; roster entries without a scholar number count as failures so `promoted + failed == total`. |
| **Test 36 — Timetable approval queue** | ✅ **DONE** | `getSubmittedTimetableQueueStream` streams pending submissions. "Approve & Publish" runs cross-class conflict checks (M3), publishes the schedule, fans out notifications (M6), and writes an audit entry. "Reject" records a mandatory 1–500 character reason and marks the version rejected. Audit writes are best-effort and never roll back a successful publish/reject. |
| **Test 37 — Timetable override & restore** | ✅ **DONE** | `saveTimetableOverride` creates date-scoped temporary schedules. `restoreTimetableVersion` creates a new version linked to the target via `supersedesId`, keeping historical versions immutable. |
| **Test 63 — Privileged audit log viewer** | ✅ **DONE** | `getAllTimetableAuditsStream` streams append-only audit records with class and action filters (`publish`, `approve`, `reject`, `submit`, `restore`, `override`, `copy`, `substitute`, `promotion`, `transfer`). Rules enforce `allow update, delete: if false` and `read: if isAdmin()`. If the live audit query fails, the viewer falls back to cached entries. |
| **Test 64 — User status & unauthorized blocking** | ✅ **DONE** | `setUserStatus` updates account status (`active`, `suspended`, `deactivated`). Non-staff roles see an access-denied lock screen on `AdminAcademicsScreen`. Rules forbid owners from modifying `status`, `role`, `class_id`, or `class_verified`, and restrict administrative collections to `isAdmin()`. |

## Test Evidence

Targeted M7 coverage — **33/33 passing**:

- `test/admin_command_center_test.dart` — **30/30**:
  - Test 55 (3): grade hierarchy, `nextGrade` progression, `nextClassId` section preservation.
  - Test 56 (3): section creation, active toggle without deletion, timetable permissions update with truthful failure.
  - Test 57 (3): placement verification, transfer with class update and house preservation, invalid id rejection.
  - Test 58 (2): house assignment preserving class placement, invalid house rejection.
  - Test 59 (5): scholar promotion preserving house, section batch promotion, invalid class rejection, **roster lookup failure reported as an error**, **missing scholar numbers counted as failures**.
  - Test 36 (4): submitted queue stream, publish approval with audit, rejection with reason, invalid reason rejection.
  - Test 37 (2): one-day override schedule, version restore preserving history.
  - Test 63 (2): audit stream with action filtering, rules append-only source contract.
  - Test 64 (6): status update, invalid status rejection, unauthorized UI lock screen, authorized 6-tab mounting, rules class write gate, rules user status immutability.
- `test/academic_section_auto_assign_test.dart` — **3/3**: section auto-assignment of saved accounts, case-insensitive roster matching, safe dropdown target resolution.

Commands verified:

- `flutter test test/admin_command_center_test.dart test/academic_section_auto_assign_test.dart` → **33/33 passed**
- `flutter test` (entire project suite) → **625/625 passed**
- `flutter analyze --no-pub` → **No issues found** (6.2s; `analysis_options.yaml` excludes `tool/**`)
- `firebase.cmd deploy --only firestore:rules` → **compiled successfully; latest version already up to date; released**

## Honest Scope & Limits (Spark vs Blaze)

1. **Sequential batch promotion on Spark.** Without Cloud Functions or callable transactions, section-wide promotion runs sequential client writes with individual error catching. `PromotionResult` truthfully reports total, promoted, failed, and the failed scholar numbers; a roster read failure is reported via `hasError` rather than disguised as an empty roster. The atomic cross-collection transaction remains documented in `BLAZE_REQUIRED_FEATURES.md`.
2. **Audit writes are best-effort.** A failed live audit write is logged but does not roll back a successful timetable publish, rejection, override, restore, or copy. The audit viewer falls back to cached entries if its live query fails.
3. **Queue fallback can be stale.** `getSubmittedTimetableQueueStream` falls back to cached submitted versions on a live read error, so an admin may see the last-known queue rather than an error banner.
4. **Auto-assignment is best-effort.** Saving a section persists the section itself; linking every matching existing scholar is attempted and logged, but the save result does not claim all matches were linked.
5. **Account suspension enforcement.** User documents store `status: 'active' | 'suspended' | 'deactivated'`. UI surfaces badge indicators and blocks actions; full revocation of Firebase Auth session tokens requires the Firebase Admin SDK on Blaze.
6. **Local-cache fallback is limited to non-live mode.** Live Firestore denials return `false` and do not create phantom cached sections; the local fallback remains for demo/offline execution without Firebase.
7. **Rules tests remain source-contract assertions.** No Firebase emulator harness was added, matching previous modules.

## Handoff

Next module: **M8 — Dashboard & profile polish + full 64-test acceptance suite** per `REMAINING_MODULES_REPORT.md`.
