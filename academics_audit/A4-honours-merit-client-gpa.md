# A4. Honours merit claim trusts client GPA; claimed-flag can never persist

**Severity:** MEDIUM  
**Status:** RESOLVED (Phase P1 Interim Hardening, 2026-11-08; end-state D5 callable deferred to Blaze)

## Resolution Evidence
- **Server/Cached Document Verification (`auth_service.dart:1647-1710`):** `claimReportCardHonoursMerit` inspects the actual report card document. It enforces `verifiedGpa >= 3.80` strictly from the document (rejecting caller-spoofed GPA values), asserts `docScholar == sNo` (rejecting cross-student claims), and checks `alreadyClaimed == false`.
- **Eradication of Doomed Client Write:** Dropped the doomed client-side `_firestore.collection('report_cards').update({'is_merit_claimed': true})` call which rules would reject. Updates cache only upon verified points award.
- **Automated Verification:** Verified by 4 security unit tests in `test/academics_security_test.dart` (spoof rejection, caller mismatch rejection, already-claimed rejection, and verified award success).

## Problem

`claimReportCardHonoursMerit` — [auth_service.dart:1567-1634](../lib/services/auth_service.dart) — awards 50 house points for a GPA ≥ 3.80 report card, but every check is client-side:

1. **Caller-supplied GPA.** `if (gpa == null || gpa < 3.80) return false;` (:1576) trusts the `gpa` argument. The method **never reads the report card document** — it does not verify the card exists, belongs to the caller, has that GPA, or hasn't already been claimed. The UI passes `card.overallGpa` ([academics_screen.dart:4266-4270](../lib/screens/academics_screen.dart)), but any modified client can call the service with `gpa: 4.0` and an arbitrary `reportCardId`.
2. **The claimed flag can never persist.** On success it updates `is_merit_claimed: true` on the report card (:1611-1616) — but `report_cards` writes are `isAdmin()` only ([firestore.rules:766](../firestore.rules)). A student's update is denied, the denial is swallowed by `catch (_) {}` (:1617), and only the local cache is flipped (:1620-1627). The server-side flag stays `false` forever.
3. **Client-only replay gate.** The UI blocks re-claims with `card.pointsClaimed || _claimedCardIds.contains(card.id)` ([academics_screen.dart:4260](../lib/screens/academics_screen.dart)) — an in-memory set plus a cache value that the server never confirms. The only server-side brake is the gamification 24-hour cooldown on activity `report_honours_$reportCardId`, which resets daily.

**Current live behavior is fail-closed by accident:** the award itself goes through `awardVerifiedGamificationPoints`, whose live Firestore transaction is rules-denied for students (D4), so the claim returns `false` today. The vulnerability activates the moment D4 ships server-side awards: a student could claim the same card **every day, forever** (50 pts/day), because the one-time flag never persists.

## What breaks

1. Post-D4: unlimited daily replay of the same merit claim — the "one-time distinction bonus" becomes a subscription.
2. Post-D4: claims for cards the student doesn't own, or with fabricated GPA — the server never looks at the card.
3. Today: the UI/cache say "claimed" while the server says nothing — the same split-brain as A2/A3, and the flag silently resets on cache clear or reinstall.

## Solution

**Interim (no Blaze) — fix before or together with D4:**

1. Read the card from Firestore inside the claim: verify it exists, `scholar_no` matches the caller, and use **the document's** `overall_gpa` for the ≥ 3.80 threshold — ignore the caller's `gpa` parameter entirely.
2. Stop writing `is_merit_claimed` from the student client (it can never succeed). Either derive "claimed" from the server-side award ledger (e.g. the contributor/claim record for activity `report_honours_$reportCardId`), or accept that the flag is admin-owned and display claim state from the ledger.
3. Keep the claim fail-closed with a truthful message while D4 is pending ("Merit awards activate when server verification is live") instead of a silent `false`.

**End state (Blaze, D5):** a callable (or the `schoolGamification` callable) performs the whole claim atomically: read card → verify ownership + GPA → check `is_merit_claimed == false` → award points → set `is_merit_claimed: true` in one transaction with an idempotency key. Rules then keep `report_cards` writes admin/server-only.

## Done when

- The claim decision uses the server document's GPA and ownership, never caller arguments.
- A second claim of the same card is rejected by persisted server state, not by a local set — verified after cache clear/reinstall.
- Until D5: the feature is honestly labeled and fails closed; no cache-only "claimed" state.