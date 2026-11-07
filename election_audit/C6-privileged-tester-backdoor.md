# C6 — Privileged-tester voting backdoor

- **Severity:** Critical
- **Area:** Authorization / vote integrity
- **Evidence:** `lib/screens/school_elections_page.dart:465-470` (`isPrivilegedTester`), `:2053-2073` (ballot UI bypass), `lib/services/auth_service.dart:4375-4642` (`castDigitalVote` staff-tester bypass)

## Problem

Accounts matching admin / scholar `11209` / roles `admin`, `super_admin`, `principal` are treated as "privileged testers" and **skip the already-voted check, the voting window, and eligibility** in both the v2 fallback and the chamber vote path. The ballot UI also hides window/house/grade restrictions for them.

## What breaks

- Staff/admin accounts can vote an unlimited number of times, in any window, in any house's election.
- Anyone who escalates via C2 (self-created users doc with scholar `11209`) inherits the bypass.
- Even if intended as a demo convenience, it ships in production code and silently corrupts real tallies.

## Solution

1. Delete `isPrivilegedTester` / staff-tester branches everywhere. Staff vote under exactly the same rules as students — or not at all (the server's `eligible()` already requires `role == 'student'`, which is the correct policy; make the client match it).
2. If demo/testing convenience is needed, gate it behind a **compile-time flag** (`bool.fromEnvironment('DEMO_MODE')`, default false) so release builds physically cannot contain it.
3. Add a test: an admin-role profile attempting a second vote must be rejected by the same duplicate check as a student.