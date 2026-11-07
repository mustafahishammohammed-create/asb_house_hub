# Gamification / Points Module Audit — Findings & Fixes

Deep read-only audit of the points economy: `GamificationSecurityService`, `SportsSecurityService`, every `house_points` / `house_contributors` / `users.points_contributed` write site, the Blitz quiz, academic award paths, house claims, sports awards, Firestore rules, and the standings/AI display layer.

**Start here:** [FINAL_POINTS_REPORT.md](FINAL_POINTS_REPORT.md) — the final cross-module report covering every module's points integration, all 13 findings, the complete fix list, and the acceptance gate.

**Method:** full static read of every file involved, attack-scenario tracing, rules-vs-client cross-check. No code files were modified. Secrets (gamification HMAC secret, sports certification salt) are referenced by existence only — values are never reproduced. Re-verified at `f20c7f7` (2026-11-07): `flutter analyze` 0 errors (20 infos), election security tests 32/32; the cross-module sweep added G12 (election certify cache double-count) and G13 (spirit reactor).

**Verdict:** the points economy has the same disease elections had, but worse — **for students it doesn't actually work at all**. Every student-facing award writes to admin-locked collections, the denial is swallowed, and success is fabricated (G1). Meanwhile the one server write path students *can* reach (sports-leader roles) has no content validation (G3), and two more hardcoded secrets ship in the binary (G2). The good news: `approveClaim`, `recordStudentConduct`, and the users-collection rules are genuinely well-built — the fix pattern already exists in this codebase.

Each finding follows: **Problem → What breaks → Solution → Done when**.

## Critical (3)

| ID | Finding | Key evidence |
|----|---------|--------------|
| G1 | Student points economy is phantom — denied writes reported as success | [G1](G1-phantom-student-points.md) |
| G2 | Hardcoded HMAC secrets; client mints and verifies its own proofs | [G2](G2-hardcoded-secrets-client-proofs.md) |
| G3 | house_points accepts unbounded writes from student sports leaders | [G3](G3-unbounded-house-points-writes.md) |

## High (4)

| ID | Finding | Key evidence |
|----|---------|--------------|
| G4 | Students self-grade assignments and self-claim academic merits | [G4](G4-self-grading-merit-claims.md) |
| G5 | Blitz quiz fully client-authoritative, answers in binary, unlimited replays | [G5](G5-blitz-quiz-client-authority.md) |
| G6 | Local-only cooldowns; clock rollback bypasses every limit | [G6](G6-local-cooldowns-clock-trust.md) |
| G7 | Contributor ledger split-brain — two ID schemes, missing records | [G7](G7-contributor-ledger-split-brain.md) |

## Medium (5)

| ID | Finding | Key evidence |
|----|---------|--------------|
| G8 | Token replay (nonce never consumed) + non-constant-time compares | [G8](G8-token-replay-timing.md) |
| G9 | Phantom success paths and fabricated claim IDs | [G9](G9-phantom-success-fabricated-ids.md) |
| G10 | Cache-first standings and AI answers present fabricated numbers | [G10](G10-cache-fabrication-ai-context.md) |
| G11 | No award idempotency; claim points/house mutable on update | [G11](G11-idempotency-mutable-claims.md) |
| G12 | Election certify live path double-counts local cache; demo +100/+50 drift | [G12](G12-election-certify-cache-double-count.md) |

## Low (1)

| ID | Finding | Key evidence |
|----|---------|--------------|
| G13 | Spirit reactor unbounded/spoofable/last-write-wins (cosmetic, no house_points) | [G13](G13-spirit-reactor-unbounded-write.md) |

## What is already solid (do not break)

- `approveClaim` — server-authoritative values, duplicate-approval guard, single transaction, rethrow on failure ([auth_service.dart:3438-3520](../lib/services/auth_service.dart)).
- `users` rules — self-update cannot touch `role`, `points`, `points_contributed`, `scholar_no`; create forces `student` + zero points ([firestore.rules:588-621](../firestore.rules)).
- `student_conduct` writes are admin-only; `recordStudentConduct` lets the transaction throw (no phantom).
- `house_claims` create is owner+pending-only; `defaultSeedStandings` is a clean zero baseline.

## Companion documents

- [REMEDIATION_ROADMAP.md](REMEDIATION_ROADMAP.md) — prioritized P0/P1/P2 plan, split into no-Blaze work (now) and Blaze work (deferred, mirrors `election_audit/BLAZE_REQUIRED_FEATURES.md`).
- Election audit pattern reference: [../election_audit/README.md](../election_audit/README.md) — the same Problem→Solution format and the A1/A2 secret-eradication pattern to copy.