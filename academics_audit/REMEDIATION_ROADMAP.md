# Academics Remediation Roadmap

Prioritized plan for A1–A7. **P0/P1/P2 are all no-Blaze** (client + rules + tests, deployable on Spark). Server-authority items are deferred to `election_audit/BLAZE_REQUIRED_FEATURES.md` **D5**.

Audit baseline: HEAD `91114ea`, 2026-11-08. Read-only audit — nothing here is implemented yet.

---

## P0 — Privacy & medical-data integrity (do first)

| # | Item | Finding | Change | Verify |
|---|------|---------|--------|--------|
| P0-1 | Lock report-card reads to owner + admin | A1 | firestore.rules:764-767 → `isAdmin() \|\| isScholarOwner(resource.data.scholar_no)`; add stream `.handleError` fallback | Rules-contract test; student denied on peer's card, own card loads; deploy + re-deploy shows "already up to date" |
| P0-2 | Medical leaves: truthful writes + real errors | A3 | Remove `catch (_) {}` in submit/approve/reject (auth_service.dart:6457,6481,6523); cache after ack; UI checks results; `.handleError` on the stream | Denial test → `false`, cache unchanged; error snackbar visible |
| P0-3 | Hide Medical Reports from non-staff | A3 | Gate the tab on `isTeacherOrFaculty \|\| isSuperAdmin` (not broad `HierarchyService.isAdmin`) | Council/captain account sees only Point Claims |
| P0-4 | Medical-leave rules validator + transition guard | A3 | `isValidMedicalLeave` on create (whitelist, size caps, date sanity); update only `pending → approved/rejected`, core fields immutable | Rules-contract tests |
| P0-5 | Real reviewer identity | A3 | Pass actual reviewer name/scholar no from admin_claims_screen instead of `'School Administration'` | Approved doc carries the reviewer |

## P1 — Phantom-success eradication & gate alignment

| # | Item | Finding | Change | Verify |
|---|------|---------|--------|--------|
| P1-1 | Assignment publish/delete truthful + gated | A2 | Return `false` on live denial, cache after ack, UI checks result; gate buttons to staff | Denial tests; student sees no Publish/Delete |
| P1-2 | Timetable bulk ops truthful + tab gated | A5 | Same treatment for clear/populate; gate all timetable mutation UI to staff; label CBSE template | Denial tests; student read-only timetable |
| P1-3 | Align faculty role lists | A6 | Decide `faculty_advisor`/`teacher_lead`: add to rules `isAdmin()` **or** remove from client; contract test keeps lists equal | Test asserts client list == rules list |
| P1-4 | Attendance dialog error handling | A6 | try/catch around Save; visible error, dialog stays open on failure | Denial → error snackbar, nothing saved |
| P1-5 | Honours claim interim hardening | A4 | Read the card doc server-side for GPA/ownership (ignore caller `gpa`); stop the doomed `is_merit_claimed` client write; derive claimed state from the award ledger; truthful fail-closed messaging | Claim uses doc GPA; no cache-only claimed state |
| P1-6 | Stop fabricating official report cards | A8 | Block invalid numeric input (no 90.0/98.0 fallbacks); per-subject entry or clearly-labeled template; remove hardcoded principalRemarks/status/section values; drop demo scholar prefill | No invented scores/endorsements on published cards |

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