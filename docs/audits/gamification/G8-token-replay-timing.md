# G8. Token replay and non-constant-time signature comparison

**Severity:** MEDIUM

## Problem

- **Replay:** `generateScoreProofToken` includes a random nonce ([gamification_security_service.dart:76](../lib/services/gamification_security_service.dart)), but `verifyScoreProofToken` (:103-260) **never records or checks used nonces**. A captured token verifies again anywhere inside the 5-minute window (:234-248). The only replay gates are the local cooldowns (G6).
- **Timing:** signature comparison uses `signature.toLowerCase() != expectedSig.toLowerCase()` (:221) — a non-constant-time string compare. Same in [sports_security_service.dart:50](../lib/services/sports_security_service.dart): `return expected == token;`. The election fix already established the constant-time pattern ([election_security_service.dart:61-68](../lib/services/election_security_service.dart)).
- **Raw-JSON fallback:** the verifier accepts an unencoded raw-JSON token (:142-159) — a second parsing path with the same trust, widening the attack surface for malformed payloads.

## What breaks

1. A token observed in logs/cache can be replayed within 5 minutes from any context where local cooldowns were reset.
2. Timing side-channel on signature comparison (low practical risk on device, but it's the same weakness already fixed once in elections).
3. Two parsing paths mean twice the validation burden; the fallback exists for no documented reason.

## Solution

1. Constant-time compare for both services (reuse the election `_constantTimeEquals` approach).
2. If tokens remain client-side hints (G2), drop the raw-JSON fallback; if they become server-verified, the server must persist consumed nonces (or use short-lived one-time tokens).
3. Remove the pointless `toLowerCase()` on hex signatures.

## Done when

- Both services use constant-time comparison.
- One parsing path only; replay handling is explicit (consumed-nonce store server-side, or documented hint-only status).