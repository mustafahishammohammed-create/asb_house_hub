# L2 — getSavedAccounts has surprising side effects

- **Severity:** Low
- **Area:** Auth service hygiene
- **Evidence:** `lib/services/auth_service.dart:2012-2098`

## Problem

A getter mutates state: it dedupes accounts, **force-marks super admins**, and **auto-adds the active account** to the saved list.

## What breaks

Reading the account list changes it; role forcing can mask stale roles; the active account appears as "saved" even when the user never saved it (and may have no password, feeding H1's no-re-auth switch).

## Solution

Make `getSavedAccounts` a pure read. Move dedupe/normalization to a one-time migration at startup; mark super-admin status from the server profile, not in a getter; only add accounts to the saved list on explicit user action (save/add sibling).