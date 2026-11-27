# C1 — Every election collection is public-read / any-user-write

- **Severity:** Critical
- **Area:** Firestore rules / server authority
- **Evidence:** `firestore.rules:741-763` (legacy elections, votes, gazettes), `firestore.rules:890-916` (school_members, election_polls_v2 + counts + participation, election_drafts_v2)

## Problem

The rules allow `read: if true` and create/update/delete for **any signed-in user** on every election collection, including the roster (`school_members`), live vote counts, participation locks, published polls, and drafts. The `schoolElection` callable validates carefully, but it runs with the Admin SDK (which bypasses rules) — while direct client writes are equally permitted. The server's validation is therefore decorative.

## What breaks

Any student, straight from the Flutter SDK or a REST call, can:

- Set `election_polls_v2/{id}/counts/{candId}` to any number → rig results.
- Delete their own `participation/{key}` doc → vote again.
- **Pre-create someone else's participation doc → permanently block them from voting** (the server sees "alreadyRecorded" and refuses).
- Edit or delete published polls and drafts.
- Rewrite `school_members/{uid}` → grant themselves `capabilities.manage_elections`, change their `scholar_no` to vote twice, or change house/grade to pass eligibility.
- Overwrite `election_gazettes` → rewrite official election history.

**Repro:** sign in as a plain student, then `FirebaseFirestore.instance.collection('election_polls_v2').doc(pollId).collection('counts').doc(candId).update({'votes': 9999})` — succeeds.

## Solution

Make the callable the **only** write path. The Admin SDK ignores rules, so locking clients out costs nothing:

```
match /school_members/{memberId} {
  allow read: if isSignedIn();
  allow write: if false;          // provisioned server-side only
}
match /election_polls_v2/{pollId} {
  allow read: if true;            // public header is fine
  allow write: if false;
  match /counts/{candidateId} {
    allow read: if true;          // aggregate totals only, no voter data
    allow write: if false;
  }
  match /participation/{key} {
    allow read: if false;         // turnout must not be enumerable
    allow write: if false;
  }
}
match /election_drafts_v2/{draftId} {
  allow read: if isSignedIn();    // managers filtered client-side; or false + callable reads
  allow write: if false;
}
```

Apply the same `write: if false` to `elections`, `election_votes`, `election_gazettes`. Move roster provisioning and candidate lookup into callable actions. Deploy with `firebase deploy --only firestore:rules` and verify with the rules emulator/unit tests that a signed-in non-admin write is denied.