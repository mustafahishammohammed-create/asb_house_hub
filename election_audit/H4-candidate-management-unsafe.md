# H4 — Candidate management is unsafe and phantom

- **Severity:** High
- **Area:** Draft/candidate lifecycle
- **Evidence:** `lib/screens/school_elections_page.dart:788-815` (create swallows), `:817-903` (add), `:839` (auto-provisioning), `:1519-1739` (add dialog lookup race), `functions/elections-v2.js:188-205` (correct server add)

## Problem

The fallback `add`: takes the **first** roster match; **auto-provisions another user's member doc** from their users doc; lets a typed name override the roster name; falls back to saved accounts; enforces no eligibility or 20-candidate limit; and does a **non-transactional read-modify-write** of the candidates array. `create` swallows write errors and caches a **phantom draft** that never existed server-side. The add dialog has an unsequenced lookup race and allows manual non-roster candidates defaulting to ruby/Grade 10.

## What breaks

- Concurrent adds lose candidates (last write wins over the whole array).
- Ineligible or non-existent people end up on the ballot; names can be falsified; another user's roster record is created/modified without their involvement.
- Managers see drafts that don't exist on the server and "successful" adds that persisted nothing.

## Solution

1. Route create/add/remove/deleteDraft through the callable only (the server `add` already enforces exactly-one roster match, roster-sourced names, eligibility, and the 20-candidate limit). Delete the fallback implementations (C4).
2. Remove auto-provisioning of other users' member docs — roster writes are server-only (C1/H1).
3. Remove the typed-name override and the saved-accounts fallback; the roster is the only name source.
4. Sequence the lookup: debounce the scholar field, cancel in-flight lookups (request id guard), disable the submit button until a lookup resolves.
5. On any write failure, show the error and cache nothing.