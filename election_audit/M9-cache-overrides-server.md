# M9 — Cache overrides server truth

- **Severity:** Medium
- **Area:** Caching / consistency
- **Evidence:** `lib/services/auth_service.dart:1901-1936` (`getElectionsStream`), `:4757-4777` (gazette stream), `lib/screens/school_elections_page.dart:237-266, 332-350` (cached ballots/drafts/certifiedIds)

## Problem

`getElectionsStream` merges cache into the server stream and **preserves cached `certified` status over the server's**; the gazette stream falls back to cache when the server is empty, so deletions never propagate; cached ballots/drafts/certifiedIds are merged into lists regardless of server state.

## What breaks

A poll reopened or de-certified on the server still shows "certified" locally; deleted gazettes/drafts keep appearing; stale cached state can resurrect drafts (C9) and mask server corrections. Users on different devices see different election states.

## Solution

1. Server is the source of truth whenever a snapshot arrives: replace, don't merge. Cache is used **only** while offline, with a visible "Offline — showing saved data" banner.
2. On reconnect, clear election caches and re-read.
3. Never let cached status override a server field; cached drafts are dropped if the server draft is published/deleted (C9).
4. Gazette deletions propagate: render exactly the server docs, cache only as offline fallback.