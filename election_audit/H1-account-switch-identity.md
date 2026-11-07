# H1 — Account switching breaks identity (cache swaps before auth)

- **Severity:** High
- **Area:** Account switching / attribution
- **Evidence:** `lib/services/auth_service.dart:2240-2291` (`switchAccount`), `:2174-2237` (`recordActiveAccount`), `:2792-2874` (`ensureSchoolMemberRecord`), `lib/screens/home_screen.dart:322-363` (`_switchActiveSession`), `lib/screens/school_elections_page.dart:45-58` (desk keyed scholar_uid)

## Problem

`switchAccount` swaps the cached scholar/uid/role/house **immediately**, then re-authenticates Firebase in the background with a 4 s timeout, swallows failures, and **skips re-auth entirely when no saved password exists**. The cached identity and the Firebase identity can therefore disagree indefinitely. `recordActiveAccount` also fire-and-forgets `ensureSchoolMemberRecord` **before** the switch completes, writing the sibling's roster doc under the old auth with a possibly stale profile (grade defaulted to 10, staff auto-promoted to admin with `manage_elections`).

## What breaks

- Cached scholar B + Firebase uid A → votes/receipts attributed to B but executed under A's auth; server eligibility checks the wrong person; the fallback writes B's scholar under A's session.
- Switching itself corrupts the roster (wrong grade/house/role), which then decides eligibility and management rights.
- Failed or password-less switches show the new account in the UI while all server actions run as the previous account. Full scenario walkthroughs: [ACCOUNT_SWITCHING.md](ACCOUNT_SWITCHING.md).

## Solution

1. Make switching **atomic**: `await signInWithEmailAndPassword` (or custom-token re-auth) **first**; only on success swap the cached profile/scholar/uid and notify listeners. On failure, keep the old account and show the error.
2. No saved password → prompt for it; never switch cache without a completed auth.
3. Block election (and other sensitive) actions while a switch is in flight; show a switching spinner.
4. Remove the fire-and-forget `ensureSchoolMemberRecord` from `recordActiveAccount`. Provision roster records server-side on sign-in (callable or Auth trigger), from authoritative data — never from the client cache.
5. After any switch, re-read the profile from the server before rendering role-gated UI.