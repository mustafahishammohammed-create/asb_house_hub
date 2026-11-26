# G3. house_points accepts unbounded writes from student sports leaders

**Severity:** CRITICAL

## Problem

[firestore.rules:820-823](../firestore.rules):

```
match /house_points/{houseId} {
  allow read: if isSignedIn();
  allow write: if isAdmin() || isSportsLead();
}
```

- `isSportsLead()` (:261-267) includes `sports_captain`, `sports_vice_captain`, `sports_lead` — **student roles** appointed via the admin roster.
- The rule has **no content validation whatsoever**: no `isValidHousePoints`, no ceiling, no house-name check, no increment-only constraint. Compare with every other collection, which has a schema validator.
- Client award flows compound this: `awardChampionshipTrophyAndPoints` accepts caller-supplied `pointsAwarded`/`runnerUpPoints` ([auth_service.dart:5793-5794](../lib/services/auth_service.dart), defaults 100/50, no clamp); `awardPlayerAccoladeCustom` accepts arbitrary `meritPoints` (:5934).

## What breaks

1. A student holding a sports-captain role can open the Firebase console/SDK and set `house_points/ruby.total_points = 999999` directly — rules accept it. No client exploit needed.
2. Or use the trophy flow with `pointsAwarded: 999999` — the transaction increments by the caller's number.
3. The house competition — the app's core premise — is decided by whichever sports leader inflates hardest. There is no audit trail distinguishing legitimate awards from arbitrary writes.
4. `house_contributors` (admin-only) and `house_points` (sports-lead) have asymmetric gates, so standings and contributor ledgers can be driven out of sync by a sports lead.

## Solution

**Interim (no Blaze):**
1. Add a rules validator for `house_points`: `house_name` must equal the doc ID (lowercased, one of the four houses), `total_points` int within 0..1,000,000, and on update require the delta to be a sane bounded increment (e.g. `request.resource.data.total_points - resource.data.total_points` between -100 and +500) — sports leads may adjust, not rewrite.
2. Clamp award amounts client-side to documented ceilings (trophy ≤ 100/50, accolade ≤ 50) and reject out-of-range inputs.
3. Consider removing `isSportsLead()` from `house_points` writes entirely until the callable exists (admin-only), since sports leaders are students.

**End state (Blaze):** only the server callable writes `house_points`; all client writes locked (`write: if false`), with an append-only award audit log.

## Done when

- Rules reject a sports-lead write setting an arbitrary total or an out-of-bound delta (rules unit test).
- No client path can award more than the documented ceiling.
- Every server-side award produces an audit record.