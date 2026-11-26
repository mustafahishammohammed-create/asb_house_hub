# C4 — The client fallback defeats the server

- **Severity:** Critical
- **Area:** Architecture / server authority
- **Evidence:** `lib/screens/school_elections_page.dart:401-435` (`call`), `:2345` (vote button candidateId), `functions/elections-v2.js:111` (server expects UUID)

## Problem

`call()` uses the `schoolElection` callable only when `FirebaseAuth.currentUser.uid == widget.uid`, with a **1500 ms timeout** (shorter than a typical Functions cold start). **Any** rejection, timeout, or UID mismatch falls through to `_callFirestoreFallback`, which re-implements every action client-side with weaker checks and swallowed errors. Because rules allow direct writes (C1), the weaker path succeeds.

A second bug makes fallback the *default* for v2 votes: the Vote button sends `candScholar.isNotEmpty ? candScholar : candId` as `candidateId`, but the server matches against the candidate **UUID** (`c.id`). Every roster candidate has a scholar number → the server rejects → the fallback votes. The secure path is effectively never exercised for normal candidates.

## What breaks

- Server validation (eligibility, windows, duplicate votes, candidate freezes) is unenforceable: make the callable fail or reject and the client does the insecure version.
- Normal v2 votes always run through the fallback, inheriting every fallback fault (C5, C8, C9, H2–H4).
- Offline/slow users silently get a different, weaker election system than online users.

## Solution

1. **Delete `_callFirestoreFallback` entirely.** On callable failure, surface the error ("Could not reach the election server. Try again.") — never re-implement authority client-side. If offline support is needed, queue the *request* and replay it against the callable; never fabricate results.
2. Fix the Vote button to always send the candidate UUID: `args['candidateId'] = candId` (the `cnd_...` id), never the scholar number.
3. Raise the callable timeout to ≥10 s (or use the SDK default of 70 s) and remove the UID-mismatch shortcut — after H1 is fixed, cached uid and auth uid always agree; if they don't, block the action and force re-auth.
4. Add a widget/integration test asserting that a callable rejection shows an error and writes nothing to Firestore.