# L1 — Cosmetic and minor logic faults

- **Severity:** Low
- **Area:** UI / display logic
- **Evidence:** `lib/screens/election_chamber_screen.dart:987` ("Certified:" label), `:1711-1743` (hardcoded grades/years), `lib/screens/school_elections_page.dart:1210-1245, 2480-2509` (fabricated margins)

## Problem

Hardcoded election years and grades 1–12; the chamber's "Certified:" label actually shows the **vote time**; margins are fabricated (`maxV>0?maxV:1`, margin 0 on ties); tie ordering is an unstable sort.

## What breaks

Users misread when certification happened; margins of "1" appear out of nowhere; tie ordering changes between builds; the app needs code edits every year.

## Solution

Derive the year from the clock/academic config; label the timestamp "Voted at"; show margin only when there is a real runner-up (else "Unanimous"/"No votes"); sort with a deterministic tiebreak (name/id) and render ties as ties (C8); drive grade ranges from school config.