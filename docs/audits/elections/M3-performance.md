# M3 — Performance: N+1 reads and stream resubscription per keystroke

- **Severity:** Medium
- **Area:** Performance / cost
- **Evidence:** `lib/screens/school_elections_page.dart:222-233` (sequential participation reads), `lib/screens/election_chamber_screen.dart:113` (`getElectionsStream()` in build), gazette/audit screens (StreamBuilders recreated per build)

## Problem

`load()` reads participation docs **sequentially, one per poll** (N+1 round trips). The chamber calls `getElectionsStream()` inside `build()` → a new stream subscription on every rebuild, including every search keystroke. Gazette/audit screens recreate their StreamBuilders per build.

## What breaks

Slow page loads that scale with poll count; wasted Firestore reads (cost); search typing stutters and resubscribes listeners repeatedly; stream state (loading/error) resets constantly.

## Solution

1. Batch participation checks: `Future.wait` on the client, or better a single callable `getMyParticipation(pollIds)` returning a map (also fixes C7's enumerable keys).
2. Create streams once in `initState` (or memoize by query) and pass them to `StreamBuilder`; rebuild only the filtered list on keystrokes, not the subscription.
3. Same treatment for gazette/audit streams.