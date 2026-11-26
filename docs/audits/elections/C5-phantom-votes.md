# C5 — Phantom votes: failure is reported as success

- **Severity:** Critical
- **Area:** Vote integrity / error handling
- **Evidence:** `lib/screens/school_elections_page.dart:694-698` (fallback catch), `:662-663` (denied legacy counts write), `lib/services/auth_service.dart:4573-4585` (`castDigitalVote` catch), `firestore.rules:580-582` (default deny)

## Problem

Both client vote paths catch **all** errors and then fabricate success:

- v2 fallback (`school_elections_page.dart:694`): the catch swallows the failure, invents a receipt, increments the local tally, and returns success.
- Chamber (`castDigitalVote`): the catch does a non-transactional participation `set`, then falls through to a local increment + receipt + `success: true`.

A guaranteed trigger exists: fallback-published polls mirror a legacy `elections` doc, and the fallback vote transaction writes `elections/{id}/counts` — a path with **no rules match**, so the default-deny rule rejects it. The transaction *always* fails for those polls → the phantom path is *always* taken.

## What breaks

Users see "vote counted" and receive a receipt while nothing (or only partial state) was persisted. Local tallies move, receipts verify against local cache, and certifications built on these numbers are fiction. Nobody — voter, manager, or auditor — can tell a real vote from a phantom one.

## Solution

1. Never fabricate success. On transaction/callable failure, **rethrow** and show "Your vote was NOT recorded. Please try again." No receipt, no local tally change.
2. Issue receipts **only** from the server's vote response (the callable already returns a `randomUUID()` receipt id).
3. Remove the legacy `elections/{id}/counts` write from the client (it dies with the fallback in C4; server-side tallies live only in v2 `counts`).
4. After a successful vote, re-read the participation doc (or trust the callable's transactional result) before showing confirmation.
5. Test: simulate a callable 500 / rules denial and assert no receipt is cached, no local count changes, and an error is shown.