# L3 — Phantom ballots in the legacy create path

- **Severity:** Low (same pattern as C5, smaller blast radius)
- **Area:** Legacy creation / error handling
- **Evidence:** `lib/services/auth_service.dart:1939-1986` (`createElectionBallot`)

## Problem

`createElectionBallot` swallows Firestore errors and returns `success: true` from the cache — the ballot appears created locally but may not exist on the server. It also hardcodes minGrade 1 / maxGrade 12 and opens at start−2s.

## What breaks

Managers believe a ballot exists; voters on other devices never see it; local-only ballots can later be "voted on" and "certified" entirely in cache (feeding C5/C8).

## Solution

Rethrow write failures and return success only after the server acknowledges; cache only as a read-through of confirmed server state. Create ballots through the v2 callable (H3 migration) so grade range and schedule are validated server-side.