# C8 — Certification is wrong in every client path

- **Severity:** Critical
- **Area:** Results / rewards integrity
- **Evidence:** `lib/screens/school_elections_page.dart:1068-1279` (v2 fallback certify), `:1154-1185` (tie), `:1160-1161` (winner house), `:1210-1245` (zero-vote), `:2480-2509` (synthesized proclamations), `lib/screens/election_chamber_screen.dart:1755-1819`, `lib/services/auth_service.dart:4795-4983` (`certifyElectionAndAwardPoints`), `:433-438` (local-only points), `functions/elections-v2.js:160-179` (correct server certify)

## Problem

- **No closing-time check** in either client path → certify while voting is open ("End Voting & Certify Winner" button is live during Open).
- **Ties proclaim `leaders.first`**; zero-vote elections compute a winner with `maxV = -1` and fabricate the margin.
- **Winner house = the poll's scope, defaulting `'ruby'`** → every universal (all-house) election awards Ruby +100 regardless of who actually won.
- Tally = `max(counts/{candId}, counts/{scholarNo}, votes_count)` — all client-writable (C1) → pump whichever key you like.
- Transaction failure is swallowed and the poll is **marked certified anyway**.
- Chamber `certifyElectionAndAwardPoints`: on transaction failure the catch performs **direct non-transactional overwrites** of gazette/elections/v2 and **re-awards points**, returning success → repeat-certify rewrites the official record and double-awards.
- v2 house points are **local-cache-only** (`incrementCachedHousePoints`) — other devices never see them.
- The build method synthesizes proclamations for legacy certified polls without a gazette (zero-vote winners, margin `maxV>0?maxV:1`, +100).

The **server** certify handles ties/no-votes correctly and refuses early closure — but issues no gazette, points, or roles, so the client fills the gap with the broken logic above.

## What breaks

Winners can be declared early, from ties, from zero votes, for the wrong house, from inflated client-writable tallies, and repeatedly — each repeat re-awarding points and overwriting the gazette. The "official" result differs between devices and between client and server.

## Solution

1. **Certify server-side only.** Extend the callable's `certify` action to transactionally: close the poll, compute the tally from the single `counts/{candId}` source, handle tie → `status: 'tied'` (no winner, runoff required), zero votes → `status: 'no_votes'`, write the gazette, and award house points from the **winning candidate's roster house**. Return the full proclamation; the client only renders it.
2. Delete all client-side certify/tally/proclamation code, including the synthesized legacy proclamations and `certifyElectionAndAwardPoints`'s catch-and-overwrite.
3. Remove `incrementCachedHousePoints` as a source of truth — points come from the server `house_points` doc.
4. Disable the Certify button until `closesAt` has passed (server enforces regardless).
5. Tests: tie → no winner; zero votes → no winner; universal poll → points go to the winner's house; second certify call → rejected, no double award.