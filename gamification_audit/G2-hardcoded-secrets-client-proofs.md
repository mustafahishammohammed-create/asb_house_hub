# G2. Hardcoded HMAC secrets; client mints and verifies its own proofs

**Severity:** CRITICAL

## Problem

Two more hardcoded secrets ship in client source (values withheld — existence only):

- Gamification institution secret — [gamification_security_service.dart:26](../lib/services/gamification_security_service.dart): `static const String _institutionSecret = <literal>`.
- Sports certification salt — [sports_security_service.dart:6-7](../lib/services/sports_security_service.dart): `static const String _kSportsCertificationSalt = <literal>`.

Both services **generate and verify tokens on the same device**: `generateScoreProofToken` (:66) / `verifyScoreProofToken` (:103); `generateMatchCertificationToken` (:10) / `verifyMatchCertificationToken` (:29). The "cryptographic proof" proves nothing — the client signs its own homework. Callers mint tokens moments before verifying them ([auth_service.dart:1042-1052](../lib/services/auth_service.dart), :1521-1533, :5459-5468).

## What breaks

1. Anyone extracting the literals from the binary (trivial string search) can mint valid tokens for **any scholar, any activity, any score ≤ 50**, and forge match-certification signatures for any fixture/score.
2. Even without extraction, the mint→verify loop is client-authoritative: a modified client skips the game entirely and calls the award with a self-minted token.
3. This is the exact pattern eradicated from elections (A1/A2): hardcoded secret + insecure fallback. The same cancer survives in two more services.

## Solution

**Interim (no Blaze):**
1. Delete both literals. Replace with fail-closed getters: `String.fromEnvironment('GAMIFICATION_HMAC_SECRET')` / `('SPORTS_CERT_SECRET')`, throwing `StateError` when unset, with `@visibleForTesting` test injection — copy the election pattern exactly ([election_security_service.dart:16-27](../lib/services/election_security_service.dart)).
2. Until a server verifier exists, treat client tokens as **anti-tamper hints only**, never as authorization. The award decision must not depend on them (see G1: the server callable is the real gate).

**End state (Blaze):** tokens are minted server-side (or scores validated server-side) inside `schoolGamification` / a sports callable; the client never holds signing keys.

## Done when

- Grep finds zero secret literals in `lib/` (existence-only references in docs).
- Live builds without dart-defines fail closed with `StateError`; tests inject ephemeral secrets.
- No award decision is gated solely by a client-verified token.