# ASB House Hub — Project Problem Register

**Date:** 2026-11-09
**Branch:** `mustafa1` (baseline `15aa7c3`)
**Method:** first-hand inspection of `lib/**`, `firestore.rules`, tests, release artifacts, and the module reports. No issue is listed without a concrete file/line or reproducible command.
**Scope rule:** Spark-only. No Cloud Functions, no server fan-out, no FCM. All fixes must preserve elections, points, sports, wallet, merch, ID scanner, behavior, 1:1 chat, account switching, A1–A6/A8, photo upload, timetable, M4 house groups, M5 class groups, and M7 admin flows.

## Severity

| Level | Meaning |
|---|---|
| **P0** | Authorization bypass or a required module is visibly missing. Fix first. |
| **P1** | Security/reliability weakness with a credible path to wrong data, privilege abuse, or lost user trust. |
| **P2** | Truthfulness, documentation, test coverage, or release hygiene. Does not block daily use. |
| **P3** | Cosmetic/residual risk to document, not worth destabilizing the app now. |

## Register

| ID | Severity | Area | Problem | Status |
|---|---|---|---|---|
| P0-01 | P0 | Security / rules | `isSuperAdmin()` accepts any email matching `(?i)^admin@.*` or `(?i)^11209@.*`; any self-registered account with such an email becomes admin. | **FIXED** |
| P0-02 | P0 | M8 dashboard | Dashboard has no today/current/next/break timetable, no verified-class badge, no class-teacher field, no class/house unread counts, no younger-student simplification, and only partial responsiveness. | **FIXED** |
| P1-01 | P1 | Security / secrets | Production fallback secrets are hardcoded in client binaries (`ELECTION_HMAC_SALT`, `VAULT_SECRET`, `GAMIFICATION_HMAC_SECRET`, `SPORTS_CERT_SECRET`). | **RESIDUAL — documented, requires deployment decision** |
| P1-02 | P1 | M8 data scoping | Dashboard must never read/display another class's timetable. No verified-class gate existed because the dashboard had no timetable at all. | **FIXED** (with P0-02) |
| P1-03 | P1 | Reliability | Silent `catch (_) {}` blocks exist across services. M6/M7 write paths are hardened; remaining blocks are cache/log/UI best-effort. High-impact send/moderate paths already return truthful booleans. | **REVIEWED — no further change required** |
| P1-04 | P1 | Security / rules | `timetable_versions` read rules allow broad signed-in reads of published versions, and Firestore list-query rules cannot field-scope by `class_id`; a modified client can query beyond its own class even though the UI does not. | **OPEN — documented in ACCEPTANCE_MATRIX test 5; path-scoped migration required** |
| P2-01 | P2 | Documentation | `MASTER_GAP_ANALYSIS.md` sections 1, 2, and 6 still claim academic/timetable/admin work is partial or missing despite M1–M7 delivery. | **FIXED** |
| P2-02 | P2 | Documentation | No `M8_VERIFICATION.md`; M8 is still marked partial in `REMAINING_MODULES_REPORT.md`. | **FIXED** |
| P2-03 | P2 | Testing | No single §11 acceptance matrix covering tests 1–64 across roles × UI × backend/rules. | **FIXED** (matrix + enforceable harness; honest gaps recorded) |
| P2-04 | P2 | Release hygiene | Release `data\app.so` predates M7 commit `15aa7c3`; the desktop launcher runs a stale binary. | **FIXED** (rebuilt at end of this batch) |
| P3-01 | P3 | Rules testing | Rules verification remains source-contract assertions; no Firebase emulator suite. Consistent with M1–M7, documented in every verification file. | **DOCUMENTED** |
| P3-02 | P3 | Spark limits | Client-side fan-out, roster cap 500, batch size 400, stream cap 100, sequential promotion, no FCM, no token revocation. Documented in M6/M7/M8 verification. | **DOCUMENTED** |

---

## P0-01 — Super-admin email regex bypass

**Evidence:** `firestore.rules:251-267`

```
request.auth.token.email.matches('(?i)^admin@.*') ||
request.auth.token.email.matches('(?i)^11209@.*')
```

The exact bootstrap emails `admin@asianschool.bh` and `11209@asianschool.bh` are already whitelisted on line 257. The two regexes add no legitimate account; they only widen the gate to `admin.anything@...` and `11209.anything@...`.

**Impact:** A user who can create a Firebase Auth account with an email beginning `admin@` or `11209@` receives `isSuperAdmin()` and therefore write access to users, academic classes, timetable audits, admin roster, and all administrative collections.

**Fix:** Delete the two regex clauses. Keep the exact bootstrap emails. Keep token-claim, `admin_roster`, `users.role`, and `school_members.role` checks.

**Verification:** rules compile; add source-contract assertions that the regexes are absent and the exact emails remain; deploy to `cloud.firestore`.

---

## P0-02 / P1-02 — M8 dashboard missing and class scoping

**Evidence:**

- `lib/screens/home_screen.dart` has no reference to `ClassTimetableVersion`, `getActiveTimetableStream`, `TimetablePeriod`, `class_verified`, or `class_teacher`.
- Dashboard body starts at `home_screen.dart:1627`; hero card at `:2350` shows house, scholar number, name, class label, and points only.
- `REMAINING_MODULES_REPORT.md:236-253` lists the M8 requirements as partial.

**Required behavior:**

1. Today's eight teaching periods, current period, next period, and the 30-minute break come from the **published** section timetable.
2. Verified-class badge and class-teacher name on the dashboard/profile.
3. Unread class and house announcement counts.
4. Younger students (LKG–UKG and primary) get a simpler dashboard with no admin/council clutter.
5. Responsive desktop/laptop/tablet/mobile layout.
6. Only the profile's verified `class_id` may be queried. An unverified profile must render a truthful "not verified" state, not another class's schedule.

**Fix:** Add `M8DashboardCard`-style widgets inside `home_screen.dart` (kept local to avoid destabilizing other screens), a `NotificationUnreadBreakdown` helper and stream in `notification_service.dart`, a cached `AcademicClass` lookup for class-teacher display, a periodic clock refresh, and width-aware layout constraints. Add widget/unit tests with a fixed clock.

**Verification:** targeted dashboard tests, full suite, analyzer, rules compile, release rebuild.

---

## P1-01 — Hardcoded production fallback secrets (residual)

**Evidence:**

- `lib/services/election_security_service.dart:16-24` returns `asb_house_hub_election_salt_production_2026` when `ELECTION_HMAC_SALT` and the test override are absent.
- `lib/services/auth_service.dart:53-61` returns `asb_house_hub_vault_secret_production_2026` when `VAULT_SECRET` and the test override are absent.
- `lib/services/gamification_security_service.dart:63-78` and `lib/services/sports_security_service.dart:19-34` use the same pattern.

**Why this is not silently "fixed":** these values are compiled into the client. Removing them without supplying `--dart-define` values would break account switching (vault decryption), election receipts, gamification signatures, and sports certification in the live desktop build. Replacing them with random per-install keys would invalidate existing encrypted credentials and previously issued signatures/receipts.

**Decision required at go-live:** build release binaries with all four `--dart-define` values and treat the fallbacks as development-only. The app's own release reminder already says this (`REMAINING_MODULES_REPORT.md:293`). Until then this is a documented residual risk, not a phantom fix.

---

## P1-03 — Silent catches review

**Evidence:** `Select-String -Path lib\services\*.dart -Pattern 'catch \(_\) \{\s*\}'` returns ~115 hits, concentrated in `auth_service.dart` preference/cache hydration, `chat_service.dart`, `class_group_service.dart`, `house_group_service.dart`, `gemini_ai_service.dart`, `timetable_service.dart`, and `qr_decoder_service.dart`.

**Review result:**

- M6 fan-out and M7 admin writes no longer swallow live write failures; they return truthful results.
- `ClassGroupService.sendMessage` and `HouseGroupService.sendMessage` commit the primary message first and treat summary/notification writes as best-effort; the boolean reflects the primary write.
- The remaining empty catches are preference reads, optional profile enrichment, cache hydration, animation/audio plumbing, and UI fallbacks. Converting all of them to thrown errors would destabilize screens for no data-integrity gain.
- New M8 code must not add empty catches around the timetable/profile/notification reads; it must render an explicit unavailable/empty state.

**Status:** reviewed; no blanket rewrite. Any future write-path catch must either return `false`/an error result or be explicitly commented as best-effort.

---

## P1-04 — Timetable cross-class read scoping (open)

**Evidence:** `firestore.rules:1259-1265`.

```
allow read: if isSeniorAdmin() ||
  (isSignedIn() && resource != null && resource.data.status == 'published') ||
  (isSignedIn() && hasUserDoc() && 'class_id' in getUserData() &&
    (resource == null || resource.data.class_id == getUserData().class_id) &&
    (resource == null || resource.data.status == 'published' || isTimetableEditor(resource.data.class_id))) ||
  (resource != null && isTimetableEditor(resource.data.class_id));
```

**Impact:** the M8 dashboard and student timetable only query the verified profile class, so the normal UI satisfies test 5. However, a modified client can read another class's published timetable because the second clause accepts any signed-in user, and the `resource == null` branches make a collection list query pass without a class filter. Firestore rules cannot inspect a query's `where` clauses, so this cannot be fixed by editing the existing expression alone.

**Why it was not "fixed" in M8:** a real fix changes the data layout — timetables must live under a path-scoped per-class collection (or a per-class active-timetable document with `get`-only student access and staff-only `list`). That is a schema/service/rules migration, not a dashboard polish, and doing it mid-acceptance would risk the M2/M3 timetable flows. It is recorded as an open P1, and `ACCEPTANCE_MATRIX.md` marks test 5 **PARTIAL**, not passing.

**Decision required:** perform the path-scoped timetable migration before claiming strict backend cross-class denial.

---

## P2-01 — Stale master gap analysis

**Evidence:** `development_plan/MASTER_GAP_ANALYSIS.md:11-17` says academic classification is partial/conflicting; `:44-47` says the entire Admin Command Center is missing; the baseline line still points at `1f426c2`.

**Fix:** Rewrite the header, section 1, section 2, and section 6 to reflect M1–M7 delivery, link the verification files, and keep only genuinely open gaps (M8 dashboard/acceptance, Blaze-deferred items).

---

## P2-02 — M8 documentation

**Fix:** Add `development_plan/M8_VERIFICATION.md` with the delivered dashboard/profile behavior, exact commands and counts, honest limits, and the M8 acceptance mapping. Update the module table and M8 section in `REMAINING_MODULES_REPORT.md`.

---

## P2-03 — §11 acceptance matrix

**Evidence:** no `test/acceptance_matrix_test.dart`; no single table mapping tests 1–64 to UI, backend/rules, and role coverage.

**Fix:**

1. Add `development_plan/ACCEPTANCE_MATRIX.md` with one row per test (1–64): requirement, implementation, UI evidence, backend/rules evidence, automated test, status.
2. Add `test/acceptance_matrix_test.dart` that:
   - asserts the matrix contains exactly 64 rows and all IDs 1–64;
   - asserts every referenced test file exists;
   - asserts the key rules contracts still exist (admin gate, class scoping, published timetable read, append-only audit, notification ownership, user field immutability);
   - asserts no unresolved `PARTIAL`/`MISSING` status is silently counted as done.
3. Do **not** claim a test is covered when the only evidence is a source assertion. Mark those rows `PARTIAL (source contract)` in the matrix.

---

## P2-04 — Stale release binary

**Evidence:** `build\windows\x64\runner\Release\data\app.so` timestamp `2026-11-09 13:22:39`; commit `15aa7c3` was created after that build.

**Fix:** After the final green suite, run `flutter build windows --release` (with the same secret strategy already used for the current desktop build), confirm the `app.so` timestamp is newer than the last commit, and record the path/timestamp in `M8_VERIFICATION.md`.

---

## P3-01 / P3-02 — Documented limits

These are not defects to code around on Spark. They stay in the verification files:

- No Cloud Functions/FCM; notifications are client-side fan-out into `users/{uid}/notifications`.
- Roster lookups cap at 500; fan-out batches at 400; notification stream caps at 100.
- Batch promotion is sequential; audit writes are best-effort; approval-queue fallback can be stale.
- Suspension removes UI access but does not revoke an already-issued Firebase Auth token.
- Rules tests are source contracts, not emulator executions.

---

## Fix order

1. **P0-01** rules regex (small, security-critical).
2. **P0-02 / P1-02** M8 dashboard + profile + unread breakdown + younger UI + responsiveness.
3. **P2-03** acceptance matrix and harness.
4. **P2-01 / P2-02** documentation truth pass.
5. Full suite, analyzer, rules deploy, **P2-04** release rebuild, commit and push.

## Verification log — 2026-11-09 M8/P0 batch

All counts below are from actual command output, not estimates.

| Check | Result |
|---|---|
| `flutter test test/dashboard_profile_test.dart` | **6/6 passed** |
| `flutter test test/teacher_timetable_editor_test.dart` | **12/12 passed** (new moving-break test included) |
| `flutter test test/acceptance_matrix_test.dart` | **6/6 passed** |
| Targeted combined run (dashboard + editor + matrix) | **24/24 passed** |
| `flutter test` (full suite) | **638/638 passed** |
| `flutter analyze --no-pub` | **No issues found** |
| `firebase.cmd deploy --only firestore:rules` | **compiled successfully; released to `cloud.firestore`** |
| `flutter build windows --release` | **built**; `app.so` 13,239,176 bytes at `2026-11-09 14:14:16` (previous stale build `13:22:39`) |

Acceptance matrix result: **60 PASS · 4 PARTIAL · 0 MISSING**. Partials 5, 22, 24, 25 are not counted as done; see `ACCEPTANCE_MATRIX.md`.

Status updates from this batch:

- **P0-01 FIXED** — prefix regexes removed from `isSuperAdmin()`, exact bootstrap emails retained, absence asserted in `test/widget_test.dart`; rules compiled and deployed.
- **P0-02 / P1-02 FIXED** — dashboard/profile delivered; unverified classes never render a timetable.
- **P1-04 OPEN** — timetable cross-class rules scoping; documented in the matrix and above. Requires a path-scoped migration.
- **P1-01 RESIDUAL** — release built with development fallback secrets; production must supply all four `--dart-define` values.
- **P2-01 / P2-02 FIXED** — master gap analysis and remaining-modules report corrected; `M8_VERIFICATION.md` added.
- **P2-03 FIXED** — 64-row matrix + enforceable harness; honest partials recorded.
- **P2-04 FIXED** — release `app.so` rebuilt after all source edits.
- **P3-01 / P3-02 DOCUMENTED** — source-contract rules tests and Spark caps remain explicit limits.
