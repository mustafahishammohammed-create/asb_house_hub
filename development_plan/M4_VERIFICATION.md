# M4 verification — house communication groups (tests 39–49)

**Date:** 2026-11-08
**Branch:** `mustafa1` (M4 work is the commit following this document)
**Method:** read of `house_group.dart`, `house_group_service.dart`, `house_group_screen.dart`, `home_screen.dart`, `hierarchy_service.dart`, `firestore.rules`; targeted M4 suite; full suite; `flutter analyze`; rules deployment output.
**Verdict:** M4 is **done for its stated Spark scope**. Membership is derived from the verified profile house, the Firestore rules enforce same-house read and leader/staff-only send, students and prefects are read-only, and tests 39–49 pass. Message attachments are Firestore data-URL fields (not Storage uploads), and house announcements do not fan out notifications until M6/test 61.

## Delivered

| Area | Status | Evidence |
|---|---|---|
| **Test 39 — auto-join on verified house** | ✅ **DONE** | `HouseGroupAccess.resolveHouse` normalises the profile's `house_name` to `ruby`/`sapphire`/`emerald`/`topaz`; opening `HouseGroupScreen` resolves the group with no join button and no membership write. `HouseGroup.defaultsFor('ruby')` produces **Ruby House Group**. |
| **Tests 40 / 48 — cross-house isolation** | ✅ **DONE (client + rules)** | `HouseGroupAccess.canView` requires same house (senior admins excepted). Rules `isSameHouse(houseId)` compares `users/{uid}.house_name` to the path house for both the group header and its messages, so a Ruby student cannot read Sapphire data even with a direct Firestore call. |
| **Test 41 — students and prefects cannot send** | ✅ **DONE** | Client `HouseGroupAccess.isAuthorizedSender` is deliberately `isSuperAdmin || isTeacherOrFaculty || isCaptain || isCouncil` and therefore excludes `HierarchyService.isAdmin()`'s prefect branch. Rules `isHouseSender` uses the rules-side `isAdmin`/`isCaptain`/`isCouncil` helpers, which never included prefects. |
| **Test 42 — students cannot attach** | ✅ **DONE** | The composer (including the attachment button) is only built when `HouseGroupAccess.canSend` is true. Rules accept `attachment_url` only inside a message create that already passes `isHouseSender(houseId)`, so a student cannot write an attachment document directly. |
| **Tests 43–46 — leader send roles** | ✅ **DONE** | House captain, vice-captain/house vice-captain (`isCaptain`), sports captain/vice, head boy/girl, and other council officers (`isCouncil`) can send in their own house only. The rules role whitelist now accepts `head_boy`, `head_girl`, `deputy_head_*`, `head_of_activities`, `cultural_secretary`, and `executive_council`. |
| **Test 47 — staff send** | ✅ **DONE** | Super admin, teacher, faculty, principal, staff, `faculty_advisor`, and `teacher_lead` pass the client policy and the rules helpers. |
| **Test 49 — transfer revokes/grants** | ✅ **DONE** | Membership is never stored; both client and rules read the live profile house. Changing `house_name` Ruby → Sapphire immediately hides Ruby and opens Sapphire, while `cacheProfile` preserves `class_id` (`11D` in the test) so a house transfer never changes the academic class. |
| **Categories** | ✅ **DONE** | Closed set `general`, `announcement`, `event`, `sports`; invalid values normalise to `general` in the model, service, UI, and rules validator. The UI offers filter chips and a sender-only category selector. |
| **Pin / moderate (tests 39–49 supporting scope)** | ✅ **DONE** | Moderators (same-house senders or senior admins) can pin, unpin, hide, unhide, and delete. Rules limit message updates to `is_pinned`, `is_hidden`, `moderated_by`, `moderated_at`; message text and authorship are immutable. Hidden messages are filtered for non-moderators. |
| **Rules** | ✅ **DEPLOYED** | `house_groups/{houseId}` and `house_groups/{houseId}/messages/{messageId}` matchers, `isSameHouse`, `isHouseSender`, `isHouseModerator`, `isValidHouseGroup`, `isValidHouseGroupMessage`; compiled and released to `cloud.firestore`. |
| **Truthful writes** | ✅ **DONE** | `sendHouseMessage`, `ensureHouseGroup`, pin/hide, and delete return `false` for unauthorised users, offline runtimes, simulated failures, and real Firestore denials. The UI shows a failure snackbar and does not clear the draft on failure. |
| **UI entry points** | ✅ **DONE** | Home action card **🏠 My House Group**, a drawer tile, and a `HouseGroupScreen` with auto-join banner, read-only banner, category filters, composer gating, attachment preview, moderation menu, and a dedicated access-denied state. |

## Test evidence

`test/house_group_test.dart` — **37/37 passing**, in six groups:

- **M4a** (10): auto-join/defaults (39), same-house read (40), student/prefect denial (41), attachment denial (42), captain own-house send (43), vice-captain (44), sports captain/vice (45), head boy/girl (46), staff/faculty (47), unknown/missing house.
- **M4b** (3): cross-house isolation (48), transfer revokes/grants without changing class (49), senior-admin view/moderate but not send.
- **M4c** (4): Firestore-shaped round-trip, invalid category normalisation, attachment-only preview, group defaults/`copyWith`.
- **M4d** (6): student send denied before any write; denied teacher send is truthful; student moderation/delete denied; denied leader moderation is truthful; offline reads return empty streams; students cannot bootstrap the header.
- **M4e** (6): rules source contract for profile-derived membership, sender helper, read/create isolation, attachment/category validator, pin/hide/delete limitation, and the extended role whitelist.
- **M4f** (8): student read-only UI, captain composer/attachment, staff composer, cross-house access denial, transfer opens the new group, pinned/hidden rendering, hidden filtering for students, category filters.

Commands run:

- `flutter test test/house_group_test.dart` → **37/37**
- `flutter test` → **500/500**
- `flutter analyze` → **0 errors, 0 warnings**, 20 pre-existing infos (unnecessary underscores and `print` in `tool/`)
- `firebase.cmd deploy --only firestore:rules` → **compiled and released**

## Honest limits / follow-ups

1. **Rules tests remain source-contract assertions.** No Firebase emulator harness was added, matching M2/M3. Real denial behaviour is enforced by the deployed rules helpers and mirrored by pure client-policy tests.
2. **Attachments are Firestore data-URL strings, not Storage objects.** `attachment_url` is capped at 900,000 characters and populated from the existing compressed image picker. This avoids new Storage rules but is not a scalable media pipeline; move to Storage + Blaze when available.
3. **No notification fan-out.** House announcements do not write `users/{uid}/notifications` docs yet; M6/test 61 owns recipient fan-out and unread badges.
4. **Message stream is capped at the newest 200.** Adequate for Spark; pagination is a later scaling concern.
5. **Group header is optional.** Students auto-join from the profile without a header document; only authorised senders can bootstrap the header. A house with no header still renders the default name and the read-only feed.
6. **Senior admins can view/moderate across houses but cannot send into another house.** Sending always requires same-house membership, matching the rules.
7. **Moderation/delete are hard deletes.** There is no tombstone or audit collection; `moderated_by`/`moderated_at` record pin/hide actions only.

## Handoff

Next module: **M5 — class groups & academic communication** per `REMAINING_MODULES_REPORT.md`. Reuse the M4 group machinery, keep M6 notification fan-out on the follow-up list, and do not regress elections, points, sports, wallet, merch, ID scanner, behavior, 1:1 chat, account switching, A1–A6/A8, photo upload, or timetable features.
