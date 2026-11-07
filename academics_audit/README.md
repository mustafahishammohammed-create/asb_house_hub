# Academics Module Audit — Findings & Fixes

Deep read-only audit of the academics module: the five-tab `academics_screen.dart` (Timetable, Assignments, Exams, Report Cards, Attendance), every academics method in `AuthService` (timetable CRUD, assignment publish/delete/grade, exam publish, report-card publish/merit claim, attendance mark, medical-leave submit/approve/reject), the `AdminClaimsScreen` Medical Reports tab, the academic models, and the corresponding `firestore.rules` blocks.

**Method:** full static read of every file involved, rules-vs-client cross-check, attack-scenario tracing. No code files were modified. Audited at HEAD `91114ea` (2026-11-08); test baseline unchanged since `753c976` (61/61 security, 262/262 widget, analyze 0 errors / 20 infos).

**Verdict:** the module's *server* perimeter is mostly sound — rules hold every sensitive write, assignment submissions carry the full R-2/R-5/N-2 protection set, and exam/report publishing is truthful and gated. The disease is the one already cured in points: **phantom success** (denied writes swallowed, cache flipped, green snackbar) survives in assignment publish/delete, medical leaves, and timetable bulk ops; **one real privacy hole** (report cards world-readable); and **one time-bomb** (honours merit trusts client GPA and its claimed-flag can never persist — safe today only because student awards are fail-closed pending D4).

Each finding follows: **Problem → What breaks → Solution → Done when**.

## High (1)

| ID | Finding | Key evidence |
|----|---------|--------------|
| A1 | Report cards readable by any signed-in student; enumerable `rep_{scholar}_{term}` IDs | [A1](A1-report-cards-world-readable.md) — firestore.rules:764-767, auth_service.dart:1653 |

## Medium (3)

| ID | Finding | Key evidence |
|----|---------|--------------|
| A2 | Assignment publish/delete phantom success; buttons ungated | [A2](A2-assignment-publish-delete-phantom.md) — auth_service.dart:1164-1173, 1200-1209 |
| A3 | Medical leave phantom submit/approve/reject; council/captains see a tab rules deny; no validator/transition guard; hardcoded reviewer | [A3](A3-medical-leave-phantom-role-mismatch.md) — auth_service.dart:6457-6548, admin_claims_screen.dart:113-171 |
| A4 | Honours merit trusts caller GPA, never reads the card; `is_merit_claimed` write is admin-only so the flag never persists → daily replay once D4 ships | [A4](A4-honours-merit-client-gpa.md) — auth_service.dart:1576, 1611-1617 |

## Low (3)

| ID | Finding | Key evidence |
|----|---------|--------------|
| A5 | Timetable clear/CBSE-populate phantom; all timetable edit buttons ungated; hardcoded demo teachers | [A5](A5-timetable-phantom-ungated.md) — auth_service.dart:794-806, 879-893 |
| A6 | `faculty_advisor`/`teacher_lead` admitted client-side but not in rules; attendance-mark denial throws unhandled | [A6](A6-role-mismatch-attendance-throw.md) — hierarchy_service.dart:21-38 vs firestore.rules:248-254 |
| A7 | Hardcoded `2310910`/`Mohammed Ayaan` leave fallback; timestamp leave IDs; attendance validator gaps; approval doesn't excuse attendance; stream fallbacks miss async errors | [A7](A7-identity-fallbacks-data-hygiene.md) — academics_screen.dart:6927-6929, auth_service.dart:6440 |

## What is already solid (do not break)

- **Assignment submissions** — owner create/update restricted to `pending`/`submitted`, graded submissions owner-immutable, council/admin grading with field whitelist (firestore.rules:741-756, 794-809; the R-2/R-5/N-2 protections verified in gamification round 6).
- **Exam publishing** — `publishExamScheduleRange` rethrows on failure (auth_service.dart:1398) and the UI gate matches rules (:2683).
- **Report-card publishing** — `publishStudentReportCard` rethrows (:1685), gated UI (:4354). (The *read* side is A1; the write side is correct.)
- **Timetable single-period save/delete** — truthful `false` on denial (:686-780), UI shows the error.
- **Attendance & medical-leave reads** — owner-or-admin scoping in rules (:769-772, :1002).
- **Photo pickers** — both exam and certificate pickers compress (`imageQuality: 80, maxWidth: 1200`), keeping base64 payloads reasonable.
- **Grading gate** — `canGradeAcademics` (staff + council, no plain students) enforced at the UI and matched by rules.

## Companion documents

- [REMEDIATION_ROADMAP.md](REMEDIATION_ROADMAP.md) — prioritized P0/P1/P2 plan, split into no-Blaze work (now) and Blaze work (deferred to `election_audit/BLAZE_REQUIRED_FEATURES.md` D5).
- [../election_audit/BLAZE_REQUIRED_FEATURES.md](../election_audit/BLAZE_REQUIRED_FEATURES.md) — D5: academics server authority (atomic merit claim, leave→attendance automation, live smoke).
- Pattern references: [../gamification_audit/README.md](../gamification_audit/README.md) (G1 phantom-success cure), [../election_audit/README.md](../election_audit/README.md) (audit format).