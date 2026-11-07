# M5 — Audit screen is fiction (and leaks the voter's choice)

- **Severity:** Medium
- **Area:** Auditability / privacy
- **Evidence:** `lib/screens/election_audit_screen.dart:71` (hardcoded 500), `:162` ("Ministry of Education quorum"), `:283` (shows candidate name), `lib/services/auth_service.dart:4669-4686` (`getElectionAuditStream`), `firestore.rules` (no `election_audits` match)

## Problem

The audit screen hardcodes `totalEligibleVoters: 500`, cites invented "Ministry of Education quorum standards", and "verifies" receipts against **local cached receipts only** while claiming they were "counted in the official tally". A matched receipt's **candidate name is displayed** → reveals the choice. Meanwhile `election_audits` is read by `getElectionAuditStream` but **no code ever writes it and no rules match it** → permanently empty/denied.

## What breaks

The audit trail is theater: wrong denominators, fake compliance claims, verification that proves nothing about the server tally, and a privacy leak (C7) in the one screen meant to guarantee integrity.

## Solution

1. Write a real audit log **server-side**: the callable appends an `election_audits` entry (actor uid, action, poll, timestamp, outcome) on every vote/manage/certify action. Rules: `read: if isAdmin()`, `write: if false`.
2. Compute eligible-voter counts from the roster query matching the poll's scope — never a constant.
3. Verify receipts via a callable that checks the server participation/tally records; return only "included / not included", never the candidate.
4. Remove the Ministry copy and any claim not backed by implemented checks.