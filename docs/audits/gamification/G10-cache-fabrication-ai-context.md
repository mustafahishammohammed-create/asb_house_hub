# G10. Cache-first standings and AI answers present fabricated numbers

**Severity:** MEDIUM

## Problem

- Home dashboard pre-hydrates standings from the local cache ([home_screen.dart:3039-3053](../lib/screens/home_screen.dart)); server data overwrites it **only when the stream delivers non-empty docs**. Until then — and forever, if the stream errors — the user sees cache values inflated by phantom awards (G1).
- The AI chat service feeds **cached** standings into its context ([gemini_ai_service.dart:183](../lib/services/gemini_ai_service.dart), :520; [house_ai_chat_screen.dart:578](../lib/screens/house_ai_chat_screen.dart)) — the AI confidently answers questions about house points using fabricated local numbers.
- `getCachedStudentContribution` ([auth_service.dart:532-551](../lib/services/auth_service.dart)) is permanently inflated by phantom awards and has no server reconciliation path at all.
- `incrementCachedHousePoints` (:485-490) is called by award paths regardless of server outcome (G1), so the cache diverges structurally.

## What breaks

1. Two students on the same Wi-Fi see different standings; the AI tells each a different story.
2. Offline/error states silently present last-known-fabricated data as current ("live standings" section).
3. Contribution stats on profiles never match the server ledger.

## Solution

1. Cache writes only from server-confirmed snapshots (the home stream already does this at :3053 — make it the **only** writer; award paths stop writing standings directly).
2. Label pre-hydration/offline states visibly ("offline — last synced …") instead of presenting them as live.
3. AI context: use the server stream's latest snapshot, or annotate the data as cached/unverified.
4. Reconcile contribution cache from `house_contributors` on read; delete phantom increments.

## Done when

- No award path writes the standings cache; only server snapshots do.
- Offline UI states are labeled; AI answers cite server-synced data or flag staleness.