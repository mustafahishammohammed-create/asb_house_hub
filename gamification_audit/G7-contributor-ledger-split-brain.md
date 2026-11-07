# G7. Contributor ledger split-brain — two doc-ID schemes, missing records

**Severity:** HIGH

## Problem

The same `house_contributors` collection is written with **two incompatible document ID schemes**:

- Scheme A — `{house}_{scholarNo}`: `awardVerifiedGamificationPoints` ([auth_service.dart:3990-3992](../lib/services/auth_service.dart)). Worse, this path **only updates if the doc already exists** (:4011 `if (contSnap.exists)`) — it never creates contributor records, so challenge points never appear in the ledger at all.
- Scheme B — `{scholarNo}`: `approveClaim` (:3461-3463), `recordStudentConduct` (:3823-3824), Blitz quiz ([house_arena_screen.dart:521-524](../lib/screens/house_arena_screen.dart)).

The leaderboard streams by `house_name` field (`getHouseContributorsStream`, :4060-4069), so scheme-A docs (if ever created) and scheme-B docs interleave; a student could appear twice under different IDs, or not at all.

## What breaks

1. Challenge/assignment points never create contributor docs → the leaderboard silently omits the most common award type.
2. If both schemes ever write for the same student, the leaderboard double-lists them and totals disagree with `house_points`.
3. `users.points_contributed` (a third ledger, updated by claims/conduct/quiz) diverges from both — three sources of truth, zero reconciliation.

## Solution

**Interim (no Blaze):**
1. Pick one scheme — `{scholarNo}` (matches the majority and the rules' doc naming) — and migrate `awardVerifiedGamificationPoints` to it, creating the doc when absent (same shape as `approveClaim` :3490-3500).
2. Stop maintaining parallel totals: `users.points_contributed` should be derived from the contributor doc, not incremented independently (or dropped until the server owns it).
3. One-time migration: merge any existing `{house}_{scholar}` docs into `{scholar}` docs.

**End state (Blaze):** the callable writes a single contributor doc per scholar atomically with the house total; `users.points_contributed` becomes a read-model projection.

## Done when

- Every award path writes the same doc ID and creates it when missing.
- Leaderboard totals equal the sum of contributor docs, which equals `house_points` total (reconciliation test).