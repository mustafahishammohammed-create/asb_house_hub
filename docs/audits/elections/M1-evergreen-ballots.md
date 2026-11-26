# M1 — Evergreen legacy ballots (missing end_time never closes)

- **Severity:** Medium
- **Area:** Legacy lifecycle
- **Evidence:** `lib/screens/school_elections_page.dart:268-303` (legacy merge)

## Problem

When a legacy `elections` doc lacks `end_time`, the client substitutes `now + 7 days` — and recomputes it on **every load**.

## What breaks

The ballot's deadline moves forward every time anyone opens the page → it never closes, can be certified at any moment as "still open", and never appears expired. Malformed or old docs become immortal elections.

## Solution

Treat missing `end_time` as **closed/invalid**, not as a fresh deadline: show the ballot as "Ended (no deadline recorded)" and exclude it from active voting. Require `end_time` at creation (server-side validation). One-off migration: set a real `end_time` on legacy docs that lack one, or mark them archived.