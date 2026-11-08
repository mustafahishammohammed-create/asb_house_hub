# M2 verification — independent check of commit `23a87cd`

**Date:** 2026-11-08 (remediation verification added)
**HEAD checked:** original audit at `23a87cd`; V1–V4 remediation is the commit following this document on `mustafa1`.
**Method:** read of `class_timetable.dart`, `timetable_service.dart`, `hierarchy_service.dart`, `teacher_timetable_editor_screen.dart`, `academics_screen.dart` timetable tab, `firestore.rules` matchers `timetable_versions` / `timetable_audit`, and the timetable test groups. Secrets were not opened.
**Verdict (updated):** M2a–M2e core engine is real and kept. **V1–V4 are fixed and covered by tests.** M2 is complete for its stated scope. V5 is explicitly owned by M6. V6 (audit truthfulness) and V7 (admin grant/revoke UI) remain non-blocking follow-ups. V8 stands: the rules tests are source-contract assertions, not evaluated emulator denials.

## Remediation status (V1–V4)

| Item | Status | Evidence |
|---|---|---|
| **V1** — rules did not validate slots 1–6, overlap, or break placement | ✅ **FIXED** | `firestore.rules` now validates all 8 slot indexes, period numbers `1..8`, monotonic 45-minute separation, last period ending by midnight, and `isValidTimetableBreakPlacement(...)` for every break position. Source-contract tests in `test/timetable_engine_test.dart` fail on the old rules. |
| **V2** — `rejection_reason` was not whitelisted; live reject denied | ✅ **FIXED** | `ClassTimetableVersion.rejectionReason` serializes to/from `rejection_reason`; the rules whitelist accepts it with a 500-character cap; `rejectTimetable` trims/validates the reason, returns `false` on denial, and does not cache. Tests cover round-trip, whitelist keys, and truthful denial. |
| **V3** — senior admins could rewrite published versions in place | ✅ **FIXED** | `timetable_versions` update now requires `resource.data.status != 'published'` before any editor or senior-admin branch. Restore/override still creates a new document. Contract test extracts the update block and asserts the freeze guards the senior branch. |
| **V4** — editor button was not gated; `'10A'` fallback | ✅ **FIXED** | `TimetableTab` resolves an editable class from the registry using `HierarchyService.canEditTimetable`; no `'10A'` fallback remains. Super admins with no resolved class get an explicit picker. `TeacherTimetableEditorScreen` blocks Save/Publish and renders an authorization screen when `canEditTimetable` is false. Widget tests cover unassigned versus assigned teachers. |
| **V5** — publish does not notify the roster | ⏳ **OPEN (M6)** | Still no `users/{uid}/notifications` fan-out. Do not mark this box. |
| **V6** — audit write reports success when denied | ⏳ **OPEN (non-blocking)** | `writeTimetableAudit` still caches and returns `true` on a real denial. Track with V7. |
| **V7** — no admin UI to grant/revoke editors | ⏳ **OPEN (non-blocking)** | `updateClassTimetablePermissions` still has no screen caller. |
| **V8** — “direct rules denial” was not run | ⏳ **OPEN (test method)** | Tests are explicitly labelled source contract. No rules emulator harness exists in the repo. |

Each item below: **Problem → What breaks → Solution → Done when**.

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

### ✅ V1 — Rules do not validate slots 1–6, overlap, or break placement (FIXED)

**Problem.** `isValidTimetableVersion` checks `slots.size() == 8` and calls `isValidTimetableSlot` only on `slots[0]` and `slots[7]` (`firestore.rules` around the validator). There is no check that every index is a slot, that period numbers are exactly 1..8, that start minutes are strictly increasing, or that the break window `[break_start_minute, break_start_minute+30)` sits in a gap. `isValidTimetableSlot` has no end field, so a 45-minute duration cannot be forged as a stored end — duration is implicit — but overlap is not implicit.

**What breaks.** Any timetable editor (or a modified client using their uid) can publish overlapping periods and a break that lands on top of a period. Acceptance tests 16, 17, and 34 are enforced only inside `ClassTimetableVersion.validate()`, which a direct write skips. The engine test named “rules enforces 8 slots” asserts the `slots[0]` / `slots[7]` strings, so the suite stays green while the hole is open. Antigravity’s note “durations locked to 45; break locked to 30; no overlap in rules” overclaims this.

**Solution.** In `isValidTimetableSlot` / `isValidTimetableVersion`, validate all eight indexes. Require `period_number == index+1` for a sorted list, or require the list already ordered 1..8. Require `slots[i].start_minute + 45 <= slots[i+1].start_minute` after placing the break as a synthetic interval when `break_after_period == i+1` (break occupies `break_start_minute` .. `+ 30`). Reject the write when the break overlaps a period or periods overlap each other.

**Done when.** A rules-contract test (string or, better, a small evaluated fixture) shows a 7-valid-plus-one-garbage list fails, an overlapping start fails, and a break covering the next period fails. Happy-path 8×45 still passes `class_timetable_test` and `timetable_engine_test`.

**Fix applied (2026-11-08).** `isValidTimetableVersion` validates `slots[0]` through `slots[7]`; `hasOrderedTimetableSlots` requires period numbers `1..8`, 45-minute non-overlap between consecutive periods, and a final end before midnight; `isValidTimetableBreakPlacement` checks every `break_after_period` value and rejects a break that overlaps the following period or runs past midnight. The source-contract group in `test/timetable_engine_test.dart` asserts every index and break position, so the old incomplete validator fails the suite. The happy path still passes the model and engine suites.

### ✅ V2 — `rejectTimetable` writes a field the rules delete (FIXED)

**Problem.** `TimetableService.rejectTimetable` updates `rejection_reason`. That key is not in `isValidTimetableVersion`’s `hasOnlyAllowedFields` list. The model has no rejection field either.

**What breaks.** On the deployed rules, every live reject is denied. The method then returns `false` (this path is truthful). Acceptance test 36 (admin reject) cannot succeed against Firestore. Local cache is not updated on that failure, so the UI and the server agree on failure — the feature is simply absent live.

**Solution.** Add `rejection_reason` (string, size cap, e.g. 500) to the model `toMap` / `fromMap`, the rules whitelist, and the reject update. Keep status transition `submitted → rejected` (and senior `published` override only if test 37 explicitly needs it). Do not let reject succeed in cache when the write fails.

**Done when.** A unit test builds the reject payload and asserts every key is in the rules whitelist; a widget or service test covers reject returning false when `firestoreFailureSimulated` is set.

**Fix applied (2026-11-08).** `ClassTimetableVersion` now stores `rejectionReason` and round-trips it through `rejection_reason`; `toMap` emits the field only when non-empty. The rules whitelist accepts `rejection_reason` with a 500-character cap. `rejectTimetable` trims the reason, rejects empty/oversized reasons, includes the field in the update, returns `false` on a simulated or real denial, and skips the cache and audit on failure. Tests cover the model round-trip, the whitelist keys, and the truthful-denial path.

### ✅ V3 — Published history is not immutable for senior admins (FIXED)

**Problem.** `timetable_versions` update allows `isSeniorAdmin()` with no `status != 'published'` guard. Editors cannot patch a published doc; a principal can rewrite its slots in place.

**What breaks.** Restore correctly creates a new version (`supersedes_id`). The robustness line “history immutable” is still false: one rules path overwrites a published version. Audit cannot reconstruct the old slots.

**Solution.** Deny slot/break/effective-date changes on `status == 'published'` for everyone, including senior admins. Override and restore already go through `restoreTimetableVersion` (new id). If a senior must reject a live version, allow only a status transition to a new doc, not an in-place slot edit. Keep `allow delete` of published docs false (already true).

**Done when.** Rules contain the published-field freeze, and a contract test fails if `isSeniorAdmin()` can change `slots` on a published doc.

**Fix applied (2026-11-08).** The `timetable_versions` update rule now starts with `resource.data.status != 'published'`, so no editor, senior admin, or principal can update a published document in place. Restore and override continue to create a new document linked by `supersedes_id`. A source-contract test extracts the update block and asserts the freeze appears before the senior branch; the old rule fails it.

### ✅ V4 — Test 35 is not on the screen that teachers actually open (FIXED)

**Problem.** `academics_screen.dart` shows `manage_recurring_timetable_button` for every `isTeacherOrFaculty` / super admin. The route uses `classId: canonicalClassId.isNotEmpty ? canonicalClassId : '10A'`. `TeacherTimetableEditorScreen` never calls `HierarchyService.canEditTimetable`.

**What breaks.** An unassigned teacher still gets an editor, and a teacher with no `class_id` opens class `10A`. Rules should deny the write (V1 notwithstanding), so this is not a silent publish for a random teacher — but test 35 required the denial in the product, and the `'10A'` fallback can target a real section by mistake. Council/students do not get the button.

**Solution.** Resolve the class from the teacher’s assignment or an explicit class picker. If `canEditTimetable` is false, hide the button and block Save / Publish in the editor (rules stay the backstop). Delete the `'10A'` fallback.

**Done when.** A widget test: unassigned teacher finds no `manage_recurring_timetable_button`; assigned class teacher does; opening the editor without a class id does not call `saveTimetableDraft` for `10A`.

**Fix applied (2026-11-08).** `TimetableTab` reads the verified `academic_classes` registry and collects only classes where `HierarchyService.canEditTimetable` is true. The button is hidden when that list is empty; a single editable class opens directly; multiple classes (including a super admin with no profile class) open an explicit picker. The `'10A'` fallback is deleted. `TeacherTimetableEditorScreen` computes `_canEdit` from the same service, renders an authorization screen without Save/Publish when false, and re-checks the flag in both write handlers. Widget tests cover the unassigned teacher (no button, blocked editor, no `10A` write) and the assigned teacher (editor available).

---

## Not blockers for M3, but the report checked them off falsely

### ⏳ V5 — Publish does not notify the roster (OPEN — M6)

**Problem.** `publishTimetable` writes the version and an audit doc. It never writes `users/{uid}/notifications`. The M2 robustness box “Publish triggers roster sync + notifications (M6 foundation)” is checked.

**What breaks.** Students with the timetable stream open do see the new published version (test 20’s live-sync half). Nobody gets an in-app notification. That is acceptance test 60, owned by M6. Checking the box makes M6 look already started.

**Solution.** Leave fan-out to M6. Uncheck the box. Do not build Cloud Functions.

**Done when.** The status table says stream sync yes, notification docs no.

### ⏳ V6 — Audit write reports success when Firestore denies it (OPEN — non-blocking)

**Problem.** `writeTimetableAudit` catches a real Firestore error, still caches the entry, and returns `true`. Callers ignore the bool. Version writes themselves return `false` on denial — that part is fine.

**What breaks.** A publish can succeed and the audit can fail (rules: `actor_uid` must equal `request.auth.uid`) while the UI says the whole operation succeeded. The local audit list then shows a row the server does not have.

**Solution.** Return `false` from `writeTimetableAudit` on a real denial, skip the cache write, and surface it from publish/submit/restore (version already committed: tell the user “saved, audit failed” rather than pretending the audit exists).

**Done when.** Simulated audit failure does not cache and does not return true.

### ⏳ V7 — No admin control to grant or revoke editors (OPEN — non-blocking)

**Problem.** `AuthService.updateClassTimetablePermissions` has no caller under `lib/screens`. M2b asked for grant/revoke, editing-enabled, and requires-approval in this module; M7 only hosts the full queue.

**What breaks.** `timetableRequiresApproval` and editor lists work if a document is hand-edited. No admin in the app can set them. Test 36’s “when required” path cannot be turned on from the UI.

**Solution.** A small section on the existing admin academics class card is enough for M2. The approval queue list can wait for M7.

**Done when.** An admin widget test toggles `timetable_requires_approval` and adds one uid, and a non-admin call is not offered.

### ⏳ V8 — “Direct rules denial” was not run (OPEN — test method)

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

1. ~~Fix **V1, V2, V3, V4**. Add tests that fail on the old rules/UI.~~ **Done 2026-11-08.**
2. ~~Correct this report and `REMAINING_MODULES_REPORT.md`: M2 stays **partial** until those four are green. Uncheck V5 until M6.~~ **Done; M2 is complete for its scope, V5 remains unchecked.**
3. ~~`flutter analyze` and the timetable suites, then the full suite. Deploy `firestore.rules` only. Commit and push to `mustafa1`.~~ **Done: analyze 0 errors/0 warnings; timetable suites 52/52; full suite 440/440; rules deployed; commit pushed.**
4. **Next:** start M3 from the M3 section of `REMAINING_MODULES_REPORT.md`. Client-side conflict checks only; server-side conflict at scale stays Blaze. Keep V6/V7 on the follow-up list.
