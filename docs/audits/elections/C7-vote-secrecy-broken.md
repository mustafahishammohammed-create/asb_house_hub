# C7 — Vote secrecy is broken (choice, turnout, and receipts all leak)

- **Severity:** Critical
- **Area:** Privacy / ballot secrecy
- **Evidence:** `firestore.rules:754-758` (`election_votes` read: true), `lib/screens/school_elections_page.dart:667-675` (candidate fields written), `functions/elections-v2.js:107-108` (unsalted participation key), `lib/screens/election_chamber_screen.dart:902` ("completely anonymous" copy)

## Problem

Three independent leaks:

1. **Choice:** the fallback writes `candidate_scholar_no` and `candidate_name` into `election_votes`, which is `read: if true` → anyone can read everyone's choice.
2. **Turnout:** participation keys are unsalted `sha256(pollId + ":" + scholarNo)` and the roster (`school_members`) is public → anyone can compute every scholar's key and check who voted.
3. **Receipts:** receipt IDs embed the voter-key prefix (`rcpt_<ms>_<key8>`), linking a receipt back to its voter.

Meanwhile the chamber tells users voting is "completely anonymous" — false on all three counts.

## What breaks

Coercion and vote-buying become verifiable ("show me your receipt / I can see you didn't vote"); social pressure maps turnout; the legacy system exposes the actual choices. This violates the basic secret-ballot guarantee the UI promises.

## Solution

1. Strip candidate-identifying fields from anything publicly readable. Vote-choice records (if kept at all) go in a server-only subcollection with `allow read: if false`.
2. Salt participation keys **server-side**: `HMAC_SHA256(secret, pollId + ":" + scholarNo.toLowerCase())` with the secret in functions config/Secret Manager — never in the binary. Clients learn only "you voted" from the callable response, never the key.
3. Receipts = random UUID only (the server already does this). No voter-derived prefix, no embedded key material.
4. Fix the copy: either implement true secrecy as above, or say precisely what is visible ("Your choice is secret; participation is visible to election officials").
5. Purge candidate fields from existing `election_votes` docs via a one-off Admin SDK migration.