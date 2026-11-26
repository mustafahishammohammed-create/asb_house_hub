# C3 — Admin bootstrap takeover in signInAdmin

- **Severity:** Critical
- **Area:** Authentication / provisioning
- **Evidence:** `lib/services/auth_service.dart:2680-2728`

## Problem

`signInAdmin` catches `user-not-found` and **creates** `admin@asianschool.bh` with whatever password was entered, then signs in as it. Account creation is wired into a login flow.

## What breaks

If the real admin account has not been provisioned yet (fresh project, deleted account, new environment), the **first person to try the admin login becomes the admin** — with full client-side privileges and, combined with C2, a path to server-side authority. There is no verification that the person entering the password is staff.

## Solution

1. Delete the auto-create branch. `signInAdmin` should only sign in; on `user-not-found` show "Admin account not provisioned — contact IT."
2. Provision the admin account **once**, out of band: Firebase console, an Admin SDK script run by IT, or a callable guarded by an existing admin's custom claim.
3. Set a custom claim (`admin: true`) on the real admin uid and use it in rules (see C2 solution) instead of email/scholar heuristics.
4. If the account already exists in the project, rotate its password after removing this code path, since anyone who read the binary knows the bootstrap trick existed.