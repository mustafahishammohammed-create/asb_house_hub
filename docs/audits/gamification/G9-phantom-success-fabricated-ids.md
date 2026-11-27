# G9. Phantom success paths and fabricated IDs around awards

**Severity:** MEDIUM

## Problem

Failure paths fabricate success across the points module (election C5 pattern):

- `submitHouseClaim` — [auth_service.dart:3380-3387](../lib/services/auth_service.dart): when the Firestore write throws, the catch invents `claim_<timestamp>` and **returns it as the claim ID**. The caller believes a claim exists; nothing was persisted.
- `awardMatchMvp` — :5698-5716: on any error (including rules denial), the "offline / unit test fallback" updates local stats and **returns true**.
- `awardPlayerAccoladeCustom` — :5965 `catch (_) {}` then local cache updates and success; the tournament screen then shows "Awarded … (+25 PTS)!" unconditionally ([sports_tournament_screen.dart:1257-1262](../lib/screens/sports_tournament_screen.dart)).
- Merit claim announcement — [academics_screen.dart:4261-4268](../lib/screens/academics_screen.dart): the accessibility announcement "Claimed 50 House Points…" fires **before** checking `success`.
- Blitz confetti — [house_arena_screen.dart:497](../lib/screens/house_arena_screen.dart): fires before the write, regardless of outcome.

## What breaks

1. Students see confirmations for awards/claims that never reached the server — support burden and distrust when standings don't match.
2. A fabricated claim ID can be referenced later (status checks, retries) and will never resolve.
3. Offline fallbacks are indistinguishable from live success in the return values, so callers can't tell demo from real.

## Solution

1. `submitHouseClaim`: on failure return an error/empty ID — never invent one.
2. `awardMatchMvp` / `awardPlayerAccoladeCustom`: in live mode, return false on write failure; reserve cache-only fallback for genuinely offline runs and label the result `demo: true`.
3. Move all success UI (snackbars, announcements, confetti) after a confirmed success result.

## Done when

- No function returns success/ID when the live write failed.
- Every success message is gated on the actual result (code review checklist).