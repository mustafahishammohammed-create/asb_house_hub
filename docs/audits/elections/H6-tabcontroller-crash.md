# H6 — Role flip during account switch crashes the v2 page

- **Severity:** High
- **Area:** UI stability / account switching
- **Evidence:** `lib/screens/school_elections_page.dart:75` (`SingleTickerProviderStateMixin`), `:100-114` (initState TabController), `:322-330` (post-frame `_isManager` flip), `:2466-2475` (build disposes/recreates TabController)

## Problem

The state uses `SingleTickerProviderStateMixin`, but `build()` **disposes and recreates the TabController** when the manager tab count changes, triggered by the post-frame `_isManager` flip. Creating a second `AnimationController`/`TabController` on a single-ticker mixin violates its contract.

## What breaks

Switching between a manager account and a non-manager account (exactly the account-switch flow) triggers a debug assertion crash: "SingleTickerProviderStateMixin can only be used as a TickerProvider once." The elections page dies at the moment roles change.

## Solution

Pick one:

1. Use `TickerProviderStateMixin` (plural) instead of `SingleTickerProviderStateMixin` — allows multiple tickers over the state's lifetime.
2. Better: don't rebuild the controller in `build()`. Compute `_isManager` **synchronously before** creating the TabController (from the already-cached profile at initState), and when the role genuinely changes, remount the page with a new `ValueKey(role)` so a fresh State creates one controller.
3. Never dispose/recreate controllers inside `build()` — do it in `didUpdateWidget`/`setState` handlers.

Test: pump the page as manager, flip the cached role to student, pump again → no exception, correct tab count.