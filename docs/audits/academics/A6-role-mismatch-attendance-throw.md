# A6. faculty_advisor/teacher_lead role mismatch; attendance-mark denial throws unhandled

**Severity:** LOW  
**Status:** RESOLVED (Phase P1, 2026-11-08)

## Resolution Evidence
- **Faculty Role Alignment (`firestore.rules:251-252`):** Added `'faculty_advisor'` and `'teacher_lead'` to the `isAdmin()` function in `firestore.rules` across both `request.auth.token.role` and `getUserData().role` branches. The rules now match the canonical list in `HierarchyService.isTeacherOrFaculty` (`hierarchy_service.dart:28-35`). Deployed to `cloud.firestore`.
- **Bidirectional Contract Test (`test/academics_security_test.dart`):** Added a contract test verifying that every role admitted by `HierarchyService.isTeacherOrFaculty` is present in `firestore.rules`'s `isAdmin()` and vice versa.
- **Attendance Save Error Handling (`auth_service.dart:1908-1964`, `academics_screen.dart:6435-6490`):** `markStudentAttendance` returns `Future<bool>`, attempts Firestore set first, checks `firestoreFailureSimulated`, returns `false` on failure, and updates cache only on ack. The dialog's Save button is wrapped in try/catch, checks the boolean result, displays a red error snackbar and keeps the dialog open on denial, only dismissing upon confirmed success.
- **Automated Verification:** Verified by failure simulation unit test and rules-contract test in `test/academics_security_test.dart`. All tests pass.

## Problem

**1. Client and rules disagree on who is faculty:**
- Client: `HierarchyService.isTeacherOrFaculty` admits `teacher`, `faculty`, `principal`, `staff`, **`faculty_advisor`, `teacher_lead`** — [hierarchy_service.dart:21-38](../lib/services/hierarchy_service.dart).
- Rules: `isAdmin()` admits only `teacher`, `faculty`, `principal`, `staff` (token or users doc) — [firestore.rules:248-254](../firestore.rules).
- Consequence: a `faculty_advisor` or `teacher_lead` account sees the exam publisher ([academics_screen.dart:2683](../lib/screens/academics_screen.dart)), report-card publisher (:4354) and attendance marker (:5705), but every write is denied. Exam/report publish rethrow, so those at least show an error; the gates themselves are wrong.

**2. Attendance marking has no error handling at all:**
- `markStudentAttendance` — [auth_service.dart:1819-1826](../lib/services/auth_service.dart): direct `set` with **no try/catch** — a rules denial throws.
- The dialog's Save button — [academics_screen.dart:6300-6331](../lib/screens/academics_screen.dart): pops the dialog, `await`s the service with **no try/catch**, then shows the success snackbar. On denial the exception is unhandled: no snackbar, no error, dialog already gone. (Unlike the phantom paths, the cache is *not* written — the throw happens first — so this is a crash-without-feedback, not a split-brain.)
- `isApproved: true` is hardcoded (:1815) — every client-marked record is born approved; there is no review step.

## What breaks

- Legitimate `faculty_advisor`/`teacher_lead` users are shown tools they cannot use; depending on the school's intent they are either wrongly locked out (rules too strict) or wrongly shown the buttons (client too loose).
- Any attendance-write denial produces an unhandled async exception with zero user feedback — the marker cannot tell whether the record saved.

## Solution

**No Blaze required:**

1. **Align the role lists — one source of truth.** Decide whether `faculty_advisor`/`teacher_lead` are real faculty roles:
   - If yes: add both to the rules `isAdmin()` role lists (token + users-doc branches) and deploy.
   - If no: remove them from `HierarchyService.isTeacherOrFaculty`.
   Either way, add a contract test asserting the client list and the rules list match, so they cannot drift again.
2. Wrap the attendance Save handler in try/catch: on error show "Attendance not saved: <reason>" and keep the dialog open; only show success after the service completes. Optionally make `markStudentAttendance` return a bool like the other truthful methods.
3. Reconsider `isApproved: true` — if attendance is meant to be reviewed, default to `false` and let staff approve; if not, drop the field rather than hardcoding it.

## Done when

- Client faculty roles == rules admin roles (test-enforced).
- A denied attendance write shows a visible error and saves nothing; a successful one shows success.
- No unhandled exception path remains in the attendance dialog.