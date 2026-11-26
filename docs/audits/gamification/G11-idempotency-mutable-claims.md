# G11. No idempotency on awards; mutable claim points/house on update

**Severity:** MEDIUM

## Problem

- **Trophy double-award:** `awardChampionshipTrophyAndPoints` builds `trophyId = 'trophy_<sport>_<timestamp>'` ([auth_service.dart:5816](../lib/services/auth_service.dart)) — every call is a new doc. A double-tap or retry awards the championship points twice; nothing checks whether this tournament was already awarded.
- **Accolade/MVP replay:** `awardPlayerAccoladeCustom` (:5924) and `awardMatchMvp` (:5639) increment stats on every call with no dedup key.
- **Mutable claim economics:** `house_claims` update rules ([firestore.rules:696-698](../firestore.rules)) lock only `scholar_no`, `activity_title`, `cert_url` — **`points` and `house_name` remain mutable** by any admin before/after approval. `approveClaim` reads the stored values (good), but an admin can edit a pending claim's points to 500 or move it to another house, and the audit trail won't show the original submission.
- `approveClaim` itself is well-built (server-authoritative read, duplicate-approval guard, transaction, rethrow) — the gap is around it.

## What breaks

1. Accidental double-taps inflate standings; retries after timeout do the same.
2. A rogue/compromised admin account can silently rewrite claim economics; the student's original submission is unrecoverable.
3. No idempotency means the future server callable will inherit the same retry hazards unless designed in now.

## Solution

1. Derive award IDs from content, not time: `trophy_<sport>_<tournamentSlug>` (one per tournament), and reject creation when the doc exists.
2. Add `points` and `house_name` to the immutable-fields list on `house_claims` update (admin may change status/reviewer fields only); corrections require reject + resubmit.
3. Accolade/MVP: require a fixture-scoped key (`<fixtureId>_<scholar>`) so re-awarding the same fixture is a no-op.

## Done when

- Repeating any award operation produces exactly one ledger effect (test).
- Rules reject mutation of claim `points`/`house_name` on update.