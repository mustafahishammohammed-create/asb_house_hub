# A3. Medical leave: phantom submit/approve/reject + role mismatch + no validation

**Severity:** MEDIUM

## Problem

Three compounding issues in the medical-leave flow:

**1. Phantom success on all three writes** (same G1 pattern):
- `submitMedicalLeaveRequest` — [auth_service.dart:6457-6464](../lib/services/auth_service.dart): Firestore `set` inside `catch (_) {}`, then cache write, then `return true` unconditionally.
- `approveMedicalLeave` — :6474-6506: `update` inside `catch (_) {}` (:6481), cache flipped to `approved`, `return true`.
- `rejectMedicalLeave` — :6516-6548: identical shape (:6523).
- Callers never check the result: student submit snackbar fires unconditionally ([academics_screen.dart:6944-6952](../lib/screens/academics_screen.dart)); admin-screen handlers show success snackbars because the service never throws ([admin_claims_screen.dart:113-171](../lib/screens/admin_claims_screen.dart)).

**2. Reviewer role mismatch — council/captains see a tab they cannot use:**
- The Medical Reports tab lives in `AdminClaimsScreen`, reachable by anyone passing `HierarchyService.isAdmin` ([home_screen.dart:1268,1632-1638](../lib/screens/home_screen.dart)) — which includes **captains, council and prefects**.
- But rules allow `medical_leaves` read/update only for `isAdmin()` = teacher/faculty/principal/staff ([firestore.rules:1001-1008](../firestore.rules)).
- Result: a council officer opens Medical Reports → the unfiltered query ([auth_service.dart:6410](../lib/services/auth_service.dart)) is denied → the snapshot stream errors (the `try/catch` at :6409-6424 only catches synchronous errors, so the cache fallback never engages for stream errors) → they see cached/empty data; they tap Approve → rules deny → swallowed → **"Approved Medical Leave!" snackbar while the server still says pending**. Split-brain with real medical consequences.
- `reviewerName` is hardcoded `'School Administration'` ([admin_claims_screen.dart:119,149](../lib/screens/admin_claims_screen.dart)) — even successful approvals carry no real reviewer identity.

**3. No create validator, no transition guard:**
- `medical_leaves` create checks only ownership + `status == 'pending'` ([firestore.rules:1003-1005](../firestore.rules)) — no field whitelist, no size caps (the base64 certificate photo is bounded only by the client's picker compression, [academics_screen.dart:6884-6885](../lib/screens/academics_screen.dart)), no date sanity.
- Update is a blanket `isAdmin()` — an admin can flip `approved → pending → approved`, rewrite `scholar_no`, or replace the photo; no `pending → approved/rejected` transition lock, no immutable reviewer fields.
- The doc comment on `approveMedicalLeave` claimed it creates "excused attendance entries" ([auth_service.dart:6467](../lib/services/auth_service.dart)) — **the code does not, and per school policy it must not**: a scholar with a submitted or approved leave is still marked **absent** (user-confirmed 2026-11-08). The leave is documentation for administration, not an attendance override. The comment has been corrected; no automation is wanted.

## What breaks

1. Students believe a leave was submitted when the write was denied (e.g. profile-cache miss → fallback scholar number `2310910` fails ownership, see A7) — they stay home believing they're covered.
2. Council/captain devices show leaves as approved/rejected while the server still shows pending; administration never sees the decision. Medical-attendance decisions silently diverge.
3. No accountability: every approval says "School Administration", never the actual reviewer.
4. Unbounded document shape on create; review decisions are reversible and unaudited.

## Solution

**No Blaze required:**

1. Truthful writes: remove the three `catch (_) {}` swallows; return `false`/rethrow on live denial; write cache only after acknowledgment; check results in both UIs and show real errors.
2. Fix the stream fallback: attach `.handleError` to `getMedicalLeavesStream` so a denied query falls back to cache (or an empty state) instead of an unhandled stream error.
3. Resolve the role mismatch — **recommended: keep medical data admin-only** (it is health data, unlike house-point claims) and hide the Medical Reports tab for non-staff: gate the tab on `isTeacherOrFaculty || isSuperAdmin`, not the broad `HierarchyService.isAdmin`. If the school later wants council review, that is an explicit rules + privacy decision, not a default.
4. Pass the real reviewer's name/scholar number into `approveMedicalLeave`/`rejectMedicalLeave` instead of the hardcoded string.
5. Rules hardening: add `isValidMedicalLeave(data)` (field whitelist mirroring the model, string length caps, photo size cap well under the 1 MiB doc limit, `start_date <= end_date`, status enum) on create; split update so `status` may only move `pending → approved/rejected` and `scholar_no`/dates/photo are immutable after creation.
6. Tests: denial → `false` + no cache mutation; council account sees no Medical Reports tab; rules-contract tests for the validator and transition guard.

**Policy note (user-confirmed 2026-11-08):** approved leave does **not** excuse attendance — the scholar remains marked absent. Do not build leave-to-attendance automation; the only fix is keeping comments/UI honest about that.

## Done when

- Denied submit/approve/reject shows an error and changes no cache; success only after server acknowledgment.
- Only staff see Medical Reports; approvals record the actual reviewer.
- Create rejects malformed/oversized docs; updates cannot reopen or rewrite a decided leave.