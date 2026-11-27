# G5. Blitz quiz is fully client-authoritative with unlimited replays

**Severity:** HIGH

## Problem

[house_arena_screen.dart](../lib/screens/house_arena_screen.dart):

- Quiz bank with **correct answers hardcoded client-side** (:190-228, five questions with `'correct': <index>`).
- Score computed on device: 20 × streak multiplier up to 2.0 (:465-472) — max ~155 per run, **no ceiling check**.
- On finish, the client directly batch-writes `house_points` (+score), `users.points_contributed` (+score), `house_contributors` (+score, +merits) (:500-533).
- **No token, no cooldown, no throttle, no GamificationSecurityService involvement at all** — unlike the assignment/merit paths.
- `batch.commit().catchError((_) {})` (:535) swallows denial; confetti fires before the write (:497).

## What breaks

1. Answers ship in the binary → perfect score every run, zero effort.
2. Unlimited replays: finish, restart, finish again — each run attempts another award. For students every write is denied (phantom, G1); for an admin/sports leader playing, **every run really inflates** their house with no daily limit.
3. A modified client writes any `_blitzScore` (e.g. 999999) — subject only to the unvalidated `house_points` rule (G3).
4. The quiz bypasses even the weak local cooldowns that other award paths have — it's the least-guarded points entry in the app.

## Solution

**Interim (no Blaze):**
1. Route the quiz through `awardVerifiedGamificationPoints` (activity `blitz_quiz`, ceiling 50) instead of direct batch writes — at least gains token, cooldown, throttle, and truthful failure (after G1 fix).
2. Apply the 24h activity cooldown to the quiz; clamp score to the ceiling.
3. Move the answer key out of the client (server-held question set) — until then, treat quiz points as demo-only and don't write standings.

**End state (Blaze):** `schoolGamification` callable serves questions, validates answers server-side, computes the score, and awards atomically with a daily limit.

## Done when

- No direct `house_points`/`users`/`house_contributors` writes remain in the arena screen.
- Quiz awards respect the same ceiling + cooldown as every other activity.
- Replaying the quiz within 24h awards nothing (server-enforced).