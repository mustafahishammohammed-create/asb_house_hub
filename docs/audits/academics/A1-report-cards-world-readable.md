# A1. Report cards are world-readable to every signed-in student

**Severity:** HIGH

## Problem

Report cards — GPA, percentage, attendance rate, per-subject grades, teacher remarks, student name and scholar number — are readable by **any signed-in account**, not just the owner and staff:

- Rules: `match /report_cards/{reportCardId} { allow read: if isSignedIn(); allow write: if isAdmin(); }` — [firestore.rules:764-767](../firestore.rules).
- Document IDs are enumerable: `cardId = 'rep_${cleanScholar}_$safeTerm'` — [auth_service.dart:1653](../lib/services/auth_service.dart). Scholar numbers are public inside the school (rosters, claims, leaderboards), and term names are a handful of predictable strings (`term_1_mid_term`, etc.).
- The parent `classes/{classId}` read is also `isSignedIn()` ([firestore.rules:720](../firestore.rules)), so class-level enumeration is trivial.

The client *behaves* as if this were private — `getReportCardsStream` filters `scholar_no == own` by default ([auth_service.dart:1541-1543](../lib/services/auth_service.dart)) — but that is a query filter, not a security boundary. Any student can read `classes/Grade 10/report_cards/rep_2310910_term_1_mid_term` directly with the same Firebase config the app ships.

## What breaks

1. **Student privacy breach.** Any student can read any other student's grades, GPA, attendance and teacher remarks across every class — not just their own. This is the academic-records equivalent of publishing report cards on a notice board.
2. Enumeration is cheap: scholar numbers are 7 digits visible throughout the app; term slugs are derived from a short fixed list.
3. Contrast with the same file's own standard: attendance reads are owner-or-admin ([firestore.rules:769-772](../firestore.rules)), medical leaves are owner-or-admin (:1002), assignment submissions are owner/council/admin (:742). Report cards are the one sensitive academic record left open.

## Solution

**No Blaze required (rules-only + small client hardening):**

1. Tighten the read rule to the same pattern already used for attendance and medical leaves:
   ```
   match /report_cards/{reportCardId} {
     allow read: if isAdmin() ||
       ('scholar_no' in resource.data && isScholarOwner(resource.data.scholar_no));
     allow write: if isAdmin();
   }
   ```
   The existing client query (`where scholar_no == own`) keeps working unchanged — every doc it returns satisfies `isScholarOwner`.
2. Add `.handleError` fallback to the cache in `getReportCardsStream` ([auth_service.dart:1550-1559](../lib/services/auth_service.dart)): the current `try/catch` only catches synchronous errors, so a rules denial on the snapshot stream would surface as an unhandled stream error. Mirror the owner-scoped fallback used elsewhere.
3. Deploy: `firebase deploy --only firestore:rules` (free on Spark).
4. Add a rules-contract test asserting the report_cards read block contains `isScholarOwner` and not a bare `isSignedIn()`.

**Decision note:** if council officers are ever meant to see peers' cards, add `isCouncil()` explicitly — but the privacy-preserving default is owner + admin only.

## Status: RESOLVED (2026-11-08)

1. **Firestore Rules:** `classes/{classId}/report_cards/{reportCardId}` read permission restricted to `isAdmin() || ('scholar_no' in resource.data && isScholarOwner(resource.data.scholar_no))`. Deployed to `cloud.firestore` with zero warnings ("already up to date").
2. **Stream Fallback:** Added `.handleError` in `auth_service.dart:1559` to gracefully catch asynchronous rules denial / stream error and fall back to local cached report cards.
3. **Automated Verification:** Verified in `test/academics_security_test.dart` (read rules contract test and stream fallback test passed).