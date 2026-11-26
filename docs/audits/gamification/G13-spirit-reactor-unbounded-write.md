# G13 — Spirit Reactor: Unbounded, Spoofable, Last-Write-Wins (LOW)

**Status:** OPEN — found during the final cross-module sweep, verified at `f20c7f7` (2026-11-07).

**Scope note:** the spirit reactor is a cosmetic arena meter. It does **not** write `house_points` and does not affect the leaderboard. Included because the sweep covered every arena write path.

## Problem

- **Client** ([house_arena_screen.dart:361-374](../lib/screens/house_arena_screen.dart)): every 5 taps, the app writes **absolute values for all four houses** plus a free-text `last_contributor` to `system_config/house_spirit_reactor`.
- **Rules** ([firestore.rules:844-853](../firestore.rules)): any signed-in user may create/update that doc, gated only by `isValidSpiritReactor` (:523-531), which checks the field whitelist and types — **no numeric bounds**. The schema comment at :140-143 claims `number (>= 0)`, but the validator never enforces it. `last_contributor` is any string ≤ 100 chars, not tied to the caller.

## What breaks

- Any student can set a rival house's spirit to a negative or astronomically large number, or zero out their own house's rivals — trivial griefing via console or a modified client.
- `last_contributor` can impersonate any name.
- Absolute-value writes are last-write-wins: concurrent taps from two students overwrite each other, so taps are silently lost.

## Solution

1. Rules: enforce `>= 0` and a sane upper cap on each house value; require `last_contributor` to match the caller's scholar number (or drop the field).
2. Client: send `FieldValue.increment(tapDelta)` for the caller's house only, instead of absolute values for all four houses — atomic increments eliminate the lost-update race.
3. Optional (Blaze): aggregate taps server-side from per-user tap docs if the meter ever becomes competitive.

## Done when

- Rules emulator: negative, over-cap, and spoofed-contributor writes rejected; increments from two users both land.
- No absolute multi-house writes remain in the client.