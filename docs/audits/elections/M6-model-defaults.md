# M6 — Dangerous model defaults

- **Severity:** Medium
- **Area:** Models / parsing
- **Evidence:** `lib/models/election_ballot.dart`, `lib/models/digital_ballot_cast.dart`, `lib/models/election_gazette.dart`

## Problem

Models default missing fields to permissive values: `isVerified: true`, Grade 11, house `ruby`, scope `All`; `parseDate` falls back to `now`; `scholarNo` falls back to the doc `id`; `isOpen` is computed from the **device clock**; `certified_at` mixes ISO strings and `serverTimestamp` values, breaking ordering.

## What breaks

A malformed or partial doc becomes a verified, open, all-houses ballot; a missing date becomes "now" (evergreen, see M1); a missing scholar number becomes the doc id (wrong identity); a user with a wrong device clock sees open/closed incorrectly; gazette ordering is inconsistent.

## Solution

1. No permissive defaults: missing required fields → parse failure → skip the doc (M2) or show "incomplete record". `isVerified` defaults **false**.
2. `parseDate` returns `null` on missing/invalid; callers decide (closed, not "now").
3. Never substitute `id` for `scholarNo`.
4. Compute open/closed from server timestamps with a skew allowance, or have the callable return `status` authoritatively.
5. Store all timestamps as `serverTimestamp` (one type); migrate ISO-string fields.