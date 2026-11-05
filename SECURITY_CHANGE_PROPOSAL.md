# ASB House Hub — security, identity and privacy changes for review

This companion is a static review of the checked-in rules, Functions and Flutter callers. Paths and line numbers refer to this checkout. A production Firebase ruleset, real roster and school devices were outside the review. The following blocks are proposed changes for a future branch. Replacing isolated rules while the old screens still write directly will break those screens. Prepare and test the matching readers, writers and data migration together.

## Where the current code loses trust

| Priority | Confirmed path | What a user could observe or do | First change |
|---|---|---|---|
| Critical | firestore.rules 196–232, 537–570; lib/services/auth_service.dart 2237–2267 | A valid self-created profile may request teacher, staff or sports lead. Staff roles unlock administrative rules. A reserved email string also grants super-admin without checking the verified flag. The admin login tries creating that account when Auth specifically reports user-not-found. Actual impact depends on the deployed rules and whether the reserved account exists. | School-provisioned membership keyed by Firebase UID. Only a backend with the appropriate IAM permissions can write it. Remove email, scholar number, cached fields and client profile role from the authority chain. |
| Critical | storage.rules 22–32, 55–56; functions/index.js 25–66, 132–163 | A signed-in client can upload under a house path carrying another scholar and claim ID. The privileged trigger derives the target document and owner from the supplied filename and merge-writes that document. Replaying an event can also change a staff decision. | Require a pre-existing owner-bound upload slot, immutable bytes and an exact object-path match. Store a separate OCR hint only while the decision is pending. |
| High | firestore.rules 537–539, 611–624, 750–770, 831–845; storage.rules 54–56 | A signed-in account can read other pupils' full profiles, class reports, chats and uploaded evidence. A recursive class allow opens attendance despite the owner check in the specific matcher. Pending wall photos are visible through direct reads. | Remove the broad allows. Scope each reader and query, including room participants, date/class access, attachment paths and published-only feeds. |
| High | lib/services/auth_service.dart 35–57, 159–201, 1881–1891, 2042–2067, 2330–2399; lib/screens/home_screen.dart 306–310 | A reversible password is stored with each saved account. Switching changes the cached student first, catches failed login and the screen still navigates to that student. A profile read can return the last cached profile on failure. | Keep only account-picker metadata. Freshly authenticate, check UID and active membership, then load that UID's state. |
| High | lib/services/chat_service.dart 17–27, 73–95, 110–141, 237–304; firestore.rules 575–581, 750–771 | A peer cannot be trusted to label themselves “admin”, create private rooms or insert inbox notifications for other people. The picker converts canonical roles to display text before an authority check. A message, unread count and notification are separate writes. | Move room creation and delivery to validated, idempotent server operations and use membership-based read rules. |
| High | lib/services/auth_service.dart 1311–1345, 1575–1603, 1858–1877; lib/services/gemini_ai_service.dart 39–49, 103–136, 272–304 | A shared-device fallback may show another student's reports or attendance. The AI builds a prompt containing a scholar identifier and attendance, stores a provider key in preferences and falls back to a concrete scholar number when identity is missing. | Keep private cache per UID or in memory. Exclude student identifiers from AI by default. Make a missing roster identity an explicit unlinked-account state. |
| High | lib/services/election_security_service.dart 6–34, sports_security_service.dart 17–25, gamification_security_service.dart 54–62, voucher_security_service.dart 220–235 | Proofs minted using material bundled in Flutter can be reproduced outside the UI. A QR image or token can be copied. | Authenticate the caller, derive values from server records, transact one-time redemption, and authorize the exact action. Never use a client-produced proof to grant points, spend money or publish an official result. |
| Medium | firestore.rules 266, 334, 497, 516 | Four validators call a Dart/JavaScript-style toLowerCase(). The Firebase Rules String API defines lower(). A validator that cannot evaluate successfully can deny intended writes. | In those Firestore validators use data.house_name.lower(), or store lowercase canonical names and validate exact values. Compile and exercise all four writes in the emulator. [Firebase Rules String](https://firebase.google.com/docs/reference/rules/rules.String) |

## 1. Provision and enforce school membership

Use the same proposed collection as the election implementation. A school-controlled import binds the verified school roster to Firebase Auth UIDs. An Auth account alone represents a login. A student needs an active linked membership to access school data. Require an administrator to resolve duplicate scholar numbers, stale links and existing email accounts before binding. Public signup should use a single-use invitation or a school identity provider, with server-side verification of ownership. For a lost password, use only an actual reachable verified school identity or a staffed recovery process.

Suggested school_members/{uid} fields are active, role, scholar_no, display_name, class_id, grade, house and capabilities. Keep grade as integer 1–12 and house lowercase. Example capabilities are manage_elections, manage_access, reviewHouseClaims, moderate_wall and can_receive_student_chat. Scope teachers through their assigned classes. Store capabilities separately from elected titles so student office holders can still be eligible voters according to the school’s policy. Provision access for at least one independently verified school administrator before switching over. Do not import privileges from existing self-authored profile documents.

**Firestore integration.** Inside the existing database match add the membership helper and these replacement paths. Replace the old users/notifications block. Deny all legacy chats reads/writes at cutover. Stage verified histories into chats_v2 before directing clients to that collection. Update every role helper and every other signed-in-only school-data rule to require an active member and the relevant capability or resource ownership. Replace broad legacy profile queries used by the leaderboard, profile picker and chat with designated minimal projections. Return public class rankings via a school-approved display alias. The basic directory below is for currently allowed chat contacts only. A server-created staff directory can serve staff search under separate staff-only rules if needed.

~~~text
function signedMember() {
  return request.auth != null &&
    exists(/databases/$(database)/documents/school_members/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.active == true;
}
function me() {
  return get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data;
}
function cap(name) {
  return signedMember() && me().get('capabilities', {}).get(name, false) == true;
}
function ownsScholar(scholar) {
  return signedMember() && me().scholar_no == scholar;
}
match /school_members/{uid} {
  allow get: if request.auth != null && request.auth.uid == uid;
  allow list, write: if false;
}
match /chat_contacts/{uid} {
  allow read: if signedMember();
  allow write: if false;
}
match /users/{uid} {
  allow get: if signedMember() && request.auth.uid == uid;
  allow list, write: if false;
  match /notifications/{notice} {
    allow read: if signedMember() && request.auth.uid == uid;
    allow update: if signedMember() && request.auth.uid == uid &&
      request.resource.data.diff(resource.data).affectedKeys().hasOnly(['is_read']) &&
      request.resource.data.is_read == true;
    allow delete: if signedMember() && request.auth.uid == uid;
    allow create: if false;
  }
}
match /chats_v2/{room} {
  allow read: if signedMember() && request.auth.uid in resource.data.participants;
  allow write: if false;
  match /messages/{message} {
    allow read: if signedMember() && request.auth.uid in
      get(/databases/$(database)/documents/chats_v2/$(room)).data.participants;
    allow write: if false;
  }
}
~~~

A trusted provisioning job should create the private profile and membership. Use a narrowly validated callable for editable personal preferences or avatars. Update signUp and getUserProfile at the same time. Retire client role promotion, arbitrary directory scans and reads of student records from the public wall. For classes, remove the recursive matching block in lines 621–624. Replace the read on each timetable, assignment and exam with class membership or assignment to teach that class. Allow a report/attendance read only to its owning student, the assigned teacher with an appropriate capability, or an authorized records administrator. Use a separate owner UID field on each migrated private document and query on it. A new deny rule cannot override an overlapping allow. Firestore requires a query whose results all satisfy the rules. [Firebase rules structure](https://firebase.google.com/docs/firestore/security/rules-structure) · [Firebase query security](https://firebase.google.com/docs/firestore/security/rules-query)

## 2. Stop switching into a cached identity

**Replacement inside AuthService.** The following block is intended for fresh sign-in flows. Use one account transition at a time. The caller must show a session-loading gate across sign-in, membership resolution and profile loading. Successful Firebase sign-in immediately emits an auth state event; change AuthGate to wait for this same verified member before rendering HomeScreen. On sign-out, disable private screens and dispose all UID-bound listeners immediately. Show retry/sign-out actions if membership lookup fails.

~~~dart
Future<UserCredential> _signInMember({
  required String email,
  required String password,
  String? expectedUid,
  bool requireAdmin = false,
}) async {
  final credential = await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  try {
    final uid = credential.user!.uid;
    if (expectedUid != null && uid != expectedUid) {
      throw StateError('This login belongs to a different school account.');
    }
    final snapshot = await _firestore.collection('school_members').doc(uid)
        .get(const GetOptions(source: Source.server));
    final member = snapshot.data();
    if (member == null || member['active'] != true) {
      throw StateError('This school account needs an active roster entry.');
    }
    final capabilities = member['capabilities'];
    if (requireAdmin &&
        (capabilities is! Map || capabilities['manage_access'] != true)) {
      throw StateError('This account cannot manage school access.');
    }
    if (_auth.currentUser?.uid != uid) {
      throw StateError('The active account changed. Sign in again.');
    }
    await clearCache();
    await cacheProfile({
      'uid': uid,
      'full_name': member['display_name'],
      'scholar_no': member['scholar_no'],
      'house_name': member['house'],
      'class_level': member['class_id'],
      'role': member['role'],
    });
    return credential;
  } catch (_) {
    if (_auth.currentUser?.uid == credential.user?.uid) {
      try {
        await _auth.signOut();
      } finally {
        await clearCache();
      }
    }
    rethrow;
  }
}

Future<UserCredential> signInAdmin({required String password}) =>
    _signInMember(
      email: 'admin@asianschool.bh',
      password: password,
      requireAdmin: true,
    );

Future<UserCredential> switchAccount(
  SavedAccount account, {required String password}
) => _signInMember(
  email: _scholarToEmail(account.scholarNo.trim().toLowerCase()),
  password: password,
  expectedUid: account.uid,
);
~~~

Pass an ephemeral password from the account-picker form, await the result, then let the membership-aware AuthGate perform routing. Remove the two writes of account.cachedProfile and account.houseName from home_screen.dart 306–310. Replace the ordinary signIn implementation with a call to _signInMember using the normalized scholar email. Adapt the profile projection to separate grade and division if class_id includes both. Resolve manage_access for staff administration explicitly instead of assuming that a particular email address is always privileged. Read the signed-in account UID directly from Firebase in private services.

**One-time upgrade.** Before reading any saved account on startup delete the legacy saved_accounts_list as a deliberate one-time re-enrollment on shared devices. Remove the obsolete password property, vault, encrypt/decrypt, fallback reads and password arguments from all saved-account writers. Keep display-only shortcuts (UID and a school-approved display label) under a new key. Never store the password or entire profile in a shortcut. Delete the legacy provider key, cached report/attendance defaults and old prefixed private records. Match exact keys and prefixes from the source, leaving unrelated device preferences intact. Do this once under a migration version, set only after every removal succeeded. Clear private in-memory state and listeners on each UID change. For sensitive records prefer server reads on shared devices, or a verified device-specific offline policy with explicit UID partitioning and expiry. Scoping preferences alone does not isolate previously cached Firestore documents.

## 3. Deliver private messages exactly once per send action

Proposed new Functions module for the existing CommonJS backend. Load it from functions/index.js after the existing admin.initializeApp() with Object.assign(exports, require('./private_chat')). The module uses the installed firebase-admin and firebase-functions dependencies. Disable the legacy client room writes and notification creation before calling the new flow. The server reads both trusted memberships and applies the school's “one participant can receive student chat” policy on creation and on each send. Removing that capability blocks further sends between two ordinary students.

~~~javascript
// Proposed functions/private_chat.js
'use strict';
const crypto = require('node:crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const db = getFirestore();

function invalid(message) { throw new HttpsError('invalid-argument', message); }
function denied() { throw new HttpsError('permission-denied', 'Chat unavailable.'); }

function caller(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  return request.auth.uid;
}
function validId(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    invalid('Invalid identifier.');
  }
  return value;
}
function hash(parts) {
  return crypto.createHash('sha256').update(JSON.stringify(parts)).digest('hex');
}
function allowPair(a, b) {
  if (a?.active !== true || b?.active !== true ||
      !(a.capabilities?.can_receive_student_chat === true ||
        b.capabilities?.can_receive_student_chat === true)) denied();
}

exports.openPrivateChat = onCall(async (req) => {
  const uid = caller(req);
  const other = validId(req.data?.otherUid);
  if (uid === other) invalid('Choose another person.');
  const pair = [uid, other].sort();
  const room = db.collection('chats_v2').doc(hash(pair));
  await db.runTransaction(async (tx) => {
    const [a, b, old] = await tx.getAll(
      db.collection('school_members').doc(uid),
      db.collection('school_members').doc(other), room);
    const first = a.data(), second = b.data();
    allowPair(first, second);
    if (old.exists) {
      if (JSON.stringify(old.get('participants')) !== JSON.stringify(pair)) denied();
      return;
    }
    tx.create(room, {
      participants: pair,
      participant_names: { [uid]: first.display_name, [other]: second.display_name },
      participant_roles: { [uid]: first.role, [other]: second.role },
      participant_houses: { [uid]: first.house, [other]: second.house },
      last_message: '', last_updated: FieldValue.serverTimestamp(), sequence: 0,
    });
  });
  return { roomId: room.id };
});

exports.postPrivateMessage = onCall(async (req) => {
  const uid = caller(req);
  const room = db.collection('chats_v2').doc(validId(req.data?.roomId));
  const action = validId(req.data?.requestId);
  const text = typeof req.data?.text === 'string' ? req.data.text.trim() : '';
  if (!text || text.length > 2000) invalid('Enter 1–2000 characters.');
  // Sender and room scope prevent another client from reserving a chosen id.
  const id = hash([room.id, uid, action]);
  const message = room.collection('messages').doc(id);
  await db.runTransaction(async (tx) => {
    const [header, old] = await tx.getAll(room, message);
    const pair = header.data()?.participants;
    if (!Array.isArray(pair) || pair.length !== 2 || pair[0] === pair[1] ||
        !pair.includes(uid)) denied();
    const other = pair.find((p) => p !== uid);
    const [a, b] = await tx.getAll(db.collection('school_members').doc(uid),
      db.collection('school_members').doc(other));
    allowPair(a.data(), b.data());
    if (old.exists) {
      if (old.get('text') !== text || old.get('sender_id') !== uid) {
        throw new HttpsError('already-exists', 'This send ID has already been used.');
      }
      return;
    }
    const prior = header.get('sequence');
    if (!Number.isSafeInteger(prior) || prior < 0 || prior >= Number.MAX_SAFE_INTEGER) {
      throw new HttpsError('failed-precondition', 'This room needs migration.');
    }
    const stamp = FieldValue.serverTimestamp();
    tx.create(message, { sender_id: uid, sender_name: a.get('display_name'),
      text, timestamp: stamp, sequence: prior + 1 });
    tx.update(room, { last_message: text, last_updated: stamp, sequence: prior + 1 });
    tx.create(db.collection('users').doc(other).collection('notifications').doc(id),
      { title: 'New message', body: 'Open your inbox.', timestamp: stamp,
        is_read: false, type: 'chat_message', room_id: room.id });
  });
  return { messageId: id };
});
~~~

**Flutter integration.** Add a cloud_functions Flutter dependency compatible with the installed Firebase core and supported platforms on the future branch. Select the same deployed region in Flutter as the Functions region. At the time of review pubspec.yaml lists firebase_core, firebase_auth, cloud_firestore and firebase_storage; cloud_functions is absent. Use the existing Firestore-generated ID technique in place of a new UUID dependency. Generate and retain requestId once per message draft in the screen. Preserve it after a timeout, clear it after acknowledgement, and generate a fresh one for a new message. Use a different request ID if the user edits a failed message. For retries across restarts store only a scoped outbox under the device's private-data policy.

~~~dart
// Add to ChatService. Import package:cloud_functions/cloud_functions.dart.
Future<String> openRoomFor(String otherUid) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('openPrivateChat').call({'otherUid': otherUid});
  return (result.data as Map)['roomId'] as String;
}

String newSendId() => _firestore.collection('chats_v2').doc().id;

Future<void> deliverDraft({
  required String roomId, required String requestId, required String text,
}) async {
  await FirebaseFunctions.instance.httpsCallable('postPrivateMessage').call({
    'roomId': roomId, 'requestId': requestId, 'text': text,
  });
}
~~~

Switch both room and message queries from chats to chats_v2. Change getMyChatsStream to filter participant UID from Firebase Auth (the current arrayContains query already has the right shape). Use the new published chat_contacts collection for student discovery. An open room still needs a peer name and school-produced metadata even if the ordinary peer is absent from that directory. Keep only school-approved staff/contact names in the discovery collection. For staff starting a pupil conversation, search through a capability-limited callable. Change room rendering to use the canonical role only for a display label, remove room-ID splitting and the legacy client-updated badge fields. Render notification unread counts from the logged-in inbox. For per-room read receipts introduce a per-UID high-water sequence set by a member-validated callable bounded by the room sequence. Until integrated, remove read-checkmarks rather than showing an invented read state.

Migrate historical rooms only after checking both participants against a trustworthy record. Existing rules allowed participants to edit room membership, so blindly copying an existing participants array can perpetuate a disclosure. Decide how staff will recover valid conversations without revealing disputed ones. Set sequences in chronological order (use original document ID to break identical timestamps), rewrite deep links and maintain an old-to-new map. The sample ID validator accepts normal Firebase-generated IDs. Inventory custom UIDs containing other characters before introducing that constraint.

## 4. Bind certificate uploads to real claims

The current flow uploads first and can return a persistent URL or inline image, then submits the claim. The privileged trigger independently creates or overwrites verification metadata. Use the activity workflow companion's proposed activity_claims_v2/{claimId} and Storage rules. Each trusted claim stores uid, house, title, path and state. File finalization checks claims_v2/{uid}/{claimId}/certificate.jpg, verifies the object, records objectGeneration and transitions awaiting_file to pending. A human reviewer with reviewHouseClaims decides the pending claim. Invalid file contents enter invalid_file. Retire the legacy parser and both unconditional merge-writes in the same release.

**Optional OCR helper after finalization.** Run recognition on only validated bytes after the claim is pending. Bind the read to its recorded bucket, path and object generation. The event retry handler must handle transient failure before storing a terminal result and guard concurrent retries. The following helper appends a private scan result for the specific pending claim even when two attempts finish at the same time. A late OCR result cannot reopen a decided claim. Keep the school logo and phrases as hints for staff.

~~~javascript
// Proposed helper inside functions/index.js, which already defines db and admin.
async function recordEvidenceHint(object, hint) {
  const match = /^claims_v2\/([^/]+)\/([A-Za-z0-9_-]{1,128})\/certificate\.jpg$/
    .exec(object.name || '');
  if (!match || !object.generation ||
      !['markers_found', 'no_markers', 'needs_review'].includes(hint)) return;
  const [, uid, id] = match;
  const claimRef = db.collection('activity_claims_v2').doc(id);
  const resultRef = claimRef.collection('staff_scan').doc('result');
  await db.runTransaction(async (tx) => {
    const [snap, result] = await tx.getAll(claimRef, resultRef);
    const claim = snap.data();
    if (!claim || result.exists || claim.state !== 'pending' || claim.uid !== uid ||
        claim.path !== object.name ||
        String(claim.objectGeneration) !== String(object.generation)) return;
    tx.create(resultRef, {
      source_generation: String(object.generation),
      hint, scanned_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}
~~~

~~~text
// Inside the Firestore database match, using cap() from section 1.
match /activity_claims_v2/{claimId}/staff_scan/{result} {
  allow get: if cap('reviewHouseClaims');
  allow list, write: if false;
}
~~~

Render private evidence through bounded authenticated SDK reads. Stop storing reusable download URLs and inline certificate data in new claim records. Inspect and revoke historical download tokens as appropriate. Move old certificate paths behind explicit review permissions, remove the broad recursive Storage read, enforce a per-owner quota and expire abandoned awaiting_file slots. Check real image bytes before OCR. Store private medical evidence under separate owner- and leave-reviewer-bound paths. Cross-service reads in Storage rules require Firestore integration permissions in the target project. [Firebase Storage rule conditions](https://firebase.google.com/docs/storage/security/rules-conditions)

## 5. Smaller changes with immediate impact

* **Wall moderation.** At firestore.rules 831–845 require published/approved status for ordinary feed queries and add the matching where('status', isEqualTo: 'approved'). Give submitters a separate owner-filtered “my submissions” query and moderators a capability-gated queue. Move likes into event_wall/{post}/likes/{uid} with one subdocument per active member. Use an idempotent transaction for any count. Require approved status when liking and derive all owner fields from UID.
* **Academic and leave privacy.** Attach owner_uid, class_id and academic year to historical records before removing unrestricted reads. Public views should never include private leave reasons, attendance histories or full report cards. Test a sibling switch and one student's attempt to read a known second student's document ID.
* **AI assistant.** Remove provider keys from preferences and query parameters in client requests. Use a school-managed backend secret, per-user quotas, approved topics and minimal inputs. Compute attendance locally or from the authenticated student's owned records. With zero tracked lessons display “No attendance recorded.” Show exactly what will be sent if the school enables external processing of personal data. Never embed identifiers, raw chat, medical details or grades by default. Disable personal answers until a UID is present. Verify a supported model and the school's data-handling policy before enabling it.
* **Device reset and recovery.** Inspect the real delivery route for scholar-number-derived recovery email addresses. Show a school support route if pupils have no corresponding inbox. Stop granting any role based on an email string or hardcoded scholar number. lib/services/hierarchy_service.dart 127–130 still maps three scholar IDs to a “Super Admin” display title. Derive titles from the trusted display record.
* **Credential keys and vouchers.** Replace offline trust with short-lived, high-entropy opaque redemption tokens stored as server-side hashes. Bind each token to its order and authorized purpose, use a server clock and consume the token and change the order in a transaction. If offline scanning is necessary, queue a scan for explicit online reconciliation and label its status appropriately. Rotate/retire older client-generated proof formats after inventory and migration.
* **Notifications and stale documents.** All system-generated inbox messages should have a deterministic event ID and generic text in push previews. Disable cross-user client inserts. On privilege removal, unsubscribe private screens and stop rendering stale restricted content. Validate authorization on every callable even if a screen is hidden.

## Review and release checks

| Scenario to exercise using multiple emulator identities | Required outcome |
|---|---|
| Fresh account creates a teacher profile, claims a reserved email, calls a staff function or reads the student directory | Access denied until a school administrator links the UID and explicitly grants scope. |
| A real teacher loses moderation capability between opening a screen and clicking Approve | The final server transaction checks live membership and rejects the transition. |
| A fails to switch into B, Firebase is offline, or B signs out mid-load | A screen never renders B's private cached records as A. The member gate shows login or retry and no command is marked successful. |
| Two ordinary pupils open a new room, an outsider queries messages by exact ID, a member tries to change participants | All are denied. A permitted council/teacher contact works with the canonical role. |
| Sender submits the same action ID after a timeout or concurrently from two sessions | One persisted message, one new room sequence and one inbox notification. Reusing the key with different text fails. |
| Student A uploads into B's slot, invents a claim ID, reuploads existing bytes or requests a private download | Every unauthorized operation fails. Allowed reviewers and the owner can read the right object only. Also test listing vs getting by exact path. |
| OCR fires twice, runs after staff approval or returns an error | One hint is recorded for a pending bound document. No event overwrites an owner or staff decision, and no score changes from OCR alone. |
| Roster query, class query, room query, feed and index setup | Allowed queries return real data, unauthorized direct gets and broad scans fail, missing indexes show retryable errors. |
| Previously untrusted roles, historical chats, evidence and long-lived URLs | School staff resolve disputed identities or quarantine affected data before granting access. Compare row counts, sample owners and check reversible backups. |

Scope of validation for this document: checked source contracts and verified the proposed JavaScript syntax separately. Rules and Flutter snippets still require integration, emulator authorization tests and a real-device shared-session test before deployment.
