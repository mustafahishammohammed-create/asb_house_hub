# G6. Rate limits are local-only; device clock rollback bypasses cooldowns

**Severity:** HIGH

## Problem

[gamification_security_service.dart](../lib/services/gamification_security_service.dart):

- 24h cooldown (:275-321) and 60s throttle (:324-368) are stored in **SharedPreferences + an in-memory map** — per device, per install, user-editable.
- Both checks use `DateTime.now()` (:291, :339) and contain the same logic flaw: `if (elapsed < window && !elapsed.isNegative)` (:295, :343). **Rolling the device clock back** makes `elapsed` negative → the guard is skipped → `allowed: true`.
- The token sliding window (:234-248) also trusts the device clock: roll forward to expire cooldowns, roll back to keep old tokens "fresh".
- On Windows, SharedPreferences is a plaintext JSON file on disk — cooldown keys (`gamification_cd_*`, `gamification_throttle_*`) can be deleted directly.

## What breaks

1. Clear app data / edit the prefs file / use a second device → all cooldowns reset → unlimited daily-challenge awards.
2. Set clock back one hour → every cooldown and throttle reports "allowed" even mid-window.
3. Set clock forward → 24h cooldowns expire instantly; token timestamps can be pre-dated to stay inside the 5-minute window.
4. None of these limits exist server-side, so nothing reconciles the abuse.

## Solution

**Interim (no Blaze):**
1. Fix the negative-elapsed logic: a negative elapsed time must **fail closed** (treat as not allowed), not skip the check.
2. Persist a monotonic high-water mark: if `now < lastCompletion`, reject rather than allow.
3. Accept that local limits are UX hints only — document that real enforcement is server-side (Blaze).

**End state (Blaze):** cooldowns/throttles stored in Firestore per scholar+activity, checked inside the award transaction using server timestamps; device clock irrelevant.

## Done when

- Clock rollback produces "not allowed", never "allowed" (unit test with injected `now`).
- Server-side cooldown exists and is authoritative (Blaze phase).