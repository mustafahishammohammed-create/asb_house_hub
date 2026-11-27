# Academics Remediation Roadmap

Prioritized plan for A1–A7. **P0/P1/P2 are all no-Blaze** (client + rules + tests, deployable on Spark). Server-authority items are deferred to `election_audit/BLAZE_REQUIRED_FEATURES.md` **D5**.

Status: **P0 & P1 CLOSED** (all 11 items implemented, tested, and rules deployed). P2 open.

---

## P0 — Privacy & medical-data integrity (RESOLVED)

| # | Item | Finding | Change | Status / Evidence |
|---|------|---------|--------|-------------------|
| P0-1 | Lock report-card reads to owner + admin | A1 | `firestore.rules`: `isAdmin() \|\| ('scholar_no' in resource.data && isScholarOwner(resource.data.scholar_no))`; added `.handleError` fallback in `auth_service.dart:1559`. | **CLOSED** — Verified in `test/academics_security_test.dart`; deployed to `cloud.firestore` ("already up to date"). |
| P0-2 | Medical leaves: truthful writes + real errors | A3 | Removed `catch (_) {}` in `submitMedicalLeaveRequest`, `approveMedicalLeave`, `rejectMedicalLeave` (`auth_service.dart`); write to Firestore first, check `firestoreFailureSimulated`, return `false` on failure, cache only on ack; UI displays real red error snackbars on failure. | **CLOSED** — Verified by failure simulation unit tests in `test/academics_security_test.dart`. |
| P0-3 | Hide Medical Reports from non-staff | A3 | Gated Medical Reports tab on `HierarchyService.isTeacherOrFaculty \|\| isSuperAdmin` (`admin_claims_screen.dart`); council/captains see only Point Claims with single-tab view. | **CLOSED** — Verified by widget test in `test/academics_security_test.dart`. |
| P0-4 | Medical-leave rules validator + transition guard | A3 | Added `isValidMedicalLeave(data)` schema validator in `firestore.rules` (field whitelist, 500k photo cap, string bounds); update requires `resource.data.status == 'pending'` and `request.resource.data.status in ['approved', 'rejected']` with immutable core fields. | **CLOSED** — Rules-contract tests pass; deployed to `cloud.firestore`. |
| P0-5 | Real reviewer identity | A3 | Passed authenticated reviewer name from `_getReviewerName()` in `admin_claims_screen.dart` to `approveMedicalLeave`/`rejectMedicalLeave`. | **CLOSED** — Verified in unit tests asserting `reviewed_by` captures actual user profile. |

## P1 — Phantom-success eradication & gate alignment (RESOLVED)

| # | Item | Finding | Change | Status / Evidence |
|---|------|---------|--------|-------------------|
| P1-1 | Assignment publish/delete truthful + gated | A2 | `publishAssignment` / `deleteAssignment` write/delete Firestore first, check `firestoreFailureSimulated`, return `false` on denial, update cache only on ack (`auth_service.dart:1168-1243`). Gated `add_assignment_button`, `empty_add_assignment_button`, and `delete_assignment_*` to `isTeacherOrAdmin` (`academics_screen.dart:1777, 2072, 2340`). UI shows real red error snackbar on denial (`:2387, 2631`). | **CLOSED** — Verified by denial tests & student/staff widget tests in `test/academics_security_test.dart`. |
| P1-2 | Timetable bulk ops truthful + tab gated | A5 | `clearTimetableForDay` and `populateDefaultCBSEWeeklyTimetable` execute Firestore delete/batch first, check `firestoreFailureSimulated`, return `false` on denial, update cache only on ack (`auth_service.dart:792-918`). Gated `add_period_button`, `empty_add_period_button`, `populate_cbse_button`, `edit_period_*`, `delete_period_*` to `isTeacherOrAdmin` (`academics_screen.dart:452, 998, 1076`). Auto-load dialog labelled with starter schedule notice (`:1169`). | **CLOSED** — Verified by failure simulation and student read-only widget tests in `test/academics_security_test.dart`. |
| P1-3 | Align faculty role lists | A6 | Added `'faculty_advisor'` and `'teacher_lead'` to `firestore.rules` `isAdmin()` token and user-doc branches (`firestore.rules:251-252`). Matching exact 6 roles in `HierarchyService.isTeacherOrFaculty` (`hierarchy_service.dart:28-35`). | **CLOSED** — Verified by bidirectional rules contract test in `test/academics_security_test.dart`. Deployed to `cloud.firestore`. |
| P1-4 | Attendance dialog error handling | A6 | `markStudentAttendance` returns `Future<bool>`, executes live set first, check `firestoreFailureSimulated`, returns `false` on failure, updates cache only on ack (`auth_service.dart:1908-1964`). Save button wrapped in try/catch, checks boolean return; on failure dialog stays open and displays red error snackbar (`academics_screen.dart:6435-6490`). | **CLOSED** — Verified by failure simulation unit test in `test/academics_security_test.dart`. |
| P1-5 | Honours claim interim hardening | A4 | `claimReportCardHonoursMerit` inspects actual report card document (Firestore live or local cache offline), enforces `verifiedGpa >= 3.80` from doc (ignoring spoofed caller GPA), enforces caller scholar ownership (`card.scholarNo == sNo`), blocks already claimed cards (`card.isMeritClaimed == false`), drops doomed client write, updates cache only on verified award (`auth_service.dart:1647-1745`). | **CLOSED** — Verified by 4 unit tests (spoof rejection, mismatch rejection, already-claimed rejection, valid award success) in `test/academics_security_test.dart`. |
| P1-6 | Stop fabricating official report cards | A8 | Deleted hardcoded `principalRemarks`, `status`, `section` getters from `AcademicReportCard` model; replaced with real nullable/serialized fields defaulting to `'Published'` and `null` (`academic_report_card.dart:128, 173-176, 256-258`). In publisher dialog, removed `'2310910'` prefill and demo values; strictly validates numeric percentage (0-100), GPA (0-4), attendance (0-100) with error messages; subject breakdown sets `teacherComment: ''` (`academics_screen.dart:5310-5324, 5575-5630`). | **CLOSED** — Verified by model round-trip and validation tests in `test/academics_security_test.dart`. |

## P2 — Hygiene

| # | Item | Finding | Change | Verify |
|---|------|---------|--------|--------|
| P2-1 | Remove hardcoded identity fallbacks | A7 | Block leave submit when profile unresolved; no `2310910`/`Mohammed Ayaan`/`ruby` defaults | Cold-cache submit → clear error, no write |
| P2-2 | Collision-free leave IDs | A7 | Auto-ID or `med_${sNo}_${millis}` | Double-submit creates two docs |
| P2-3 | Attendance validator: bind scholar to path, check date | A7 | Pass `{scholarNo}` into `isValidAttendance`; date type check | Rules-contract test |
| P2-4 | Fix the "excused attendance" comment | A7 | Correct the doc comment: leave approval never excuses attendance — scholar remains absent (school policy, user-confirmed 2026-11-08). No automation wanted | Comment matches policy |
| P2-5 | Stream fallbacks catch async errors | A7/A1/A3 | `.handleError` → cache on report-cards and medical-leaves streams | Denial → cache fallback, no unhandled error |
| P2-6 | Empty publisher defaults | A9 | Teacher/paper-title/syllabus controllers start empty with hints (keep genuine defaults like hall/duration) | No boilerplate published unchanged |
| P2-7 | Attachments per-item cap | A9 | `isValidHomework`: each attachment item `is string && size() <= 2000` | Rules-contract test |

## Acceptance gate (whole module)

1. `flutter analyze` — 0 errors/warnings (infos ≤ current 20).
2. All existing suites stay green (61/61 security, 262/262 widget) + new academics denial/gate/validator tests.
3. `firebase deploy --only firestore:rules` succeeds; immediate re-run says "already up to date".
4. Manual smoke on a live build: student reads own report card only; student sees no publish/delete/edit affordances; council sees Point Claims but not Medical Reports; staff publish/delete/leave-approve flows show real success/failure.
5. Every `catch (_) {}` around an academics Firestore write is gone or justified in writing.

---

## Deferred to Blaze — D5 (do NOT start on Spark)

Mirrored in `election_audit/BLAZE_REQUIRED_FEATURES.md`:

1. **Atomic honours merit claim** (A4 end state): callable reads card → verifies ownership + GPA → checks `is_merit_claimed == false` → awards + sets flag in one transaction with idempotency key. Depends on D4 (`schoolGamification`).
2. **Live academics smoke test**: the P0–P2 manual checklist re-run against the deployed callables.

**Cancelled — do not build:** leave → excused-attendance automation. School policy (user-confirmed 2026-11-08): a scholar with a submitted or approved medical leave is still marked **absent**; the leave never overrides attendance.

**Order when Blaze arrives:** D4 first (points authority), then D5 item 1 (rides on the points callable), then item 2.