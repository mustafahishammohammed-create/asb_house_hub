# Account-Switching Scenarios — What Actually Happens

Companion to [H1](H1-account-switch-identity.md), [C6](C6-privileged-tester-backdoor.md), [H6](H6-tabcontroller-crash.md), [M7](M7-receipt-crypto.md).

Relevant code: `lib/services/auth_service.dart:2240-2291` (`switchAccount`), `:2174-2237` (`recordActiveAccount`), `:2792-2874` (`ensureSchoolMemberRecord`), `:4122-4219` (receipts), `:1989-2007` (`clearCache`), `lib/screens/home_screen.dart:322-363` (`_switchActiveSession`), `lib/widgets/account_switcher_modal.dart:621-671` (sibling add), `lib/services/hierarchy_service.dart:116-143` (`canManageElections`).

## S1 — A→B, re-auth slower than the 4 s timeout

- **Problem:** cache says B instantly; the timeout swallows the still-pending sign-in. B opens elections: the desk is keyed `Bscholar_Buid`, but Firebase uid is still A.
- **Breaks:** server eligibility checks `school_members/A` (wrong person) or rejects → fallback → vote written under **A's auth with B's scholar**, receipt cached for B. Attribution is wrong in both directions.
- **Solution:** atomic switch — await re-auth before swapping cache (H1); block election actions while switching.

## S2 — A→B, B has no saved password

- **Problem:** `switchAccount` returns early; **no re-auth at all**.
- **Breaks:** permanent S1 state until a manual sign-in; UI shows B while every server action runs as A.
- **Solution:** no password → prompt for it; never swap cache without completed auth (H1).

## S3 — A→B, wrong password or offline

- **Problem:** the sign-in failure is swallowed; the UI still shows B.
- **Breaks:** same misattribution as S1, with no error shown to the user.
- **Solution:** revert to A on failure and surface the error (H1).

## S4 — Roster write during the switch

- **Problem:** `recordActiveAccount` fire-and-forgets `ensureSchoolMemberRecord` **before** auth completes; grade defaults to 10; staff are auto-promoted to `role: 'admin'` with `manage_elections`.
- **Breaks:** the sibling's `school_members` doc is written under the old auth with a stale/wrong profile — the act of switching corrupts eligibility and management rights.
- **Solution:** remove the fire-and-forget write; provision roster server-side on sign-in from authoritative data (H1, C1).

## S5 — Siblings share one device

- **Problem:** per-scholar receipt isolation works (the tested part), but `getReceiptForBallot` with an empty scholar reads the **global mirror list**; cached **drafts, certifiedIds, and gazette are shared**; `clearCache` removes only the global receipts key, leaving per-scholar receipts, drafts, gazette, and audits behind.
- **Breaks:** B can see A's receipts (cross-account leak), open/republish A's cached drafts (C9), and inherits A's cached "certified" states (M9).
- **Solution:** scope **every** cache key by scholar/uid (drafts, certifiedIds, gazette, audits); delete the global receipt mirror; `clearCache` wipes all per-scholar keys; never read another scholar's cache entry.

## S6 — Manager→student switch

- **Problem:** the v2 page recreates its TabController in build on the role flip (H6); the chamber gates on **cached role/caps + current Firebase email** — if re-auth failed, that email is still A's.
- **Breaks:** debug crash on the elections page; or B keeps A's manager UI and rights.
- **Solution:** H6 ticker fix; gate on one identity source — the server-verified profile of the **current** Firebase uid, re-read after every switch (H1).

## S7 — Student→admin switch

- **Problem:** the privileged-tester bypass activates (C6).
- **Breaks:** unlimited voting, no window/eligibility checks — and via C2 anyone can fake the admin profile.
- **Solution:** delete the tester bypass (C6); authority from custom claims only (C2).

## S8 — Email-substring manager gate

- **Problem:** `canManageElections` uses `email.contains('admin@asianschool.bh')`; a student who signs up with scholar `xadmin` gets email `xadmin@asianschool.bh`, which **contains** the admin string.
- **Breaks:** manager UI and fallback management actions for a regular student.
- **Solution:** exact email equality (or better, custom claims / server-verified capabilities); never substring-match identity strings.

## S9 — Vault extraction (no switching bug needed)

- **Problem:** the credential vault's secret is hardcoded in the binary (value withheld); saved sibling passwords are encrypted with it.
- **Breaks:** anyone with the app binary can decrypt **all saved sibling passwords** on the device → full takeover of every saved account.
- **Solution:** move credentials to platform secure storage (`flutter_secure_storage` → Keystore/Keychain) or stop storing passwords and require re-auth per switch (H1, M7).