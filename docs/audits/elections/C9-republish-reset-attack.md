# C9 — Republish / reset attack on live and certified polls

- **Severity:** Critical
- **Area:** Election lifecycle
- **Evidence:** `lib/screens/school_elections_page.dart:940-1066` (fallback publish), `:986` (opens now−2s), `:332-350` (cached drafts resurrected), `:905-938` (deleteDraft/remove without status check), `functions/elections-v2.js:159` (server publish is idempotent), `:207-228` (server publish)

## Problem

The fallback `publish` has **no draft-status check** and uses `pollRef.set` without merge → publishing over a **live or certified** poll resets it (new doc, counts wiped, voting reopened). It also ignores the scheduled start and opens at `now − 2s`. Cached drafts are re-added to the manager list even when the server draft is published → a deleted/published draft resurrects from local cache and can be republished. `deleteDraft` and `remove` likewise skip status checks → candidates can be removed from a published poll. The server has no `deleteDraft` action at all, so those operations *always* run through the fallback.

## What breaks

A manager — or anyone, via C1's direct writes — can reset a running election (erasing votes), reopen a certified one, change the candidate slate mid-vote, or resurrect deleted drafts. Scheduled elections open immediately instead of at their start time.

## Solution

1. Remove fallback publish/deleteDraft/remove (dies with C4). All lifecycle actions go through the callable, which already freezes published candidates and makes publish idempotent.
2. Add server actions: `deleteDraft` (only while `status == 'draft'`), `removeCandidate` (draft only), `close`/`cancel` with authority checks.
3. Client: filter cached drafts against server status — a draft the server says is published/deleted is dropped from cache, never resurrected.
4. Honor `startMs`: server publish keeps the scheduled `opensAt`; voting rejects before it (already does) and the UI shows "Opens at …".
5. Test: publish twice → second is a no-op; publish over a certified poll → rejected; remove candidate from published poll → rejected.