# Teacher permissions and class roster repair — 28 November 2026

Version: 1.0.2+3. This report supersedes the earlier broad teacher/administrator access descriptions for these features.

## Delivered behavior

- Administration has a visible **Class students** entry. Every class has **View students** in its action menu; tapping the class opens its roster. Rosters show names, scholar numbers, verification/account status and student count, including inactive sections. Live placements take priority over stale saved-account data.
- Teacher assignment now selects a registered account instead of only saving a name. The class teacher name and UID are saved together; subject teachers are selected by account. Updating assignments does not reassign student placements. Name-only legacy assignments must be linked to an account using **Edit class teacher**.
- Teachers have a **Teacher Workspace**, their assigned class groups, and **1-on-1 Chats**. They can start private conversations with students and other teachers. The directory is no longer truncated at 200 users.
- Teachers cannot review/approve/reject point claims, edit the class registry, move students or use academic-administration controls. These restrictions are enforced by Firestore, not only hidden buttons. Existing management/council/house-captain claim permissions remain.
- Class and subject teachers can message only groups where administration assigned their UID. A teacher's old student placement does not grant another class's group access. Revoked group access clears the visible feed; switching groups clears the draft and attachment.
- New medical reports are bound to the student's verified class when submitted. Only the owner, that class's currently assigned class teacher, and senior management (administrator, principal, head, management and equivalent existing roles) can read them. Subject teachers, unrelated teachers, council officers and other pupils are denied.
- Medical lists use server-scoped queries. Reports are not written into the shared live fallback cache; cached-only responses are suppressed, legacy shared cache is removed, and local/demo caches are isolated by account. Errors do not restore previously visible medical data.
- Private chats have immutable participant lists. Teachers cannot add themselves to other people's chats or edit/delete their messages. Notification previews are readable only by their recipient; class/chat notification creation remains scope-bound.
- Medical forms retain entered text after failed saves, block repeated submission taps, explain who receives the report and enforce the existing 500,000-character attachment limit. Optional null fields are omitted on new submissions; prior null fields remain compatible. Medical report cards and class selection were checked at 360px width and repaired to wrap correctly.

## Validation

- Full Flutter suite: **759 passed**, zero failed.
- Static analysis: **no issues**.
- Firestore/Storage emulator suite: **32 passed**, zero failed. Positive and negative cases cover report creation/query/review, reassignment revocation, legacy reports, teacher claim denial, registry/placement tampering, class-group posting and private chats.
- Live Firestore rules and the new medical class/submitted-time index deployed. Exact rule hash is recorded in `logs/live-verification.json`; all eight deployed indexes are READY and match the local index definitions.

## Compatibility and limits

Existing medical reports without a trusted class ID remain available to their owner and senior management only. No medical/student records were rewritten to guess their class. Student class placement must be verified before submitting a new report. Reports are scoped to the class they were submitted to, with access following that class's current teacher assignment.

Existing grade-wide academic content and the school's other unrelated role policies were not migrated in this change. Existing PDF medical attachments still use the pre-existing image-oriented preview; a full PDF viewer is a separate outstanding issue. Physical Android-device testing and signed-in Windows interactive testing were not performed; automated UI and backend tests are the validation evidence.

The signed universal APK and Windows ZIP were rebuilt from source commit `52c21f9` as version **1.0.2+3**. APK signature verification passed with the existing release key. All 22 Windows runtime files match the build. The new account-selector marker is present in every APK architecture and the Windows Dart payload. Hashes are recorded in `release.json`. Older split APKs, debug APK and Play Store bundle are not part of this release.
