# M2 verification — independent check of commit `23a87cd`

**Date:** 2026-11-08
**HEAD checked:** `23a87cd` on `mustafa1` (`feat(academics): implement teacher-managed recurring weekly timetable engine (M2)`), clean vs `origin/mustafa1`.
**Method:** read of `class_timetable.dart`, `timetable_service.dart`, `hierarchy_service.dart`, `teacher_timetable_editor_screen.dart`, `academics_screen.dart` timetable tab, `firestore.rules` matchers `timetable_versions` / `timetable_audit`, and `test/timetable_engine_test.dart` rules-contract group. Secrets were not opened.
**Verdict:** M2a–M2e **core engine is real and should be kept**. The “M2 complete, all 9 robustness boxes, tests 9–30 and 34–38 via UI and direct rules denial” claim is **not true**. Do **not** start M3 until the blockers below are fixed. Passing `433/433` does not cover these holes: the rules tests only search `firestore.rules` for substrings, and one of those substrings is the incomplete slot check.

Each item: **Problem → What breaks → Solution → Done when**.

---

## What is actually shipped (do not redo)

- Versioned model: 6 days Sat–Thu, 8 slots, end time derived as start+45, break end derived as start+30, `validate()` chronology, `activeForDate`.
- `TimetableService` draft / submit / publish / restore-creates-new-version, section cache keys, `.handleError` on the three streams, `firestoreFailureSimulated` on the version writes.
- Class fields `classTeacherUid`, `timetableEditorUids`, `timetableEditingEnabled`, `timetableRequiresApproval`.
- `HierarchyService.canEditTimetable` unit matrix (test 35) and `updateClassTimetablePermissions` in `AuthService` (no screen calls it).
- Rules: Friday absent from the day whitelist; create/publish split via `canPublishTimetable`; audit `allow update, delete: if false`; students are not `isTimetableEditor` because that helper requires `isAdmin()`.
- Teacher editor: day selector, 07:45-style start pickers, auto end, break, validation snackbar, draft, submit-vs-publish, preview dialog, restore modal, photo field.
- Student `TimetableTab`: Sat–Thu, `getActiveTimetableStream`, legacy grade timetable fallback, in-progress card still driven by `TimetablePeriod`.

---

## Blockers (fix before M3)

### V1 — Rules do not validate slots 1–6, overlap, or break placement

**Problem.** `isValidTimetableVersion` checks `slots.size() == 8` and calls `isValidTimetableSlot` only on `slots[0]` and `slots[7]` (`firestore.rules` around the validator). There is no check that every index is a slot, that period numbers are exactly 1..8, that start minutes are strictly increasing, or that the break window `[break_start_minute, break_start_minute+30)` sits in a gap. `isValidTimetableSlot` has no end field, so a 45-minute duration cannot be forged as a stored end — duration is implicit — but overlap is not implicit.

**What breaks.** Any timetable editor (or a modified client using their uid) can publish overlapping periods and a break that lands on top of a period. Acceptance tests 16, 17, and 34 are enforced only inside `ClassTimetableVersion.validate()`, which a direct write skips. The engine test named “rules enforces 8 slots” asserts the `slots[0]` / `slots[7]` strings, so the suite stays green while the hole is open. Antigravity’s note “durations locked to 45; break locked to 30; no overlap in rules” overclaims this.

**Solution.** In `isValidTimetableSlot` / `isValidTimetableVersion`, validate all eight indexes. Require `period_number == index+1` for a sorted list, or require the list already ordered 1..8. Require `slots[i].start_minute + 45 <= slots[i+1].start_minute` after placing the break as a synthetic interval when `break_after_period == i+1` (break occupies `break_start_minute` .. `+ 30`). Reject the write when the break overlaps a period or periods overlap each other.

**Done when.** A rules-contract test (string or, better, a small evaluated fixture) shows a 7-valid-plus-one-garbage list fails, an overlapping start fails, and a break covering the next period fails. Happy-path 8×45 still passes `class_timetable_test` and `timetable_engine_test`.

### V2 — `rejectTimetable` writes a field the rules delete

**Problem.** `TimetableService.rejectTimetable` updates `rejection_reason`. That key is not in `isValidTimetableVersion`’s `hasOnlyAllowedFields` list. The model has no rejection field either.

**What breaks.** On the deployed rules, every live reject is denied. The method then returns `false` (this path is truthful). Acceptance test 36 (admin reject) cannot succeed against Firestore. Local cache is not updated on that failure, so the UI and the server agree on failure — the feature is simply absent live.

**Solution.** Add `rejection_reason` (string, size cap, e.g. 500) to the model `toMap` / `fromMap`, the rules whitelist, and the reject update. Keep status transition `submitted → rejected` (and senior `published` override only if test 37 explicitly needs it). Do not let reject succeed in cache when the write fails.

**Done when.** A unit test builds the reject payload and asserts every key is in the rules whitelist; a widget or service test covers reject returning false when `firestoreFailureSimulated` is set.

### V3 — Published history is not immutable for senior admins

**Problem.** `timetable_versions` update allows `isSeniorAdmin()` with no `status != 'published'` guard. Editors cannot patch a published doc; a principal can rewrite its slots in place.

**What breaks.** Restore correctly creates a new version (`supersedes_id`). The robustness line “history immutable” is still false: one rules path overwrites a published version. Audit cannot reconstruct the old slots.

**Solution.** Deny slot/break/effective-date changes on `status == 'published'` for everyone, including senior admins. Override and restore already go through `restoreTimetableVersion` (new id). If a senior must reject a live version, allow only a status transition to a new doc, not an in-place slot edit. Keep `allow delete` of published docs false (already true).

**Done when.** Rules contain the published-field freeze, and a contract test fails if `isSeniorAdmin()` can change `slots` on a published doc.

### V4 — Test 35 is not on the screen that teachers actually open

**Problem.** `academics_screen.dart` shows `manage_recurring_timetable_button` for every `isTeacherOrFaculty` / super admin. The route uses `classId: canonicalClassId.isNotEmpty ? canonicalClassId : '10A'`. `TeacherTimetableEditorScreen` never calls `HierarchyService.canEditTimetable`.

**What breaks.** An unassigned teacher still gets an editor, and a teacher with no `class_id` opens class `10A`. Rules should deny the write (V1 notwithstanding), so this is not a silent publish for a random teacher — but test 35 required the denial in the product, and the `'10A'` fallback can target a real section by mistake. Council/students do not get the button.

**Solution.** Resolve the class from the teacher’s assignment or an explicit class picker. If `canEditTimetable` is false, hide the button and block Save / Publish in the editor (rules stay the backstop). Delete the `'10A'` fallback.

**Done when.** A widget test: unassigned teacher finds no `manage_recurring_timetable_button`; assigned class teacher does; opening the editor without a class id does not call `saveTimetableDraft` for `10A`.

---

## Not blockers for M3, but the report checked them off falsely

### V5 — Publish does not notify the roster

**Problem.** `publishTimetable` writes the version and an audit doc. It never writes `users/{uid}/notifications`. The M2 robustness box “Publish triggers roster sync + notifications (M6 foundation)” is checked.

**What breaks.** Students with the timetable stream open do see the new published version (test 20’s live-sync half). Nobody gets an in-app notification. That is acceptance test 60, owned by M6. Checking the box makes M6 look already started.

**Solution.** Leave fan-out to M6. Uncheck the box. Do not build Cloud Functions.

**Done when.** The status table says stream sync yes, notification docs no.

### V6 — Audit write reports success when Firestore denies it

**Problem.** `writeTimetableAudit` catches a real Firestore error, still caches the entry, and returns `true`. Callers ignore the bool. Version writes themselves return `false` on denial — that part is fine.

**What breaks.** A publish can succeed and the audit can fail (rules: `actor_uid` must equal `request.auth.uid`) while the UI says the whole operation succeeded. The local audit list then shows a row the server does not have.

**Solution.** Return `false` from `writeTimetableAudit` on a real denial, skip the cache write, and surface it from publish/submit/restore (version already committed: tell the user “saved, audit failed” rather than pretending the audit exists).

**Done when.** Simulated audit failure does not cache and does not return true.

### V7 — No admin control to grant or revoke editors

**Problem.** `AuthService.updateClassTimetablePermissions` has no caller under `lib/screens`. M2b asked for grant/revoke, editing-enabled, and requires-approval in this module; M7 only hosts the full queue.

**What breaks.** `timetableRequiresApproval` and editor lists work if a document is hand-edited. No admin in the app can set them. Test 36’s “when required” path cannot be turned on from the UI.

**Solution.** A small section on the existing admin academics class card is enough for M2. The approval queue list can wait for M7.

**Done when.** An admin widget test toggles `timetable_requires_approval` and adds one uid, and a non-admin call is not offered.

### V8 — “Direct rules denial” was not run

**Problem.** Definition of done says tests 9–30 and 34–38 pass via UI **and** direct rules denial. What exists is model/service/widget tests plus five `rulesContent.contains(...)` checks.

**What breaks.** Substring checks cannot deny a student write or an overlapping payload. The repo has no rules emulator harness; do not pretend one ran.

**Solution.** Either add the Firebase rules unit emulator for these matchers, or label the current tests “source contract” and add the V1–V3 assertions to that contract so a regression fails in `flutter test`. Do not claim emulator denial until it is run.

**Done when.** The report’s definition of done matches the kind of test that actually ran.

---

## Explicitly still M3 (not M2 leftovers)

Double-booking (tests 18–19), copy timings to selected days (31–32), one-day overrides (33), substitute tags. `activeForDate` has no override precedence yet. Do not start these inside the V1–V4 fix.

---

## Standing constraints (unchanged)

Spark only. No leave-excuses-attendance. Do not regress elections, points, sports, wallet, merch, ID scanner, behavior, 1:1 chat, account switching, A1–A6/A8, or photo upload. No secret values in docs or commits. Truthful version writes stay server-first.

---

## Instruction for the implementer

1. Fix **V1, V2, V3, V4**. Add tests that fail on the old rules/UI.
2. Correct this report and `REMAINING_MODULES_REPORT.md`: M2 stays **partial** until those four are green. Uncheck V5 until M6.
3. `flutter analyze` and the timetable suites, then the full suite. Deploy `firestore.rules` only. Commit and push to `mustafa1`.
4. Then start M3 from the M3 section of `REMAINING_MODULES_REPORT.md`. Client-side conflict checks only; server-side conflict at scale stays Blaze.
