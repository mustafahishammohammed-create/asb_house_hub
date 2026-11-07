# A2. Assignment publish/delete report phantom success; buttons are ungated

**Severity:** MEDIUM

## Problem

The assignment write paths repeat the G1 phantom-success pattern that was already eradicated from the points module:

- `publishAssignment` — [auth_service.dart:1131-1177](../lib/services/auth_service.dart): writes the local cache **first** (:1144-1161), then the Firestore `set` inside `catch (_) {}` (:1164-1171), then `return true` (:1173). A rules denial is invisible.
- `deleteAssignment` — [auth_service.dart:1180-1213](../lib/services/auth_service.dart): same shape — cache removal first (:1190-1197), Firestore `delete` inside `catch (_) {}` (:1200-1207), `return true` (:1209).
- Rules: assignment create/delete require `isAdmin()` ([firestore.rules:730,739](../firestore.rules)) — teacher/faculty/principal/staff only. Students, council, captains and prefects are all denied.
- The UI never checks the return value and never gates the buttons:
  - Publish modal and "Publish Homework" button are ungated; success snackbar fires unconditionally — [academics_screen.dart:2337,2543-2556](../lib/screens/academics_screen.dart).
  - Delete button and "Assignment deleted successfully." snackbar fire unconditionally — [academics_screen.dart:2302-2334](../lib/screens/academics_screen.dart).
  - The only role gate in the assignments tab is on **grading** (:2211, `canGradeAcademics`). Publish/delete have none.

## What breaks

1. A student (or council officer — council may only update `status`, not create/delete) taps Publish or Delete → the assignment appears/disappears **on their device only**, with a green success message. The server never changed. Refresh from another device shows the truth — split-brain.
2. Because the cache is written before the server attempt, the fabricated state persists offline and is re-shown on every cold start until a successful server stream overwrites it.
3. Staff on a denied write (e.g. a `faculty_advisor` account — see A6) get the same false success, so even legitimate users can't tell their publish failed.

## Solution

**No Blaze required:**

1. Make both methods truthful, copying the pattern already used by `saveTimetablePeriod` (:686-737) and `publishExamScheduleRange` (:1323-1426): attempt the Firestore write; on failure in live mode return `false` (or rethrow); only write the cache after server acknowledgment, or label the offline fallback explicitly as demo.
2. Check the result in the UI: success snackbar only on `true`; on `false` show "You don't have permission to publish/delete assignments" (or the server error).
3. Gate the Publish and Delete buttons with the same check the rules enforce — `HierarchyService.isTeacherOrFaculty || isSuperAdmin` — so unauthorized accounts never see the affordance (match the exam publisher gate at :2683).
4. Tests: simulate a rules denial → both methods return `false`, cache unchanged; widget test asserting the buttons are absent for a student role.

## Done when

- A denied publish/delete returns failure, shows an error, and leaves the cache untouched.
- Students/council/captains see no Publish/Delete assignment buttons; staff do.
- Existing truthful paths (timetable save, exam publish) remain unchanged.