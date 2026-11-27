# A7. Identity fallbacks, collision-prone IDs, and data-hygiene gaps

**Severity:** LOW

## Problem

A cluster of small correctness/hygiene issues, each minor alone:

1. **Hardcoded demo identity in the leave form.** The submit handler falls back to `sNo = '2310910'` and `sName = 'Mohammed Ayaan'` when the profile cache is missing — [academics_screen.dart:6927-6928](../lib/screens/academics_screen.dart). If the cache is cold, the request is submitted under **another scholar's number**: rules `isScholarOwner` denies it (unless the user happens to be 2310910), the denial is swallowed (A3), and the student is told it succeeded. House falls back to `'ruby'` (:6929) the same way.
2. **Timestamp-only leave IDs.** `leaveId = 'med_${now.millisecondsSinceEpoch}'` — [auth_service.dart:6440](../lib/services/auth_service.dart). Two submits in the same millisecond (double-tap, retry) overwrite one another; the ID also carries no owner, so it is guessable/enumerable by anyone who can read the collection (admins).
3. **Attendance validator gaps.** `isValidAttendance` ([firestore.rules:508-522](../firestore.rules)) does not bind `scholar_no` to the `{scholarNo}` path segment — an admin can file scholar X's record under scholar Y's path — and does not validate `date` at all. Admin-only surface, so hygiene rather than exposure.
4. **Misleading "excused attendance" comment.** `approveMedicalLeave`'s doc comment promised "creating excused attendance entries" ([auth_service.dart:6467](../lib/services/auth_service.dart)) but no attendance write exists. Per school policy (user-confirmed 2026-11-08) that omission is **correct**: a scholar with a submitted or approved leave is still marked **absent** — the leave never excuses attendance. The comment was fixed to match policy; no automation is wanted.
5. **Stream fallbacks that don't catch stream errors.** `getMedicalLeavesStream` ([auth_service.dart:6408-6425](../lib/services/auth_service.dart)) and `getReportCardsStream` (:1519-1563) wrap only the synchronous query construction in try/catch; permission errors arrive asynchronously on the stream and bypass the cache fallback. Relevant after A1/A3 rules tightening.

## What breaks

- Cold-cache leave submits silently fail or (worst case, for the actual scholar 2310910) file under a demo identity — wrong data, false success.
- Same-millisecond resubmits destroy the earlier request.
- Attendance records can be misfiled across scholar paths by admins; dates are unvalidated strings/maps.
- The misleading comment could make staff believe an approved leave excuses the absence — policy is the scholar stays absent regardless of leave.

## Solution

**No Blaze required:**

1. Remove the hardcoded identity fallbacks: if `scholarNo`/name/house can't be resolved from the profile, block submission with "Profile not loaded — try again" instead of inventing `2310910`/`Mohammed Ayaan`/`ruby`.
2. Use Firestore auto-IDs (`.doc()`) or `med_${sNo}_${millis}` for leave IDs — collision-free and owner-scoped.
3. Extend `isValidAttendance`: `data.scholar_no == scholarNo` (pass the path segment into the validator) and a `date` type/format check.
4. Keep comments/UI honest about the leave policy: approval never alters attendance; the scholar remains absent (user-confirmed 2026-11-08). No leave-to-attendance automation.
5. Add `.handleError` cache fallbacks to both streams (shared pattern with A1/A3 fixes).

## Done when

- No code path submits academic/medical data under a hardcoded identity; missing profile blocks with a clear message.
- Leave IDs are unique per submit; attendance validator binds scholar to path and checks date.
- Comments/UI match actual behavior; stream denials degrade to cache, not unhandled errors.