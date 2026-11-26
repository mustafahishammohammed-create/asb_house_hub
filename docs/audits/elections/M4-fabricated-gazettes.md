# M4 — Fabricated "statutory records" presented as real history

- **Severity:** Medium
- **Area:** Data integrity / trust
- **Evidence:** `lib/services/auth_service.dart:4700-4737` (`getFoundationalGazettes`), `lib/screens/election_gazette_screen.dart:31-34, 85-88` ("Load Statutory Records")

## Problem

`getFoundationalGazettes` invents winners (Mustafa Ahmed SCH-042, emerald, 248 votes; Alexander Sterling SCH-001, ruby, 312) and presents them as statutory records. The gazette screen's "Load Statutory Records" button **overwrites the entire cached gazette** with this fiction — available to any user.

## What breaks

Fake election history is indistinguishable from real proclamations; pressing the button destroys the locally cached real gazette; users and other AI/features consuming this data treat fiction as fact.

## Solution

1. Delete `getFoundationalGazettes` and the button. If historical records are wanted, import **real** ones via an Admin SDK script into `election_gazettes` with a `historical: true` flag.
2. The gazette screen loads only from the server stream; cache is a read-through fallback, never overwritten by synthetic data.
3. Clearly label any seeded demo data as `DEMO` in the doc and the UI.