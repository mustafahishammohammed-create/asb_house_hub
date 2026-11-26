# M10 — Universal polls label every candidate as Ruby

- **Severity:** Medium
- **Area:** Results display / points routing
- **Evidence:** `lib/screens/school_elections_page.dart:1021, 1043` (fallback publish), `:1160-1161` (winner house from scope)

## Problem

When publishing a universal (all-house) poll, the fallback labels **every candidate's house `'ruby'`**; certification then derives the winner's house from the poll scope, which also defaults to `'ruby'`.

## What breaks

House chips are wrong for every non-Ruby candidate; combined with C8, universal elections award +100 to Ruby no matter who wins — a systematic scoring bias.

## Solution

1. Candidate house comes from the **roster record** at add/publish time (server-side), never from the poll scope or a constant.
2. Universal polls display each candidate's real house (or "—" if unknown); certification awards points to the winning candidate's roster house (C8).
3. Migration: fix existing universal polls whose candidates were all stamped ruby by re-reading roster houses.