# G1. Student points economy is phantom — denied writes reported as success

**Severity:** CRITICAL

## Problem

Every student-facing points path writes to collections that Firestore rules deny for students, then swallows the error and reports success:

- `awardVerifiedGamificationPoints` — [auth_service.dart:3984-4027](../lib/services/auth_service.dart): increments local cache **before** the Firestore transaction (:3984-3985), the transaction writes `house_points` + `house_contributors` (:3989-4020), `catch (_) {}` (:4021) swallows the rules denial, and the function returns `success: true, pointsAwarded: points` (:4023-4027).
- Rules: `house_points` write requires `isAdmin() || isSportsLead()` ([firestore.rules:820-823](../firestore.rules)); `house_contributors` write requires `isAdmin()` (:825-828). A plain student is neither.
- Blitz quiz — [house_arena_screen.dart:500-535](../lib/screens/house_arena_screen.dart): batch-writes `house_points`, `users.points_contributed` (immutable for owners per rules :619), and `house_contributors`; `await batch.commit().catchError((_) {})` (:535) swallows the denial; confetti fires before the write (:497).
- Assignment grading — [auth_service.dart:1041-1053](../lib/services/auth_service.dart) and report-card merit — :1521-1534: both call the same phantom award path.

## What breaks

1. A student completes a quiz / assignment / merit claim → UI shows points awarded, confetti, "+20 Pts" → **server standings never change**. The entire student points economy is fake; every device shows different (locally inflated) numbers.
2. Local caches (`cached_house_standings_map`, `cached_student_contribution_*`) are permanently inflated and never reconciled, because the server write that should have been the source of truth never happened.
3. Admin devices show real standings; student devices show fabricated ones — split-brain across the school.
4. This is the election audit's C5 (phantom success) pattern repeated in the points economy.

## Solution

**Interim (no Blaze):**
1. Make failure truthful: `awardVerifiedGamificationPoints` must return `success: false` when the Firestore transaction fails in live mode (delete the blanket `catch (_) {}`; only fall back offline when Firebase is genuinely unavailable, and label it demo).
2. Do not increment local caches before server acknowledgment — move cache writes after a successful transaction, or reconcile from the server stream.
3. Blitz quiz: check `batch.commit()` result; on denial show "Score recorded locally — pending server verification" instead of confetti-as-success.
4. Gate student point-earning UI as "demo/offline" until the server callable exists, so nobody believes fake standings.

**End state (Blaze):** a `schoolGamification` callable owns all awards: server-side activity validation, server cooldowns, atomic `FieldValue.increment`, idempotency keys, audit log. Rules keep direct writes locked. See REMEDIATION_ROADMAP.md.

## Done when

- A student award attempt against live Firestore returns failure (or a truthful pending state), never `success: true` with zero server effect.
- Local standings/contribution caches are only written from server-confirmed data.
- Test: simulate rules denial → function returns failure, cache unchanged.