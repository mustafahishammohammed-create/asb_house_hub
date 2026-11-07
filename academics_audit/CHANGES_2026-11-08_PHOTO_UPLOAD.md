# Session Changes — 2026-11-08 (Photo Upload Feature + Audit Docs + Policy Correction)

Purpose: a complete, verification-ready record of **every change made in this session**, so each claim can be independently re-checked against the code. Nothing was deleted or reverted.

**Commit:** `c07c946` — "feat(academics): photo upload on timetable, assignment, report-card UIs" (15 files, +643 / −24). Pushed `fd0a4cd..c07c946` to `origin/mustafa1`.
**Verify the commit:** `git show c07c946 --stat` and `git log origin/mustafa1 -1`.

Context: the request was "add an option for uploading pic in each ui there like for timetable the leave then exam window and all". The exam window and medical-leave form **already had** photo pickers, so they were left untouched. Code edits were limited to the three UIs that lacked upload (timetable, assignments, report cards) plus their models/service/rules.

---

## 1. New file: `lib/widgets/academic_image.dart` (244 lines)

Shared photo widgets, all new:

| Item | Line | What it does |
|------|------|--------------|
| `buildAcademicImage(imageUrl, {fit})` | :6 | Renders base64 data-URL via `Image.memory`, else `Image.network`; broken-image icon fallback on decode/network error |
| `showAcademicImagePreview(context, imageUrl, title)` | :30 | Transparent dialog, `InteractiveViewer` (minScale 0.8, maxScale 4.0), max height 75% of screen, close button |
| `AcademicImageUploadField({label, value, onChanged})` | :87 | Camera + gallery buttons (`ImagePicker`, `imageQuality: 80, maxWidth: 1200`), emits `data:image/jpeg;base64,...`; preview + Remove when a value exists; picker errors shown as snackbar |
| `AcademicImageThumbnail({imageUrl, title, height = 120})` | :192 | Tappable thumbnail with "View Photo" badge; opens the preview dialog |

**Verify:** `git show c07c946 -- lib/widgets/academic_image.dart` (new file mode).

## 2. Models — `imageUrl` added (3 files)

Each model gained: `final String? imageUrl` field, ctor param, conditional `if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl` in `toMap()`, camelCase-tolerant `fromMap` (`map['image_url'] ?? map['imageUrl']`), and `copyWith` support.

| File | Field | toMap | fromMap | copyWith | == / hashCode |
|------|-------|-------|---------|----------|---------------|
| `lib/models/timetable_period.dart` | :15 | :161 | :186 | :206,:217 | :236,:249 |
| `lib/models/academic_assignment.dart` | :85 | :186 | :232 | :256,:271 | :294,:311 |
| `lib/models/academic_report_card.dart` | :108 | :170 | :249 | :278,:294 | (model has no ==) |

`lib/models/exam_schedule_item.dart` was **not** modified — it already had `imageUrl`.

## 3. UI wiring: `lib/screens/academics_screen.dart` (+55 lines, no deletions of existing logic)

| Change | Line(s) |
|--------|---------|
| Import `../widgets/academic_image.dart` | :15 |
| Period card: thumbnail under time/room chips (conditional on `period.imageUrl`) | :980-987 |
| Timetable modal: `String? photoBase64 = existing?.imageUrl;` | :1234 |
| Timetable modal: `AcademicImageUploadField` after the Break switch | :1531-1535 |
| Timetable modal: `imageUrl: photoBase64` in `TimetablePeriod(...)` | :1557 |
| Assignment card: thumbnail after Instructor text | :2094-2102 |
| Assignment modal: `String? photoBase64;` | :2371 |
| Assignment modal: upload field after Description | :2549-2553 |
| Assignment modal: `imageUrl: photoBase64` in `AcademicAssignment(...)` | :2573 |
| Report-card view: thumbnail before "Subject Performance Analytics" | :4938-4947 |
| Report-card dialog: `String? photoBase64;` | :5272 |
| Report-card dialog: upload field after Teacher Remarks | :5503-5507 |
| Report-card dialog: `imageUrl: photoBase64` in `publishStudentReportCard(...)` | :5593 |

**Not mine (pre-existing, untouched):** exam publisher `photoBase64` :3559 / :4102; leave-form picker :6690.

## 4. Service: `lib/services/auth_service.dart` (3 lines)

- :1649 — new `String? imageUrl,` parameter on `publishStudentReportCard`.
- :1670 — `imageUrl: imageUrl,` passed into the `AcademicReportCard` ctor.
- :6469 — comment corrected to: "Approves a medical leave. Does not alter attendance — the scholar is still marked absent (school policy)." (comment only, no logic change).

Timetable and assignment saves needed **no** service change — they persist `model.toMap()`, so the new field flows automatically. `publishExamScheduleRange` already had `imageUrl` (:1335) — untouched.

## 5. Rules: `firestore.rules` (+2 / −1 lines) — DEPLOYED

- :384 — `'image_url'` appended to the `isValidHomework` allowed-fields whitelist (covers both `/classes/{id}/assignments` and `/homework`).
- :398 — new cap: `(!('image_url' in data) || (data.image_url is string && data.image_url.size() <= 500000)) &&`.

Timetable / midterm_exams / report_cards rules are admin-write-only with no field validator, so the new field passes there without rules changes.

**Deploy result:** `firebase deploy --only firestore:rules --non-interactive` → "rules file firestore.rules compiled successfully" → "released rules firestore.rules to cloud.firestore" → "Deploy complete!" (2026-11-08).
**Re-verify cloud matches repo:** run the same deploy command again; it should say "already up to date, skipping upload".

## 6. New file: `test/academics_image_test.dart` (8 tests, all passing)

1. TimetablePeriod imageUrl round-trip + empty-omission + camelCase + copyWith + equality
2. AcademicAssignment round-trip + **every toMap key ∈ isValidHomework whitelist** (parsed from firestore.rules)
3. AcademicReportCard round-trip
4. ExamScheduleItem imageUrl regression (pre-existing feature)
5. Rules contract: `image_url` whitelisted with the 500000-char string cap
6. Widget: upload field shows Take Photo/Upload Image when empty, Remove when set; Remove clears value
7. Widget: thumbnail tap opens dialog with title + InteractiveViewer
8. Widget: invalid base64 → broken-image icon, no exception

## 7. Audit documentation (docs only, no code)

| File | Change |
|------|--------|
| `academics_audit/A8-report-card-fabricated-content.md` | NEW finding (MEDIUM): publisher synthesizes subject grades from one percentage with fixed offsets, canned comments, silent 90.0/98.0 fallbacks, hardcoded 'Official'/'A'/principal endorsement, demo scholar prefill |
| `academics_audit/A9-demo-prefills-attachments-caps.md` | NEW finding (LOW): demo prefills + uncapped attachment items; status note added that the `image_url` cap is now shipped |
| `academics_audit/README.md` | Added "Shipped feature" section (this work); updated photo-picker bullet; A8/A9 rows |
| `academics_audit/A3-medical-leave-phantom-role-mismatch.md` | Policy note: leave never excuses attendance |
| `academics_audit/A7-identity-fallbacks-data-hygiene.md` | Same policy correction |
| `academics_audit/REMEDIATION_ROADMAP.md` | D5 leave→excused-attendance automation marked cancelled |
| `election_audit/BLAZE_REQUIRED_FEATURES.md` | D5 rewritten: only atomic honours-merit callable + live smoke test remain; policy note that the excused-attendance automation is cancelled and must not be built |

## 8. Policy correction (user-confirmed 2026-11-08)

"Even if leave is submitted he is marked absent." Medical leave is documentation only — it **never** excuses attendance. Applied to: the code comment (:6469 above), the five docs in §7, and a project-memory file (`project-leave-attendance-policy.md`, outside the repo) so it is not reintroduced later. No attendance logic was changed.

---

## Verification results (run first-hand this session)

| Check | Command | Result |
|-------|---------|--------|
| Static analysis | `flutter analyze` | 20 infos, 0 errors, 0 warnings (unchanged baseline) |
| Full test suite | `flutter test` | **331/331 passed** (262 widget + 61 security + 8 new) |
| Rules compile + deploy | `firebase deploy --only firestore:rules --non-interactive` | compiled successfully, released |
| Push | `git push origin mustafa1` | `fd0a4cd..c07c946` |

**Not done / limits:** the app was not run on a device or emulator — the new widgets are covered by widget tests only, not a visual smoke test. Findings A1–A9 themselves were **not** fixed (audit docs only); the sole rules change is the `image_url` whitelist+cap.

## Explicitly NOT changed

- No file deleted, no change reverted, no existing logic removed.
- Exam-window and leave-form pickers (already existed).
- `exam_schedule_item.dart`, `publishExamScheduleRange`, attendance/leave submit/approve/reject logic.
- All other modules (elections, gamification, sports, wallet, etc.).