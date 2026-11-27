# M8 — Server gaps: missing actions, no App Check, ignored schedule

- **Severity:** Medium
- **Area:** Callable completeness
- **Evidence:** `functions/elections-v2.js:139-232`, `functions/index.js:19`, `lib/screens/school_elections_page.dart:1326-1517` (`createDraft` forces start=now)

## Problem

The callable has no `close`, `cancel`, `deleteDraft`, or audit actions; no App Check enforcement; `createDraft` always sets start = now and publish opens at now−2s, so **scheduled elections are impossible**; the position list omits `viceCaptain`.

## What breaks

Managers can't close/cancel/delete through the secure path (forcing the fallback, C4/C9); any script can call the endpoint (no App Check); scheduled polls open immediately; vice-captain elections can't be created.

## Solution

1. Add callable actions: `close` (manager, before deadline), `cancel` (manager, any time, no points), `deleteDraft` (draft only), `audit` (append log entry, M5).
2. Enforce App Check on the callable (`enforceAppCheck: true`) and attest the Flutter app (Play Integrity / DeviceCheck / debug provider for dev).
3. Accept and honor `startMs` in create/publish; server vote already rejects before `opensAt` — keep it and show "Opens at …" in the UI.
4. Add `viceCaptain` (and any other missing positions) to the position list in one shared constant used by client and server.