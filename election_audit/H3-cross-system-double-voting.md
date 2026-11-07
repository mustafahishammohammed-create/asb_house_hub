# H3 — Cross-system double voting and split tallies

- **Severity:** High
- **Area:** Legacy/v2 coexistence
- **Evidence:** `lib/services/auth_service.dart:4375-4642` (`castDigitalVote` locks), `lib/screens/school_elections_page.dart:563-686` (fallback transaction, dual counts keys), `functions/elections-v2.js:107-136` (server participation/counts)

## Problem

Mirrored polls exist in **both** systems. The chamber path locks `election_votes/{ballotId}_{HMAC}`; the v2 page locks `participation/{sha256}`. Neither checks the other's lock for mirrored polls. The fallback also increments counts under **both** `candId` and `scholarNo` keys, while the server certify reads only `candId`.

## What breaks

- One person votes in the chamber **and** in the v2 page → two counted votes, both feeding certification (the client tally max-merges them).
- Chamber/fallback votes (scholar-keyed counts) are invisible to server certification but visible to client certification → two different "official" results for the same poll.

## Solution

1. Pick **one system of record: v2.** Migrate legacy polls into `election_polls_v2` (Admin SDK script), then make legacy collections read-only history (rules `write: if false`, C1) and remove legacy voting from the chamber.
2. Single participation lock per (poll, voter), checked only by the callable; single counts key (`candId` UUID) incremented only inside the server transaction.
3. Until migration completes, have the callable's vote action check **both** locks for mirrored polls and write both atomically — a temporary bridge, deleted after migration.
4. Test: vote via chamber then via v2 page for the same mirrored poll → second attempt rejected.