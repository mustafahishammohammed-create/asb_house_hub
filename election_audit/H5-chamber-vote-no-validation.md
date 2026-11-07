# H5 — Chamber vote path has almost no validation; UI races

- **Severity:** High
- **Area:** Legacy voting / UI concurrency
- **Evidence:** `lib/services/auth_service.dart:4375-4642` (`castDigitalVote`), `lib/screens/election_chamber_screen.dart:916-938` (vote modal pops before await), `:1711-1743` (create modal pops before await)

## Problem

`castDigitalVote` performs **no status, window, eligibility, or candidate-membership checks**; candidate matching by **name** can increment multiple same-name candidates; the else-branch writes vote locks even when the ballot exists nowhere. The vote modal pops **before** `await castDigitalVote` with no busy guard; the create modal does the same.

## What breaks

- Double-tap → two votes (or two creates) race; the user can reopen the dialog while the first vote is in flight.
- Votes land on closed/draft ballots, for ineligible voters, on multiple candidates at once, or on ballots that don't exist.
- Create failures silently lose the draft because the dialog already closed.

## Solution

1. Migrate chamber voting to the v2 callable (H3) so all validation is server-side. If legacy voting must remain temporarily, move it into a callable with the same checks as `elections-v2.js`.
2. Match candidates by **ID only** — never by name.
3. Add busy guards: a `_submitting` flag disables the button and pops the dialog **only after** the await succeeds; on failure the dialog stays open with the error.
4. Never write locks for a ballot that doesn't exist — verify the ballot doc inside the transaction and abort otherwise.
5. Test: double-tap the vote button → exactly one vote recorded; vote on a closed ballot → rejected.