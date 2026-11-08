# A5. Timetable clear/CBSE-populate are phantom; edit buttons ungated; demo content hardcoded

**Severity:** LOW  
**Status:** RESOLVED (Phase P1, 2026-11-08)

## Resolution Evidence
- **Truthful Bulk Writes (`auth_service.dart:792-918`):** `clearTimetableForDay` and `populateDefaultCBSEWeeklyTimetable` execute Firestore delete/batch operations first, check `firestoreFailureSimulated`, return `false` on failure, and only mutate local cache upon verified server acknowledgement.
- **UI Gating (`academics_screen.dart:452, 998, 1076`):** `add_period_button`, `empty_add_period_button`, `empty_load_cbse_button`, `populate_cbse_button`, and the per-card Edit/Delete icon buttons are gated on `if (isTeacherOrAdmin)` (`HierarchyService.isTeacherOrFaculty || isSuperAdmin`). Students see a clean read-only schedule.
- **Starter Schedule Labeling (`academics_screen.dart:1169`):** The confirmation dialog explicitly informs the user that it populates an indicative starter template.
- **Automated Verification:** Verified by failure simulation unit tests & student read-only widget test in `test/academics_security_test.dart` and `test/widget_test.dart` (Test 226). All tests pass.

## Problem

The timetable tab is mostly truthful — `saveTimetablePeriod` ([auth_service.dart:686-737](../lib/services/auth_service.dart)) and `deleteTimetablePeriod` (:740-780) return `false` on live denial and the save UI shows the error ([academics_screen.dart:1562-1568](../lib/screens/academics_screen.dart)). Two paths break the pattern:

1. **Phantom bulk writes:**
   - `clearTimetableForDay` — [auth_service.dart:783-810](../lib/services/auth_service.dart): clears the cache first (:792), server deletes inside `catch (_) {}` (:794-804), `return true` (:806).
   - `populateDefaultCBSEWeeklyTimetable` — :813-897: caches each day (:878), server writes inside `catch (_) {}` (:879-889), `return true` (:893). The "CBSE Weekly Timetable Loaded Successfully!" snackbar ignores the result ([academics_screen.dart:1161-1170](../lib/screens/academics_screen.dart)).
2. **Ungated edit affordances.** Every period card shows Edit/Delete buttons ([academics_screen.dart:988-1010](../lib/screens/academics_screen.dart)) and the tab offers add/CBSE-load to all roles — there is **no role gate anywhere in the timetable tab** (the screen's only gates are grading :2211, exam publish :2683, report publish :4354, attendance :5705). Rules require `isAdmin()` for timetable writes ([firestore.rules:723-726](../firestore.rules)), so students tap buttons that can only ever fail (or phantom-succeed locally).
3. **Hardcoded demo content.** The CBSE template ships fixed teacher names and rooms ("Mr. Sharma", "Mrs. Nair", "Room 101"…) — [auth_service.dart:825-872](../lib/services/auth_service.dart) — presented as a real schedule, not labeled as a template.

## What breaks

- A student "loads the CBSE timetable" or clears a day → green success, local schedule changes, server untouched → their device shows a fabricated timetable until the next successful server read.
- Real staff whose write is denied (role mismatch, A6) get success on the bulk paths but honest errors on single-period saves — inconsistent behavior in one tab.
- Demo teacher names can be mistaken for the actual school schedule.

## Solution

**No Blaze required:**

1. Make `clearTimetableForDay` and `populateDefaultCBSEWeeklyTimetable` truthful: server write first (or collect per-doc failures), return `false` on any live denial, cache only acknowledged state; check the result in the UI.
2. Gate all timetable mutation affordances (add/edit/delete/CBSE-load/clear) on `isTeacherOrFaculty || isSuperAdmin`, matching the rules — students get a read-only schedule.
3. Label the CBSE template as a starter template in the confirm dialog, or move the teacher/room values into admin-editable config instead of hardcoded constants.

## Done when

- Denied bulk operations return failure and leave the cache unchanged; the UI reports it.
- Students see a read-only timetable; staff see edit controls.
- Tests: denial → `false` for both bulk methods; widget test for the read-only student view.