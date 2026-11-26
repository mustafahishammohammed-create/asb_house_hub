# H2 — Eligibility rests on self-asserted or fabricated data

- **Severity:** High
- **Area:** Eligibility / roster integrity
- **Evidence:** `lib/screens/signup_screen.dart` (self-selected house/grade), `lib/screens/school_elections_page.dart:452-460` (fallback grade 10), `:122-397` (synthesized members), `lib/services/auth_service.dart:2792-2874` (`ensureSchoolMemberRecord` defaults), `functions/elections-v2.js:44-54` (`eligible`), `:107-108` vs client key (lowercase mismatch)

## Problem

- Signup lets users **self-select house and grade**; the roster is client-writable (C1) → the server's `eligible()` trusts data the voter controls.
- The fallback identity hardcodes **grade 10**; `load()` synthesizes grade-10 members and a fake grade-12 admin; `ensureSchoolMemberRecord` defaults grade 10 and promotes staff to `role: 'admin'` with `manage_elections`.
- Fallback house comparison is **case-sensitive** (`'Ruby'` ≠ `'ruby'` → wrongly blocked).
- **Key-normalization mismatch:** the client lowercases the participation key, the server does not → for non-numeric scholar IDs (`TEA-101`, `SCH-…`) one voter gets two keys → vote once via the server, again via the fallback.

## What breaks

Grade/house-restricted elections can be entered by anyone who edits their roster doc or signs up with a different house/grade; legitimate voters can be blocked by a case mismatch; duplicate-vote protection fails for staff-style scholar IDs; fabricated grades make eligibility meaningless in the fallback path.

## Solution

1. Make the roster authoritative: import it from school records (Admin SDK / secure callable); signup **reads** house/grade from the roster instead of asking the user; `school_members` writes locked (C1).
2. Delete every grade default (10/11/12) — missing grade = ineligible, with a "profile incomplete" message.
3. Normalize identifiers in one shared place: `scholarNo.trim().toLowerCase()` for all keys and comparisons, client and server; house comparisons case-insensitive.
4. Add server tests: uppercase/lowercase scholar produce the same participation key; wrong-case house still matches.