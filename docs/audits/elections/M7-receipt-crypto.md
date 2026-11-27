# M7 — Receipt crypto weaknesses

- **Severity:** Medium
- **Area:** Receipts / applied crypto
- **Evidence:** `lib/services/election_security_service.dart`, `lib/services/auth_service.dart:39-89` (vault), `:4122-4219` (receipts)

## Problem

A hardcoded HMAC salt ships in the binary (value withheld from this report); the "anonymized" voter hash is deterministic and reversible via the public roster; hash comparison is non-constant-time; receipt codes are 8 chars; the signed timestamp is a local ISO string **without offset**, so the HMAC breaks after a timezone change. The credential vault uses a separate hardcoded secret (value withheld).

## What breaks

Anyone with the APK can recompute every "anonymized" hash (deanonymization, C7), forge receipt signatures, and brute-force the short codes; traveling users' receipts stop verifying; saved sibling passwords are recoverable (see ACCOUNT_SWITCHING S9).

## Solution

1. Move all signing/verification **server-side**; secrets live in Secret Manager, never in the binary. The client receives a signed receipt from the callable and can verify it with a public key if offline verification is needed.
2. If a client-side hash remains, make it keyed with a per-install random secret stored in platform secure storage — but prefer server-side.
3. Use constant-time comparison for any MAC check.
4. Receipt codes ≥ 128 bits of entropy (UUIDv4 is fine).
5. Sign UTC ISO-8601 with `Z` offset so verification is timezone-independent.
6. Vault: move saved credentials to `flutter_secure_storage` (Keystore/Keychain) or stop storing passwords at all (re-auth per switch, H1).