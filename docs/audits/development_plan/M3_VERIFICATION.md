# M3 verification — timetable advanced (tests 18–19, 31–33, substitution)

**Date:** 2026-11-08
**Branch:** `mustafa1` (M3 work is the commit following this document)
**Method:** read of `class_timetable.dart`, `timetable_service.dart`, `teacher_timetable_editor_screen.dart`, `academics_screen.dart`, `timetable_period.dart`, `firestore.rules`; targeted M3 suite; full suite; `flutter analyze`; rules deployment output.
**Verdict:** M3 is **done for its stated Spark scope**. Double-booking (18–19), copy-to-selected-days (31–32), one-day overrides (33), substitution markers, and transition gaps are implemented and tested. Notification fan-out for substitutions remains M6/test 60, and conflict checks remain client-side at publish time.

## Delivered

| Area | Status | Evidence |
|---|---|---|
| **Tests 18–19 — teacher/room double-booking** | ✅ **DONE (client-side)** | `ClassTimetableVersion.detectConflicts` compares a candidate against other classes' active published versions at distinct start times. `TimetableService.findTimetableConflicts` queries `timetable_versions` with equality-only filters (`day_of_week`, `status == published`), resolves each class's active version locally (including overrides), and ignores same-class/unpublished docs. `publishTimetable(..., enforceConflicts: true)` is the default and returns `false` before any write when a conflict exists. The editor preflights and shows `timetable_conflict_dialog` instead of publishing. |
| **Tests 31–32 — copy to selected days** | ✅ **DONE** | `copyTimetableToDays` creates a **new version per selected target day** (draft by default), skips the source day, never mutates existing days, strips substitute markers, and returns a per-day success map. Existing other-day versions are untouched; publishing one copied day leaves the rest as drafts. UI: copy dialog with day checkboxes. |
| **Test 33 — temporary one-day override** | ✅ **DONE** | `ClassTimetableVersion.overrideDate`, `isTemporary`, and override-aware `activeForDate` prefer a published override on its exact date, then fall back to the recurring published version. Overrides live in the same `timetable_versions` collection with `override_date`; validation rejects Friday and a date whose weekday does not match the version's day. `saveTimetableOverride` writes a separate document and leaves the recurring version intact. |
| **Substitution** | ✅ **DONE** | `TimetableSlot.substituteTeacherName/Uid`, `hasSubstitute`, `effectiveTeacherName`; recurring versions strip substitute fields, only the dated override carries them. Teacher editor assigns/clears a substitute in override mode; student timetable shows a `SUBSTITUTE` badge, substitute name, and original teacher. Service writes a `substitute` audit entry. Substitution notification fan-out is implemented and tested in M6/test 60 (`NotificationService.notifyTimetableSubstitution`). |
| **Transition gaps** | ✅ **ALREADY SUPPORTED (M2)** | The M2 validator accepts non-contiguous starts as long as periods do not overlap. Covered by `class_timetable_test.dart` → `accepts transition gaps between periods (no overlap)`. No M3 code change was needed. |
| **Rules** | ✅ **DEPLOYED** | `override_date` timestamp and substitute slot fields are whitelisted; published schedules are readable by any signed-in user so cross-class conflict checks work (drafts/submitted/rejected stay class-scoped); audit actions accept `copy` and `substitute`. Deployed to `cloud.firestore`; rules compiled successfully. |
| **Truthful writes** | ✅ **DONE** | A denied override returns `null` and caches nothing. Copy reports per-day failures. Publish returns `false` and writes nothing when the conflict gate fires. |

## Test evidence

`test/timetable_m3_test.dart` — **23/23 passing**, in seven groups:

- **M3a** (3): override wins for its exact date only; `override_date` round-trips Firestore/cache maps; Friday and mismatched-weekday validation.
- **M3b** (5): teacher double-booking detected; publish blocked and writes nothing; room double-booking detected; adjacent periods allowed; pure detector ignores same-class and unpublished versions.
- **M3c** (3): copy targets only selected days; source day is never mutated; copied days publish independently.
- **M3d** (4): publishing an override leaves the recurring version intact; substitution is date-specific; denied override caches nothing; invalid dates rejected.
- **M3e** (1): `TimetablePeriod` substitute metadata round-trips.
- **M3f** (4): copy dialog; override + substitute assignment saves a dated version; student temporary banner + substitute indicator; conflict dialog blocks publish.
- **M3g** (3): rules source contract for override/substitute fields, published cross-class reads, and audit actions.

Commands run:

- `flutter test test/timetable_m3_test.dart` → **23/23**
- `flutter test` → **463/463**
- `flutter analyze` → **0 errors, 0 warnings**, 20 pre-existing infos (unnecessary underscores and `print` in `tool/`)
- `firebase.cmd deploy --only firestore:rules` → **compiled and released**

## Honest limits / follow-ups

1. **Client-side conflict check, not transactional.** Two editors can publish conflicting schedules concurrently between the query and the write. Server-side validation at scale remains Blaze-deferred; the rules cannot express cross-document conflict checks on Spark.
2. **Conflict checks only consider published versions.** Drafts and submitted versions do not block; this is intentional so editors can prepare changes.
3. **Rules tests remain source-contract assertions.** No emulator harness was added (same V8 caveat as M2).
4. **Substitution notification delivered in M6.** Handled via `NotificationService.notifyTimetableSubstitution` in M6 / test 60.
5. **Approval queue and admin grant/revoke UI are not M3 leftovers.** The queue stays in M7; the permission UI is M2 V7 (non-blocking).
6. **Copy publishes only when explicitly requested.** The UI copies as drafts; existing days are never overwritten.

## Handoff

Next module: **M4 — house communication groups** per `REMAINING_MODULES_REPORT.md`. Keep M6 notification fan-out and M2 V6/V7 on the follow-up list. Do not regress elections, points, sports, wallet, merch, ID scanner, behavior, 1:1 chat, account switching, A1–A6/A8, or photo upload.
