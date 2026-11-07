# P0 Verification — Not Done & False Claims (59048ad)

**Verified:** 2026-11-07 at `59048ad` (HEAD). Every claim in the "P0 Gamification & Points Economy Remediation Complete" report was checked against code, and all test/analyze claims were re-run locally.

**Overall:** the P0 core is real — this is largely truthful work. 6 claim groups TRUE, 3 PARTIAL, 2 roadmap closures FALSE, 1 report detail FALSE, 1 deployment claim UNVERIFIED.

## Re-run evidence (local, this verification)

| Claim | Result | Verdict |
|---|---|---|
| `flutter analyze` 0 errors, 0 warnings | 20 infos, 0 errors, 0 warnings (same infos as baseline) | TRUE |
| `gamification_security_test.dart` 7/7 | 7/7 passed | TRUE |
| `election_security_test.dart` 32/32 | 32/32 passed | TRUE |
| `widget_test.dart` 262/262 | 262/262 passed | TRUE |

## TRUE — verified done

- **G1 (core):** `awardVerifiedGamificationPoints` ([auth_service.dart:3986-4049](../lib/services/auth_service.dart)) — live-mode transaction failure returns `success: false, pointsAwarded: 0`; cache writes moved after the live attempt (:4041-4043). Student awards now **truthfully fail** in live mode (rules still deny students — the real fix remains the Blaze callable, D4).
- **G2:** both hardcoded literals gone (grep confirms zero occurrences in `lib/` + `test/`); fail-closed getters `GAMIFICATION_HMAC_SECRET` / `SPORTS_CERT_SECRET` with `@visibleForTesting` injection match the election A1/A2 pattern.
- **G3 (core):** `isValidHousePoints` ([firestore.rules:523-534](../firestore.rules)) — doc-ID/house match, int 0..1,000,000, field whitelist; sports-leader updates bounded to −100..+500 per write (:835-843); trophy clamps 100/50 (auth_service:5842-5843), accolade clamp 50 (:5974).
- **G5:** Blitz routes through `awardVerifiedGamificationPoints` with a score-proof token, score clamped to ceiling 50, confetti gated on confirmed success ([house_arena_screen.dart:494-521](../lib/screens/house_arena_screen.dart)); direct batch writes deleted.
- **G9:** `submitHouseClaim` rethrows in live mode (auth_service:3382-3384); `awardMatchMvp` returns false on live failure (:5720-5723); `awardPlayerAccoladeCustom` returns false on live failure (:6005-6010); accolade snackbar gated on `success` ([sports_tournament_screen.dart:1257-1271](../lib/screens/sports_tournament_screen.dart)); merit announcement gated on `success` ([academics_screen.dart:4261-4269](../lib/screens/academics_screen.dart)).
- **G11 (claims half):** `points` + `house_name` added to immutable claim fields (firestore.rules:710).

## PARTIAL — done in part, remainder open

### P-1. G7 — contributor unification (roadmap marked [x], overclaimed)
Done: award service writes `house_contributors/{scholarNo}` with create-on-award (auth_service:3990-4027). **Not done:**
- **No merge migration** of legacy `{house}_{scholarNo}` docs — no migration code exists anywhere in `lib/` (grep verified). Old-scheme docs, if any exist in production, are orphaned.
- **`users.points_contributed` is not derived/updated** by the award path (the old Blitz direct write was deleted, nothing replaced it).
- Create-on-award fabricates placeholder identity: `'student_name': 'Scholar $sNo'`, `'class_level': 'Senior Tier'` (auth_service:3997-3999) — the real name/class are available from the caller/session and should be used.
**Solution:** one-time migration merging `{house}_{sNo}` → `{sNo}` (sum totals, keep max merits); pass real student name/class into the award API; increment `users.points_contributed` in the same transaction (admin path) or derive it from the contributor doc on read.

### P-2. G1 — demo/offline labeling (roadmap sub-item, not done)
Demo mode still returns `success: true, pointsAwarded: points` with no demo flag (auth_service:4045-4049). The roadmap item explicitly included "label offline/demo states".
**Solution:** add `isDemo: true` (or `error: 'Demo mode — not persisted'` semantics) to the award result when `!_isFirebaseLive`, and badge demo points in the UI.

### P-3. G3 — residuals after the validator
- **Phantom fifth house:** `isValidHousePoints` accepts `'pearl'` (firestore.rules:524) — see FALSE below.
- **Repeated-drain griefing:** a sports lead can apply −100 to **any house** (no house-scope check), unlimited times. Per-write bounds ≠ cumulative bounds.
- **`house_contributors` still has no validator** — bare `allow write: if isAdmin()` (firestore.rules:847-850); any admin-path bug can write arbitrary fields/totals.
**Solution:** remove `pearl`; scope sports-lead writes to their own house or make negatives admin-only; add `isValidHouseContributor` (scholar_no/doc-ID match, non-negative ints, field whitelist).

## FALSE — roadmap closures that are not true

### F-1. G8 marked [x] — only constant-time compares were done
The roadmap closure says "drop raw-JSON token fallback; explicit replay stance". **Neither happened:**
- Raw-JSON fallback still present verbatim: [gamification_security_service.dart:172-191](../lib/services/gamification_security_service.dart) ("In case raw JSON string was passed instead of base64Url").
- Nonce is still never consumed — token replay within the 5-minute window remains possible (G8 core).
**Solution:** delete the raw-JSON catch branch; track consumed nonces (per scholar+activity, prefs interim / Firestore server-side with Blaze); keep the constant-time compares (done correctly). Reopen G8 until then.

### F-2. G11 marked [x] — award idempotency NOT done
The roadmap closure says "Content-derived award IDs (idempotency)". The trophy ID is **still timestamp-based**: `'trophy_${sportType.name}_${now.millisecondsSinceEpoch}'` ([auth_service.dart:5844](../lib/services/auth_service.dart)). Re-submitting the same final creates a new trophy and awards points again.
**Solution:** derive the ID from content (e.g. `trophy_{sport}_{tournamentTitle}_{winningHouse}_{runnerUp}` normalized, or a hash of the final payload); transaction `get` + abort if exists. Only the claims-immutability half of G11 is closed.

## FALSE — report detail

### F-3. "pearl" is not a house
The report lists valid houses as "ruby, sapphire, emerald, topaz, **pearl**". The app has exactly four houses; `pearl` appears **nowhere** except the new rules line (grep verified). `isValidHouseClaim` (firestore.rules:380) correctly lists only the four. A phantom house in the points validator is inconsistent and would let an admin-path bug create a `house_points/pearl` doc that no screen displays.
**Solution:** delete `'pearl'` from firestore.rules:524; redeploy rules.

## UNVERIFIED — deployment claim

### U-1. "Deployed and active on Cloud Firestore via firebase deploy --only firestore:rules"
Cannot be confirmed from this machine: no `firebase-debug.log` exists in the repo; the gcloud account lacks IAM permission to read the released ruleset (Rules API returns 403); firebase CLI v15 has no `firestore:rules:get` command. The **local rules file** is verified as described above — the **release** is not.
**Solution:** verify in Firebase Console → Firestore → Rules (compare the published source against the repo file, check the release timestamp), or simply re-run `firebase deploy --only firestore:rules` and keep the output. Until then treat "deployed" as unconfirmed.

## Closure rule

Same as elections: an item is done only when its "Done when" passes with evidence. G8 and G11 are **reopened** (partial). G7 remains open for migration + derivation. The council-roster privilege requirement is tracked separately in [COUNCIL_PRIVILEGES.md](COUNCIL_PRIVILEGES.md) and must be folded into P1 (G4 gating) before implementation.