# G12 — Election Certification Double-Counts Points in the Local Cache (MEDIUM)

**Status:** OPEN — found during the final cross-module sweep, verified at `f20c7f7` (2026-11-07).

## Problem

`certifyElectionAndAwardPoints` ([auth_service.dart:4998-5236](../lib/services/auth_service.dart)) has three exit paths, and the live path falls through into demo-era cache code:

1. **Live path** (:5037-5066): calls the `schoolElection` callable with `action: 'certify'`. On server error it returns failure truthfully. **On server success there is no early return.**
2. Execution continues past the demo-only transaction (`if (!_isFirebaseLive)` :5073, skipped when live) into:
   - :5126 `await incrementCachedHousePoints(hName, housePoints);`
   - :5128-5131 inserts the **client-built** `CertifiedElectionResult` into the gazette cache.
   - :5156-5163 a direct `election_polls_v2` set that rules deny for non-admin commissioners in live mode — swallowed by `catch (_) {}` (dead write).
3. The catch-block fallback (:5180-5234) repeats the same cache increment at :5202 for the demo path.

## What breaks

- **Cache double-count:** once the callable is deployed (Blaze D1), the server awards points in Firestore **and** the client increments its local cache by the client-assumed `housePoints` (default 50). Standings read from cache show server + 50 until the next full server sync.
- **Amount drift:** the client caches its own `housePoints` parameter, never the amount the server actually awarded. If the server logic awards a different value, the cache is wrong by the difference.
- **Gazette cache fabrication:** the cached proclamation is the client's object, not the server's certified record.
- **Demo inconsistency (cosmetic):** the offline fallback in [school_elections_page.dart:1240,1297-1305](../lib/screens/school_elections_page.dart) awards **+100** while the service default is **+50**; :1305 also increments the cache even when the Firestore set at :1299-1304 was denied and swallowed (phantom pattern, demo-only path).

This is a display/cache-integrity bug, not a server exploit — the server ledger remains authoritative. It is the election-side twin of G10.

## Solution

1. On live callable success, **return early** with the server's result (parse the callable response, or read back the `election_gazettes` / `house_points` docs). Never run `incrementCachedHousePoints` on the live path.
2. Gate the direct `election_polls_v2` write and all cache writes to the demo path only.
3. Unify the demo award amount (one constant shared by service and page fallback).
4. In the demo fallback, increment the cache only after the write succeeds (or label demo state explicitly).

## Done when

- Live certify (post-Blaze smoke test): local cached standings equal server standings exactly; gazette cache matches the server record.
- Demo certify: exactly one cache increment; one shared award constant.
- Regression test covers both paths; `flutter analyze` 0 errors.