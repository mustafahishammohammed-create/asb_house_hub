# G4. Students self-grade assignments and self-claim academic merits

**Severity:** HIGH

## Problem

**Assignment self-grading:** [academics_screen.dart:2204-2218](../lib/screens/academics_screen.dart) — `_cycleAssignmentStatus` lets any viewer tap an assignment through `pending → submitted → graded` ([academic_assignment.dart:58-67](../lib/models/academic_assignment.dart)). Reaching `graded` mints a score token and awards `pointsReward` (default 20, publisher-supplied) with **no role check anywhere** — not in the UI handler, not in `updateAssignmentStatus` ([auth_service.dart:1041-1053](../lib/services/auth_service.dart)). The status even cycles `graded → pending`, so the same assignment can be re-graded after the local 24h cooldown (or immediately on a wiped/second device).

**Merit self-claim:** `claimReportCardHonoursMerit` ([auth_service.dart:1497-1534](../lib/services/auth_service.dart)) — the honors gate is `if (gpa != null && gpa < 3.80 return false` (:1506). `gpa` is **optional**: passing null skips the check entirely. The GPA itself comes from the client-supplied card model. `pointsReward` defaults to 50 (the ceiling). The server dedup flag `is_merit_claimed` writes to `classes/{level}/report_cards` — admin-only per rules :662-665 — so for students it fails and is swallowed (:1547), leaving only local cache as the re-claim gate.

## What breaks

1. A student taps their homework twice → "graded" → +20 points minted (phantom per G1, but the local ledger and UI treat it as real).
2. A modified client calls `claimReportCardHonoursMerit(gpa: null)` → 50 points per report card, no honors evidence.
3. Teachers' grading authority is meaningless: the student's device decides when work is "graded".
4. Server-side assignment/report-card updates fail silently for students (admin-only rules), so the client's local "graded" state diverges from the server record.

## Solution

**Interim (no Blaze):**
1. Only staff roles may transition to `graded` — check `HierarchyService.canManageElections`-style capability (or a new `canGradeAcademics`) in both the UI handler and `updateAssignmentStatus`; students may only reach `submitted`.
2. Make `gpa` required and validate it against the server report-card document inside the award path; never trust the card model. Until server validation exists, disable the merit-claim button for students (label "verified by staff").
3. Remove the `graded → pending` cycle for students; status transitions belong to the grader.

**End state (Blaze):** grading and merit verification are server actions; points follow server-confirmed grades only.

## Done when

- A student cannot transition any assignment to `graded` (UI + service + rules align).
- Merit claim without a server-verified GPA ≥ 3.80 is impossible.
- Re-grading the same assignment cannot mint points twice (server idempotency).