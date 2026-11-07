# M2 — One malformed document kills whole lists (and is a cheap DoS)

- **Severity:** Medium
- **Area:** Parsing robustness
- **Evidence:** `lib/screens/school_elections_page.dart:358-388` (gazette/legacy-certified lists), `:307` (`as Timestamp?` sort cast), `lib/models/election_gazette.dart` (`as num?`), `lib/models/election_audit_record.dart` (`(v as num).toInt()`)

## Problem

List parsing has no per-document error boundary: one bad doc throws and the **entire** gazette/certified list is dropped. Hard casts (`as Timestamp?`, `as num?`, `(v as num).toInt()`) crash on strings/missing fields. Streams that error fall back to cache silently, showing stale data forever.

## What breaks

A single malformed doc — accidental or deliberate, since anyone can write these collections (C1) — blanks the gazette or crashes the elections page for every user. A cheap denial of service.

## Solution

1. Wrap each document's parsing in try/catch; skip (and log) the bad doc, keep the rest.
2. Replace hard casts with safe parsing: `v is Timestamp ? v : null`, `num.tryParse(v.toString())`, etc.
3. Surface stream errors with a retry banner instead of silently showing cache.
4. Fuzz test: feed each model a doc with wrong-typed fields → no throw, sensible defaults or skip.