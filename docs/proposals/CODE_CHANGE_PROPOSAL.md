# ASB House Hub • app review and proposed code changes

Review of checkout 91538d1. Start here, then open the three companion guides for the code affecting your area. All code below is a proposal for a separate staging copy. No change here activates a feature.

## What the app does

ASB House Hub combines a school portal with house competitions. Students can see academic work, attendance, notices, fixtures and standings, use chat, submit claims, shop and enter the election chamber. Staff screens cover moderation, behavior, academic records and sporting results. The Flutter client uses Firebase Authentication, Firestore, Storage and device preferences. The checked-in Functions entry point processes certificate uploads. The client currently performs many operations that determine official school records.

## What to fix first

| Order | What happens today | Suggested change | Where to read the code |
|---|---|---|---|
| 1 | A signed-in account can get access beyond its class or chat. Profile fields and email influence privilege. | Bind an account to one verified school member. Enforce class, room and staff permissions in the backend before enabling new writes. | [Security, identity and chat](./SECURITY_CHANGE_PROPOSAL.md) |
| 2 | The election chamber displays and accepts candidates from a document, but a staff member cannot build and publish the ballot there. A normal student's transaction tries to read an admin-only vote lock. | Give staff a draft and publish flow. Accept eligible votes on the server with one receipt per enrolled student. | Elections below |
| 3 | One student's homework status can affect the shared assignment. Medical leave and attendance can disagree. | Separate the teacher's assignment, the student's submission and the assessor's decision. Apply approved leave against the school calendar. | [Academics, attendance and publishing](./ACADEMIC_CHANGE_PROPOSAL.md) |
| 4 | A store reservation can look ready before payment or collection. Separate operations can disagree about house points and sports awards. | Use staff-confirmed transitions, persistent operation IDs and atomic inventory or points changes. | [Store, activities and scoring](./ACTIVITIES_CHANGE_PROPOSAL.md) |
| 5 | Screens can present cached, synthetic or failed results as official. On a shared device this also affects receipts and AI context. | Show who owns each record, whether it came from the server and what action the user can take next. | Shared-device, AI and visual changes below |

## Elections • where the path breaks

| Step | Evidence in this checkout | Effect |
|---|---|---|
| Create, add a person, publish | The home route opens ElectionChamberScreen at lib/screens/home_screen.dart:3176. The chamber subscribes to getElectionsStream at lib/screens/election_chamber_screen.dart:53 and renders an empty candidate list at line 392. The app has no reachable draft editor or candidate publisher. | Staff need outside database access to stage the very first election. |
| Vote as a student | lib/services/auth_service.dart:3596–3608 reads election_votes inside the transaction. firestore.rules:718–726 restricts reads to admins. | A student can press Confirm and be denied even for an open election. Making the vote collection broadly readable would expose records and still leave the integrity hole below. |
| Protect the count | firestore.rules:694–706 allows signed-in clients to replace the candidate array and total on an open ballot. lib/services/auth_service.dart:3611–3638 increments the total even if the chosen candidate was missing. The code checks neither the registered grade nor house on the server. | A client can alter the result independently of one legitimate vote. |
| Acknowledge a vote | lib/services/auth_service.dart:3608–3668 can fall through to a local receipt if the election is missing or Firebase is unavailable. Receipt cache key at line 3503 is shared across accounts. | A student can get a receipt for an unrecorded vote, or see another account's voting state. |
| Verify and declare results | lib/screens/election_audit_screen.dart:55–74 uses local receipts and a fallback of 500 eligible voters. lib/services/auth_service.dart:3765 accepts a caller-selected winner. The audit and gazette screens and certification method have no callers in the shipped lib tree. | A voter has no straightforward route back to an official receipt or published outcome. Turnout and a certified winner need trustworthy inputs. |

## Proposed election policy

The example implements a staff-managed single-seat election. A manager looks up a real student by scholar number, adds their public name and statement to a private draft, reviews the list and publishes. Only active students in the configured grade range and optional house can vote, once. The server enforces opening and closing instants. A manager certifies after the deadline. The public result can explicitly say tie or no votes. This example assumes at least two candidates, a single round, no minimum turnout, no early close, and no automatic grants of roles or house points. Confirm these school policies before activation. If a quorum is required, freeze the eligible register at publication and use its actual size. Here eligibility follows the current roster.

Required private roster: school_members/{firebaseUid} with active (boolean), role, scholar_no (canonical string), display_name, grade (integer), house (lowercase), class_id and a capabilities map. The school must verify that a scholar belongs to exactly one active UID, including when accounts are replaced. Never fill this roster by trusting a self-registered profile. The security guide covers the access boundary. The election stores a voter's participation separately from the aggregate counts and returns a receipt that omits the choice. Infrastructure administrators can still observe server operations. Describe the receipt as confirmation of participation.

### Server module

Proposed new target: functions/elections-v2.js. Append the single export line shown below to the existing Functions entry point after its Admin initialization. Keep the existing certificate trigger. All election code blocks labelled JavaScript under this heading form ONE module in order.


~~~javascript
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { randomUUID, createHash } = require("node:crypto");

const db = getFirestore();
const houses = ["ruby", "sapphire", "emerald", "topaz"];
const positions = ["headBoy", "headGirl", "houseCaptain", "viceCaptain",
  "culturalSecretary", "sportsCaptain", "prefect"];
const fail = (code, message) => { throw new HttpsError(code, message); };

function boundedText(value, max, label) {
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) {
    fail("invalid-argument", "Check " + label + ".");
  }
  return value.trim();
}

function resourceId(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,80}$/.test(value)) {
    fail("invalid-argument", "Invalid record ID.");
  }
  return value;
}

function requireState(ok, message) {
  if (!ok) fail("failed-precondition", message);
}

function eligible(person, poll) {
  return person?.active === true && person.role === "student" &&
    Number.isInteger(person.grade) && person.grade >= poll.minGrade &&
    person.grade <= poll.maxGrade && houses.includes(person.house) &&
    (poll.house === "all" || person.house === poll.house);
}

function draftSettings(data) {
  const title = boundedText(data.title, 120, "title");
  const { position, minGrade, maxGrade, house, startMs, endMs } = data;
  if (!positions.includes(position) || !["all", ...houses].includes(house) ||
      !Number.isInteger(minGrade) || !Number.isInteger(maxGrade) ||
      minGrade < 1 || maxGrade > 12 || minGrade > maxGrade ||
      !Number.isSafeInteger(startMs) || !Number.isSafeInteger(endMs) ||
      startMs < 0 || endMs <= startMs || endMs > 4102444800000) {
    fail("invalid-argument", "Check the position, house, grades and voting window.");
  }
  return { title, position, minGrade, maxGrade, house, startMs, endMs };
}

function publicHeader(draft) {
  const { title, position, minGrade, maxGrade, house, startMs, endMs } = draft;
  return { title, position, minGrade, maxGrade, house,
    opensAt: Timestamp.fromMillis(startMs), closesAt: Timestamp.fromMillis(endMs) };
}

exports.schoolElection = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) fail("unauthenticated", "Sign in to continue.");
  const data = request.data ?? {};
  const pollId = resourceId(data.pollId);
  const member = db.collection("school_members").doc(uid);
  const draft = db.collection("election_drafts_v2").doc(pollId);
  const poll = db.collection("election_polls_v2").doc(pollId);
  const action = data.action;

  return db.runTransaction(async (tx) => {
    const person = (await tx.get(member)).data();
    if (person?.active !== true) fail("permission-denied", "School membership required.");

    if (action === "vote" || action === "receipt") {
      if (person.role !== "student") fail("permission-denied", "Student account required.");
      const scholar = boundedText(person.scholar_no, 64, "verified roster identity");
      const key = createHash("sha256").update(pollId + ":" + scholar).digest("hex");
      const participation = poll.collection("participation").doc(key);
      const prior = (await tx.get(participation)).data();
      if (action === "receipt" || prior) {
        return { receipt: prior?.receipt ?? null, alreadyRecorded: Boolean(prior) };
      }
      const box = (await tx.get(poll)).data();
      if (!box) fail("not-found", "Election was not published.");
      const now = Date.now();
      requireState(box.status === "published" && now >= box.opensAt.toMillis() &&
        now < box.closesAt.toMillis(), "Voting is closed.");
      if (!eligible(person, box)) fail("permission-denied", "Outside the eligible electorate.");
      const candidateId = resourceId(data.candidateId);
      requireState(box.candidates.some(c => c.id === candidateId), "Candidate is not on this ballot.");
      const receipt = randomUUID();
      tx.create(participation, { receipt });
      tx.set(poll.collection("counts").doc(candidateId),
        { count: FieldValue.increment(1) }, { merge: true });
      return { receipt, alreadyRecorded: false };
    }

    if (person.capabilities?.manage_elections !== true) {
      fail("permission-denied", "Election manager required.");
    }
    const current = (await tx.get(draft)).data();
    if (action === "create") {
      const settings = draftSettings(data);
      if (current) {
        requireState(current.createdBy === uid && Object.keys(settings).every(
          k => current[k] === settings[k]), "Draft ID already used. Open the existing draft.");
        return { pollId };
      }
      requireState(settings.endMs > Date.now(), "Choose a future deadline.");
      tx.create(draft, { ...settings, candidates: [], status: "draft", createdBy: uid });
      return { pollId };
    }

    if (!current) fail("not-found", "Draft not found.");
    if (action === "publish" && current.status !== "draft") return { pollId, status: current.status };
    if (action === "certify") {
      const box = (await tx.get(poll)).data();
      requireState(Boolean(box), "Publish the ballot first.");
      if (box.status === "certified") return { pollId, result: box.result };
      requireState(Date.now() >= box.closesAt.toMillis(), "Voting is still open.");
      const totals = await tx.getAll(...box.candidates.map(c => poll.collection("counts").doc(c.id)));
      const rows = box.candidates.map((c, i) => {
        const n = totals[i].exists ? totals[i].get("count") : 0;
        requireState(Number.isSafeInteger(n) && n >= 0, "Invalid count. Review the tally.");
        return { id: c.id, count: n };
      });
      const total = rows.reduce((sum, r) => sum + r.count, 0);
      const max = Math.max(...rows.map(r => r.count));
      const leaders = total ? rows.filter(r => r.count === max).map(r => r.id) : [];
      const outcome = !total ? "no_votes" : leaders.length > 1 ? "tie" : "winner";
      const result = { rows, total, leaders, outcome };
      tx.update(poll, { status: "certified", result, certifiedAt: FieldValue.serverTimestamp() });
      tx.update(draft, { status: "certified", certifiedBy: uid });
      return { pollId, result };
    }

    requireState(current.status === "draft", "Published candidates and settings are frozen.");
    if (action === "remove") {
      const key = resourceId(data.candidateId);
      tx.update(draft, { candidates: current.candidates.filter(c => c.id !== key) });
      return { pollId };
    }

    if (action === "add") {
      const scholar = boundedText(data.scholarNo, 64, "scholar number");
      const statement = boundedText(data.statement, 800, "candidate statement");
      const matches = await tx.get(db.collection("school_members")
        .where("scholar_no", "==", scholar).limit(2));
      requireState(matches.size === 1, "The roster must contain one matching member.");
      const doc = matches.docs[0];
      const candidate = doc.data();
      requireState(eligible(candidate, current), "Candidate is not eligible for this ballot.");
      const name = boundedText(candidate.display_name, 120, "roster display name");
      const existing = current.candidates.find(c => c.uid === doc.id);
      const next = { id: existing?.id ?? randomUUID(), uid: doc.id, name, statement };
      const list = current.candidates.filter(c => c.uid !== doc.id);
      requireState(list.length < 20, "This ballot supports up to 20 candidates.");
      tx.update(draft, { candidates: [...list, next] });
      return { pollId, candidateId: next.id };
    }

    if (action === "publish") {
      requireState(current.endMs > Date.now(), "The deadline has passed.");
      requireState(current.candidates.length >= 2, "Add at least two eligible candidates.");
      const people = await tx.getAll(...current.candidates.map(c =>
        db.collection("school_members").doc(c.uid)));
      const candidates = current.candidates.map((c, i) => {
        const registered = people[i].data();
        requireState(eligible(registered, current), "Review a candidate whose membership changed.");
        const name = boundedText(registered.display_name, 120, "roster display name");
        requireState(name === c.name, "A candidate changed name. Refresh their draft entry.");
        return { id: c.id, name, statement: c.statement };
      });
      tx.create(poll, { ...publicHeader(current), candidates, status: "published",
        publishedAt: FieldValue.serverTimestamp() });
      tx.update(draft, { status: "published", publishedBy: uid });
      return { pollId, status: "published" };
    }
    fail("invalid-argument", "Unknown election action.");
  });
});
~~~

In functions/index.js, after admin.initializeApp(), expose it with:

~~~javascript
exports.schoolElection = require("./elections-v2").schoolElection;
~~~

### Rules and deployment boundary

Add the following inside the Firestore database documents match in staging. The security chapter owns the school_members read rule. These two collections have their own top-level paths. A manager can list all drafts. An active member can see all published elections and certified results, even for a different house. Voting eligibility is narrower. If election visibility itself must be restricted, change both the rule and the feed query. Counts and participation are private documents and are accessed through the callable. Review every overlapping allow in the combined ruleset.

~~~javascript
function hasElectionMembership() {
  return request.auth != null &&
    exists(/databases/$(database)/documents/school_members/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.active == true;
}
match /election_drafts_v2/{pollId} {
  allow read: if hasElectionMembership() &&
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.capabilities.manage_elections == true;
  allow write: if false;
}
match /election_polls_v2/{pollId} {
  allow read: if hasElectionMembership();
  allow write: if false;
  match /{nested=**} { allow read, write: if false; }
}
~~~

The legacy election paths also need a cutover. Replace the existing election update and ballot/vote create grants at firestore.rules:694–726 with read-only archive rules, including the nested ballots. Keep individual legacy ballot records restricted. Lock the legacy gazette writers too. A permissive legacy path would still let old apps advertise a second result. Do this in an announced election-free window, after inventorying active ballots and deciding how each one finishes. Archive historic totals with their provenance. Local cached receipts cannot safely reconstruct a school's electorate or votes.



### Flutter election screen

Proposed new target: lib/screens/school_elections_page.dart. The blocks below form one Dart file in order. This example uses the packages already declared in this checkout, including http, and the default Functions region matching the server block above. The endpoint is derived from the initialized Firebase project, never from user input. For an emulator build, inject the local Functions endpoint and a matching emulator Auth/Firestore project in the test harness. For App Check enforcement, add its token to the transport, or use the supported callable SDK on your release platforms. [Firebase callable protocol](https://firebase.google.com/docs/functions/callable-reference)

The screen loads the account and records from the server. A reload button is available for newly published ballots. It deliberately does not display private drafts from a device cache. Wire the Home election tile at lib/screens/home_screen.dart:3176 to const SchoolElectionsPage() and import this file. Use the page's certified results panel as the gazette entry point when retiring the old audit and gazette readers.

~~~dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

typedef Fields = Map<String, dynamic>;
typedef ElectionDoc = QueryDocumentSnapshot<Fields>;

class SchoolElectionsPage extends StatelessWidget {
  const SchoolElectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Sign in to view elections.')));
        }
        return _ElectionDesk(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _ElectionDesk extends StatefulWidget {
  const _ElectionDesk({super.key, required this.uid});
  final String uid;

  @override
  State<_ElectionDesk> createState() => _ElectionDeskState();
}

class _ElectionDeskState extends State<_ElectionDesk> {
  final db = FirebaseFirestore.instance;
  late Future<({Fields member, List<ElectionDoc> polls, List<ElectionDoc> drafts})> feed;
  bool busy = false;
  String? unconfirmedDraftId;
  final receipts = <String, String>{};

  @override
  void initState() {
    super.initState();
    feed = load();
  }

  Future<({Fields member, List<ElectionDoc> polls, List<ElectionDoc> drafts})> load() async {
    const opts = GetOptions(source: Source.server);
    final member = (await db.collection('school_members').doc(widget.uid).get(opts)).data();
    if (member == null || member['active'] != true) {
      throw StateError('Ask the school to link your account to its roster.');
    }
    final polls = await db.collection('election_polls_v2').orderBy('opensAt', descending: true).get(opts);
    final canManage = member['capabilities']?['manage_elections'] == true;
    final drafts = canManage
        ? (await db.collection('election_drafts_v2').orderBy('startMs', descending: true).get(opts)).docs
        : <ElectionDoc>[];
    return (member: member, polls: polls.docs, drafts: drafts);
  }

  void refresh() => setState(() => feed = load());

  Future<Fields> call(String action, String id, [Fields args = const {}]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.uid) throw StateError('Sign in again.');
    final token = await user.getIdToken();
    if (token == null) throw StateError('Sign in again.');
    final project = Firebase.app().options.projectId;
    final url = Uri.https('us-central1-' + project + '.cloudfunctions.net', '/schoolElection');
    final reply = await http.post(url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token},
      body: jsonEncode({'data': {...args, 'action': action, 'pollId': id}}),
    ).timeout(const Duration(seconds: 25));
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw StateError('Account changed. Reopen elections.');
    }
    final envelope = jsonDecode(reply.body);
    if (envelope is! Map) throw const FormatException('Unrecognized server response.');
    if (reply.statusCode != 200 || envelope['error'] != null) {
      throw StateError(envelope['error']?['message']?.toString() ?? 'Request failed.');
    }
    final result = envelope['result'] ?? envelope['data'];
    if (result is! Map) throw const FormatException('Missing election confirmation.');
    return Map<String, dynamic>.from(result);
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
      if (mounted) refresh();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error  Refresh to check the server before retrying.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Fields?> form(String title, Map<String, String> labels) {
    final values = <String, dynamic>{};
    final key = GlobalKey<FormState>();
    return showDialog<Fields>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Form(key: key, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final field in labels.entries) TextFormField(
            decoration: InputDecoration(labelText: field.value),
            onChanged: (value) => values[field.key] = value.trim(),
            validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
          )],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (key.currentState!.validate()) Navigator.pop(dialog, values);
          }, child: const Text('Continue')),
        ],
      ),
    );
  }

  Future<bool> confirm(String title, String detail) async {
    return await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: Text(title), content: Text(detail), actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Confirm')),
      ],
    )) ?? false;
  }

  Future<void> createDraft() async {
    final values = await form('Create a private draft', {
      'title': 'Election title',
      'position': 'Position code, e.g. houseCaptain',
      'house': 'House, or all',
      'minGrade': 'Lowest eligible grade (1–12)',
      'maxGrade': 'Highest eligible grade (1–12)',
      'start': 'Opening time in UTC, YYYY-MM-DDTHH:MMZ',
      'end': 'Closing time in UTC, YYYY-MM-DDTHH:MMZ',
    });
    if (values == null || !mounted) return;
    int instant(String key) {
      final text = values.remove(key) as String;
      if (!text.endsWith('Z')) throw const FormatException('Include the UTC suffix Z.');
      final date = DateTime.parse(text);
      final canonical = date.toUtc().toIso8601String().substring(0, 16) + 'Z';
      if (canonical != text) throw const FormatException('Use YYYY-MM-DDTHH:MMZ.');
      return date.millisecondsSinceEpoch;
    }
    values['startMs'] = instant('start');
    values['endMs'] = instant('end');
    values['minGrade'] = int.parse(values['minGrade'] as String);
    values['maxGrade'] = int.parse(values['maxGrade'] as String);
    values['house'] = (values['house'] as String).toLowerCase();
    final id = unconfirmedDraftId ??= db.collection('election_drafts_v2').doc().id;
    await call('create', id, values);
    unconfirmedDraftId = null;
  }

  Future<void> add(String id) async {
    final input = await form('Add or update a candidate', {
      'scholarNo': 'Registered scholar number', 'statement': 'Approved candidate statement',
    });
    if (input != null && mounted) await call('add', id, input);
  }

  Future<void> checkReceipt(String id, {String? candidateId}) async {
    final result = await call(candidateId == null ? 'receipt' : 'vote', id,
      ifCandidate(candidateId));
    if (!mounted) return;
    final receipt = result['receipt'] as String?;
    if (receipt != null) receipts[id] = receipt;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(receipt == null
      ? 'No vote is recorded for your account in this election.'
      : 'Your vote is recorded. Receipt: ' + receipt)));
  }

  Fields ifCandidate(String? id) => id == null ? {} : {'candidateId': id};

  Widget action(String label, Future<void> Function() work) => TextButton(
    onPressed: busy ? null : () => run(work), child: Text(label));

  Widget managerCard(ElectionDoc doc) {
    final p = doc.data();
    final candidates = (p['candidates'] as List).cast<Map>();
    return Card(child: ExpansionTile(
      title: Text(p['title'] as String),
      subtitle: Text('${p['status']} · ${p['position']} · ${p['house']} · Grades ${p['minGrade']}–${p['maxGrade']}'),
      children: [
        Text('Opens ${DateTime.fromMillisecondsSinceEpoch(p['startMs'] as int, isUtc: true)}'),
        Text('Closes ${DateTime.fromMillisecondsSinceEpoch(p['endMs'] as int, isUtc: true)}'),
        for (final c in candidates) ListTile(
          title: Text(c['name'] as String), subtitle: Text(c['statement'] as String),
          trailing: p['status'] == 'draft' ? action('Remove', () async {
            if (await confirm('Remove candidate?', c['name'] as String) && mounted) {
              await call('remove', doc.id, {'candidateId': c['id']});
            }
          }) : null,
        ),
        if (p['status'] == 'draft') ...[
          action('Add candidate', () => add(doc.id)),
          action('Publish ballot', () async {
            if (await confirm('Publish ballot?', 'Freeze this list of ${candidates.length} candidates and schedule voting.') && mounted) {
              await call('publish', doc.id);
            }
          }),
        ],
        if (p['status'] == 'published') action('Certify after deadline', () async {
          if (await confirm('Publish the final count?', 'The server will count the votes and declare the outcome.') && mounted) {
            await call('certify', doc.id);
          }
        }),
      ],
    ));
  }
~~~


~~~dart
  Widget ballot(ElectionDoc doc, Fields member) {
    final p = doc.data();
    final opens = (p['opensAt'] as Timestamp).toDate();
    final closes = (p['closesAt'] as Timestamp).toDate();
    final now = DateTime.now();
    final published = p['status'] == 'published';
    final inWindow = !now.isBefore(opens) && now.isBefore(closes);
    final student = member['role'] == 'student';
    final grade = member['grade'];
    final eligible = student && grade is int && grade >= p['minGrade'] &&
        grade <= p['maxGrade'] && (p['house'] == 'all' || p['house'] == member['house']);
    final recorded = receipts[doc.id];
    final candidates = (p['candidates'] as List).cast<Map>();
    final result = p['result'] as Map?;
    final counts = <String, int>{
      if (result != null) for (final r in result['rows'] as List)
        r['id'] as String: r['count'] as int,
    };
    final outcome = result?['outcome'];
    final leaderIds = result?['leaders'] as List? ?? const [];
    final leaders = candidates.where((c) => leaderIds.contains(c['id']))
        .map((c) => c['name']).join(', ');
    final phase = result != null ? 'Certified'
        : now.isBefore(opens) ? 'Scheduled' : inWindow ? 'Open' : 'Awaiting certification';
    return Card(child: ExpansionTile(
      title: Text(p['title'] as String),
      subtitle: Text('$phase · ${p['house']} · Grades ${p['minGrade']}–${p['maxGrade']}'),
      children: [
        Text('Voting window (your local time): ${opens.toLocal()} to ${closes.toLocal()}'),
        if (result != null) Text(outcome == 'winner' ? 'Elected: $leaders'
          : outcome == 'tie' ? 'Tied: $leaders' : 'No votes cast'),
        if (recorded != null) SelectableText('Recorded · Receipt $recorded'),
        if (published && inWindow && !eligible) const Text('You can view this ballot. Voting is limited to eligible students.'),
        for (final c in candidates) ListTile(
          title: Text(c['name'] as String),
          subtitle: Text(c['statement'] as String),
          trailing: result != null ? Text('${counts[c['id']]} votes')
            : eligible && published && inWindow && recorded == null
                ? action('Vote', () async {
                    if (await confirm('Vote for ${c['name']}?', 'You can cast one vote in this election.') && mounted) {
                      await checkReceipt(doc.id, candidateId: c['id'] as String);
                    }
                  }) : null,
        ),
        if (student) action('Check my receipt', () => checkReceipt(doc.id)),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('School elections'), actions: [
        IconButton(tooltip: 'Refresh elections', onPressed: busy ? null : refresh,
          icon: const Icon(Icons.refresh)),
      ]),
      body: FutureBuilder(
        future: feed,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Could not load elections. ${snap.error}'));
          final data = snap.requireData;
          final manage = data.member['capabilities']?['manage_elections'] == true;
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (busy) const LinearProgressIndicator(),
            if (manage) ...[
              Text('Election management', style: Theme.of(context).textTheme.titleLarge),
              action('Create draft', createDraft),
              for (final d in data.drafts) managerCard(d),
            ],
            Text('Published ballots and results', style: Theme.of(context).textTheme.titleLarge),
            if (data.polls.isEmpty) const Text('The school has not published any ballots yet.'),
            for (final d in data.polls) ballot(d, data.member),
          ]);
        },
      ),
    );
  }
}
~~~

Before a student pilot, replace the free-text type, house, grades and UTC fields with dropdowns and date/time pickers labeled with the school's time zone. The accepted position codes are in the server's positions array. Present the nominee's statement for staff approval before adding it. Add pagination for the history after the first term. Refresh on app resume and the next scheduled boundary, and check the receipt when expanding a ballot. The explicit refresh and receipt buttons make those actions available in this sample. Store a pending create operation and its original form values per staff account if drafts must survive an app restart during a timeout. Reconcile against the management list before issuing another create. The new paths do not feed the legacy gazette or academic reward logic.

### Election acceptance checks

| Exercise with two physical accounts or emulator users | Expected result |
|---|---|
| Manager creates a draft, enters a real scholar number twice, changes the statement, adds a second person and publishes | First nominee appears once. A student cannot find the draft. Both names and statements appear on the published ballot. |
| Enter a missing, inactive, duplicate roster identity or an ineligible nominee. Publish with one candidate | Show the server's explanation and keep the draft editable. |
| Vote one instant before opening, exactly at opening, and exactly at closing under a controlled server clock | Deny, accept, deny respectively. Changing the phone clock only changes its display. |
| Two devices for the same scholar choose different people simultaneously. Force a timeout after commit, then use Check my receipt | One participation record, one counted vote, same receipt. Returning the receipt acknowledges the original choice. |
| Attempt direct document writes, an invented candidate, wrong house, wrong grade, staff vote or early certification | No change in participation, totals or published result. Authorized staff can manage without gaining a student vote. |
| Deadline passes with no votes, a tie, or a winner. Certify twice. Sign out and sign in on a fresh device | Identical public result on both reads. The student's own receipt can be retrieved on another device. One account never sees another's receipt in the UI. |
| Existing elected students, migrated ballots, corrected school IDs | Preserve past results separately. Freeze scholar-number changes or migrate the private participation markers atomically before allowing a replacement identity to vote. |

A practical load test should cast simultaneous votes for the most popular candidate. This simple tally uses one counter document per candidate. If staging shows contention at school-wide turnout, use multiple server-picked counter shards per candidate and aggregate the fixed shard set during certification. Validate the supported turnout against the school's actual peak.



## Other screens that promise an outcome

| Screen | What I found | Suggested behavior |
|---|---|---|
| Home → Academic profile | lib/screens/home_screen.dart:5088–5091 displays High Honors, Senior Tier 1 and 99.4% attendance as fixed values. | Read the signed-in student's published report and marked school days. Show “No marks published” and “No days marked” separately. State which attendance statuses are in the denominator. |
| Home → Library | lib/screens/home_screen.dart:5170–5295 contains three fixed books and a Renew button that only closes the sheet and shows a success message. | Add a librarian checkout and return path and an owner-only loan list. Show the updated due date only after the database acknowledges a renewal. See code below. |
| Home → Settings | lib/screens/home_screen.dart:5300–5421 initializes push and effects to true on every open. Clear App Cache only shows a snackbar. The theme switch does update the theme controller. | Persist effects, apply them to the effect widgets, and expose actual platform notification authorization and subscription when implemented. Clear only named disposable caches. Give the UI the actual outcome of the clear operation. |
| Event wall | lib/screens/home_screen.dart:750–778 reshares the certificate URL into a pending post and ignores failure. The feed limits to 20 before filtering by status at 4174–4199. firestore.rules:831–849 allows signed-in reads of pending posts and replacement of the likes fields. | Keep certificate proof private. Offer an optional, separately uploaded public image. Query only published posts. Separate moderation and author-only drafts. Use a single per-person reaction and a backend total. |
| Student scanner and profile | lib/screens/id_scanner_screen.dart:536–606 can resolve a QR from a saved sibling or its embedded name/house after authoritative lookup fails. lib/widgets/student_profile_modal.dart:92–124 can resolve a person by display name. | Use a scan as a lookup hint. Require a verified roster match by stable ID before opening staff actions. Distinguish offline, access denied, unknown ID and ambiguous names. |
| House AI | lib/services/gemini_ai_service.dart:38–52 stores a user key in preferences. Lines 102–204 build personal context including attendance, work and contributions. At 277–278 missing identity falls back to a particular scholar and grade. The chat constructs history at lib/screens/house_ai_chat_screen.dart:162–175. | Remove the default scholar and grade. Keep personal lookups in an owner-checked local or server query. The ordinary assistant should receive only the student's question and approved public school information. Separate cached answers from provider responses in the UI. |
| Startup and account switching | lib/main.dart:26–47 catches Firebase initialization failure and launches the same app. The auth gate at 79–93 can go straight to login while the session is still loading. | Give a failed Firebase startup its own retry screen. Wait for the authenticated UID and verified membership before rendering personal data. Let public cached content display an offline timestamp. |
| Roster and appointments | lib/services/auth_service.dart:2865–2981 writes a roster slot, profile and notifications separately. A partial write can make the roster title and actual account disagree. | Staff issue/revoke a capability only on verified school membership. In one transaction check the previous slot holder, update both affected members and create an audit event. Queue notifications from committed events. Treat elected titles as profile information under school policy. |
| Release build | android/app/build.gradle.kts:39–43 selects the debug signing config for release. lib/firebase_options.dart:16–22 falls back to web options for other desktop platforms. | Configure the school's release signer through CI secrets and fail a release if missing. Only advertise platforms with a registered Firebase configuration and a tested school workflow. |
| Language, device and motion | lib/main.dart:62–64 wires the English/Arabic delegates. Many action labels remain English literals, including election buttons. The Arena and mascot screens run repeating controllers. | Move action/status text and accessible descriptions to the two ARB files. Check RTL navigation, Arabic names, text scaling and reduced-motion mode on the actual device. |

### Library checkout, renewal and return

Proposed target: functions/library-v2.js. This is independent of the election module. Provision library_copies_v2/{copyId} from the real catalog, with a title and a boolean hold field. A librarian enters or scans the copy and selects an active borrower via a staff-only directory. On checkout, generate one Firestore auto-ID for the loan and keep that ID for retries. Student renewal takes the loan ID and the version currently shown. Librarian return takes the same loan ID. Illustrative school policy grants fourteen days, one renewal, and blocks renewal after the due instant or when a copy is on hold. Review the policy with the librarian, including how they correct a catalog hold.

~~~javascript
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const store = getFirestore();
const loanPeriodMs = 14 * 86400000;

function loanCheck(ok, code, message) {
  if (!ok) throw new HttpsError(code, message);
}

function loanId(value) {
  loanCheck(typeof value === "string" && /^[a-zA-Z0-9_-]{1,128}$/.test(value),
    "invalid-argument", "Invalid ID.");
  return value;
}

exports.schoolLibrary = onCall(async ({ auth, data }) => {
  loanCheck(auth?.uid, "unauthenticated", "Sign in to continue.");
  const uid = auth.uid;
  const id = loanId(data?.loanId);
  const loanRef = store.collection("library_loans_v2").doc(id);
  return store.runTransaction(async tx => {
    const me = (await tx.get(store.collection("school_members").doc(uid))).data();
    loanCheck(me?.active === true, "permission-denied", "Active school account required.");
    const staff = me.capabilities?.manage_library === true;
    const loan = (await tx.get(loanRef)).data();
    const now = Date.now();

    if (data.action === "checkout") {
      loanCheck(staff, "permission-denied", "Librarian required.");
      const copyId = loanId(data.copyId);
      const borrower = loanId(data.borrowerUid);
      if (loan) {
        loanCheck(loan.copyId === copyId && loan.borrower === borrower &&
          loan.issuedBy === uid, "already-exists", "Loan ID already used.");
        return { loanId: id, state: loan.state, dueMs: loan.dueAt.toMillis() };
      }
      const copyRef = store.collection("library_copies_v2").doc(copyId);
      const copy = (await tx.get(copyRef)).data();
      const member = (await tx.get(store.collection("school_members").doc(borrower))).data();
      loanCheck(member?.active === true, "failed-precondition", "Borrower is inactive or missing.");
      loanCheck(copy && typeof copy.title === "string" && copy.title.length > 0 &&
        copy.hold === false && !copy.currentLoanId, "failed-precondition", "Copy unavailable.");
      const dueMs = now + loanPeriodMs;
      tx.update(copyRef, { currentLoanId: id });
      tx.create(loanRef, { copyId, title: copy.title, borrower, issuedBy: uid,
        state: "open", version: 0, dueAt: Timestamp.fromMillis(dueMs) });
      return { loanId: id, state: "open", dueMs };
    }

    if (data.action === "return") loanCheck(staff, "permission-denied", "Librarian required.");
    else loanCheck(data.action === "renew" && loan?.borrower === uid,
      "permission-denied", "Borrower account required.");
    loanCheck(loan, "not-found", "Loan missing.");
    if (data.action === "return" && loan.state === "returned") return { state: "returned" };
    loanCheck(loan.state === "open", "failed-precondition", "This loan is closed.");
    const copyRef = store.collection("library_copies_v2").doc(loan.copyId);
    const copy = (await tx.get(copyRef)).data();
    loanCheck(copy?.currentLoanId === id, "failed-precondition", "Librarian must reconcile this copy.");

    if (data.action === "return") {
      tx.update(copyRef, { currentLoanId: null });
      tx.update(loanRef, { state: "returned", returnedBy: uid, returnedAt: Timestamp.fromMillis(now) });
      return { state: "returned" };
    }

    if (data.version === 0 && loan.version === 1) return { dueMs: loan.dueAt.toMillis() };
    loanCheck(data.version === 0 && loan.version === 0 && copy.hold === false &&
      loan.dueAt.toMillis() > now, "failed-precondition", "Contact the librarian to renew.");
    const dueMs = loan.dueAt.toMillis() + loanPeriodMs;
    tx.update(loanRef, { version: 1, dueAt: Timestamp.fromMillis(dueMs) });
    return { dueMs };
  });
});
~~~

Register the module after the existing Admin initialization with the same export pattern used for schoolElection. In the Home library modal replace the fixed book list with a borrower-scoped query. In a librarian route expose checkout and return only to staff with manage_library. Invoke schoolLibrary through the same authenticated transport as the election call, substituting its fixed endpoint and request payload. When a call fails, keep the item visible and offer refresh. A school without an imported catalog can hide the renew action and show an actual library contact instead.

~~~dart
final loans = FirebaseFirestore.instance.collection('library_loans_v2')
    .where('borrower', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
    .where('state', isEqualTo: 'open').snapshots();
~~~

~~~javascript
match /library_loans_v2/{loanId} {
  allow read: if hasElectionMembership() && (resource.data.borrower == request.auth.uid ||
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.capabilities.manage_library == true);
  allow write: if false;
}
match /library_copies_v2/{copyId} {
  allow read: if hasElectionMembership() &&
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.capabilities.manage_library == true;
  allow write: if false;
}
~~~

The membership helper above is defined in the election rules block. In a combined ruleset reuse the security guide's common active-member helper throughout. Test simultaneous checkouts of the same physical copy, a repeated renewal after timeout, a returned loan, a hold and a student's attempt to list a sibling's loans.



### Home, shared devices and backgrounds

1. On Home, group the elections, academics, shop and fixtures into a single place where students can find each action by name. lib/screens/home_screen.dart:3059–3186 currently dispatches several actions by comparing visible title strings, including an emoji. A wording or Arabic translation change can silently break navigation. Give each item a stable ID and an onTap callback. Keep staff management visible to authorized users inside the same feature students use.
2. For forms, ballots, medical leave, chat, and the scanner's result panel use the existing scaffold and surface colors as the page and card backgrounds. The project already defines a light scaffold at lib/theme/app_theme.dart:232 and a dark one at line 315. Reserve the house gradient for headers such as the Arena or the house profile. Use the theme's onSurface color for field instructions and a text label or icon alongside every status color. This helps Topaz and Emerald members read the same ballot and makes errors visible in both themes.
3. For the settings sheet, keep the existing theme controller. Offer System, Light and Dark because a boolean cannot preserve System. Persist sound/effects per account, and pass the preference to the actual effects controller. On shared hardware also honor the device's reduced-motion setting. An unimplemented push switch should be hidden or replaced with a description of the in-app inbox until device permission, token registration and unsubscribe all work.
4. For caches, store only an allowlisted read model. Separate a temporary view, a pending user draft, and an acknowledged official record. Use an account-scoped namespace on every read and write. Only mark the current view ready after checking the authenticated UID again following each await. Clear screen state and cancel subscriptions when switching accounts, even if the new account has the same house. AuthService.clearCache at lib/services/auth_service.dart:1861–1878 currently removes named defaults and swallows errors. Give “Clear cached views” a separate method that can report failure and preserves pending work.

A small route pattern for the Home action list, using the proposed election page. Substitute the actual existing route builders for the other tiles during integration.

~~~dart
ListTile(
  leading: const Icon(Icons.how_to_vote_outlined),
  title: const Text('School elections'),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const SchoolElectionsPage()),
  ),
)
~~~

For the election, homework, library and leave forms, replace page-specific background and label colors with this layout. bodyContent is the page's existing scrollable content. Giving the scrollable a bounded rectangle avoids nested vertical scroll views. In high contrast or reduced-motion mode keep the controls in the same positions.

~~~dart
Widget schoolFormPage(BuildContext context, String title, Widget bodyContent) {
  final theme = Theme.of(context);
  return Scaffold(
    backgroundColor: theme.scaffoldBackgroundColor,
    appBar: AppBar(title: Text(title)),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: SizedBox.expand(child: Card(
        color: theme.colorScheme.surface,
        margin: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 12),
        child: Padding(padding: const EdgeInsets.all(16), child: bodyContent),
      )),
    ))),
  );
}
~~~

Proposed cache helpers for disposable views in lib/services/auth_service.dart. Call them only with ownerUid obtained from the authenticated session. Never store a password, receipt containing vote choice, medical attachment or unsubmitted work under this disposable namespace. Delete known legacy keys separately during migration. Old unscoped personal data with unknown ownership should be discarded.

~~~dart
String viewPrefix(String ownerUid) {
  if (ownerUid.isEmpty) throw ArgumentError('An authenticated UID is required.');
  return 'asb.view.v2.' + Uri.encodeComponent(ownerUid).replaceAll('.', '%2E') + '.';
}

Future<void> clearSavedViews(String ownerUid) async {
  final prefs = await SharedPreferences.getInstance();
  final prefix = viewPrefix(ownerUid);
  for (final key in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
    if (!await prefs.remove(key)) throw StateError('Could not clear a cached view.');
  }
}
~~~

### Event wall moderation and reactions

At submission ask “Share a separate photo with the school?” only after the claim itself is saved. Use a distinct attachment and a staff-generated public derivative. Keep pending submissions in a private author/staff collection. Staff approval should create the public post and update its moderation record together. Strip sensitive proof links and any download-token URLs from the public copy. A student feed can then query only wall_public_v2 ordered by publishedAt. No newer pending entries can push older published posts out of that query. Withdraw a post by removing its public projection and restricting the separate public media path. Existing published download URLs need a separate access/token review.

Below is a complete server-side reaction example for that projection. It accepts a desired boolean and persists the user's individual reaction and the post's summary in one transaction. Repeating “like” leaves the count at one for that student. Call this from the existing thumb button when you replace the likes/liked_by writes at lib/screens/home_screen.dart:4499–4525. Allow active members to read public posts and only their own reaction. Deny client writes to both paths and retire the legacy broad grants.

~~~javascript
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore } = require("firebase-admin/firestore");
exports.setWallReaction = onCall(async ({ auth, data }) => {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in.");
  if (typeof data?.postId !== "string" || !/^[a-zA-Z0-9_-]{1,80}$/.test(data.postId) ||
      typeof data.liked !== "boolean") {
    throw new HttpsError("invalid-argument", "Invalid reaction.");
  }
  const db = getFirestore();
  const post = db.collection("wall_public_v2").doc(data.postId);
  const reaction = post.collection("reactions").doc(auth.uid);
  return db.runTransaction(async tx => {
    const [member, item, previous] = await tx.getAll(
      db.collection("school_members").doc(auth.uid), post, reaction);
    if (member.data()?.active !== true) throw new HttpsError("permission-denied", "School account required.");
    if (!item.exists) throw new HttpsError("not-found", "Post unavailable.");
    const count = item.get("likes");
    if (!Number.isSafeInteger(count) || count < 0 || (previous.exists && count === 0)) {
      throw new HttpsError("failed-precondition", "Moderator must reconcile the count.");
    }
    if (previous.exists === data.liked) return { liked: data.liked, count };
    const next = count + (data.liked ? 1 : -1);
    if (data.liked) tx.create(reaction, { liked: true });
    else tx.delete(reaction);
    tx.update(post, { likes: next });
    return { liked: data.liked, count: next };
  });
});
~~~

Publish public posts with likes initialized to zero and a fresh immutable post ID. On withdrawal retain the private moderation record. If a post is ever published again use a new ID to avoid inheriting orphaned reaction documents.

### House AI and personal records

Separate two actions in the chat screen. “My school records” routes the signed-in student to a structured owner-checked screen for attendance, homework or timetable. “Ask a general question” can send only text the student explicitly submits after seeing what is shared. Remove the prebuilt live-context blob and personal conversation history from the external payload. School staff should select an approved provider/configuration on the server, with a secret, a spending limit, short timeouts and an active-account check. Remove the key editor and delete its legacy preference during migration. During an outage offer the school information already available on this device, labeled with its last sync time. There is no need to generate a plausible attendance percentage.

A copyable boundary before enabling external AI. Route sensitive topics through explicit UI actions. The student's free text can itself contain personal data, so provide a preview and consent step before a general question is submitted. Keep analytics and diagnostic logs free of prompts and replies.

~~~dart
enum AdvisorAction { timetable, assignments, attendance, generalQuestion }

Map<String, String> generalQuestionPayload({
  required AdvisorAction selectedAction,
  required String question,
  required bool sharingConfirmed,
}) {
  final text = question.trim();
  if (selectedAction != AdvisorAction.generalQuestion || !sharingConfirmed) {
    throw StateError('Open the school record locally, or confirm sharing a general question.');
  }
  if (text.isEmpty || text.length > 600) {
    throw ArgumentError('Use a question between 1 and 600 characters.');
  }
  return {'question': text};
}
~~~

Use this at the send handler in lib/screens/house_ai_chat_screen.dart:162–175. The new server endpoint must apply its own length, identity, rate and spending checks. A client-side helper alone cannot restrict direct API calls. Keep the existing local answer route behind a verified identity check and remove both literal scholar fallbacks at lib/services/gemini_ai_service.dart:277 and 392. For unknown attendance, display “No attendance register available for this account”.



### Notifications and wallet buttons

The app writes notifications when a claim or role changes (for example lib/services/auth_service.dart:2733 and 2926), but I found no matching student inbox reader under lib. A student should be able to answer “what happened to my claim?” through the claim's current state even when notification delivery fails. Add an Inbox entry on Home. Use these reads and updates only after installing the owner-only inbox rules in the security guide. Create notifications on the server with stable event IDs and a timestamp. For older records missing timestamps, reconcile dates before enabling the ordered feed. A device push subscription is a separate feature.

~~~dart
final inbox = FirebaseFirestore.instance.collection('users')
    .doc(FirebaseAuth.instance.currentUser!.uid).collection('notifications');
final recentNotifications = inbox.orderBy('timestamp', descending: true)
    .limit(40).snapshots();

Future<void> markNotificationRead(DocumentReference<Map<String, dynamic>> notice) =>
    notice.update({'is_read': true});
~~~

In the wallet, lib/screens/digital_wallet_screen.dart:1240–1250 opens a success sheet when the user taps the wallet button. The PDF action at 1730–1746 reports a file in Downloads. The shown handlers never invoke a wallet provider or write PDF bytes. For the current feature, label the in-app action “View pass” and remove the PDF success message. For actual export, add a file producer, show the platform save/share dialog and use the returned outcome. Report cancel, save failure or the real saved location accurately. Issue provider-signed passes server-side only after the order or student identity is verified. Test by opening the exported PDF or finding the pass in the native wallet on a second screen.

## How to adopt the proposals together

1. **Establish identity and the access boundary.** Audit the school's real enrollment source, verify the initial staff accounts independently and design an invitation or registrar process. One scholar may have only one active canonical identity. Turn off client-controlled role grants. Review all overlapping legacy Firestore and Storage allow expressions. Restrict old public download URLs as well as new uploads. A matching allow can still grant access when another match denies it. [Firebase rule matching](https://firebase.google.com/docs/rules/rules-behavior)
2. **Use a separate Firebase project for the pilot.** Export staging data and test restoration. Import a small anonymized fixture with two students in different classes/houses, one assigned teacher, a librarian, a cashier and an election manager. Provision exactly the capability names used by each module. Use a private staff-assignment record for class-specific privileges. Keep each CommonJS module separate and initialize Admin once in the existing entry point. Use one authenticated callable client on each supported platform. The main election screen demonstrates an HTTPS transport for the dependencies in this checkout. Other Flutter snippets using cloud_functions need the corresponding platform integration or the same transport. [Callable functions](https://firebase.google.com/docs/functions/callable)
3. **Choose one reader and writer per official result.** Use activity_point_events_v2 as the common ledger, activity_house_totals_v2 for house totals and activity_contributors_v2 keyed by UID for personal totals. The proposed academic grade, claim and Brain Blitz writers use these paths. Move standings and contributor readers together. Use a separate versioned opening balance for each season or partition the schema by season before enabling repeated yearly resets. Store collections in the guides under their stated access policies. Never dual-award the same event to old and new standings.
4. **Migrate ambiguous cases by hand.** Staff must resolve unverified role assignments, unfinished elections, missing class/year ownership, duplicate scholar IDs, claims where OCR overwrote the reviewer state, and legacy store passes whose payment is unknown. Preserve a read-only historical copy. Verify an imported record's owner using a second account that must be denied access. Compare counts and totals before enabling a new screen.
5. **Migrate one complete workflow at a time.** Ship both the staff action and the student view. Close the old write grants, deploy new rules and callables in coordinated order, then enable the client feature for one class. Do read-before-write validation for each transaction and keep external effects such as provider requests outside transaction callbacks. Allow an app-version mismatch to produce a clear update-required message. [Firestore transactions and retries](https://firebase.google.com/docs/firestore/manage-data/transactions)
6. **Know how to stop.** Use an operator-controlled flag to stop new submissions if reconciliation fails. Preserve receipts and operation IDs, compare them to the authoritative ledger, and recover in staging first. Reopening permissive legacy rules or replaying local receipts would undo the access and integrity fixes.

## What was verified

- Reviewed the app by following role → screen → service → stored record/rules → next user's screen. Coverage includes home and onboarding, signup/login and switching, class work and records, elections, chat, AI, events and notices, claims and moderation, conduct, standings, sports, quizzes, wallet/store, scanner, library, settings, theming/localization, Firebase integration and release configuration. Visual suggestions are based on widget source. Generated platform glue, art/model content and dependency internals received no line-by-line audit.
- Ran the existing suite on a disposable copy using the installed Flutter SDK and locked package configuration. **253 tests passed.** Isolated Dart analysis of lib, test and tool found **zero errors, zero warnings and 20 informational lints**. The current election duplicate-vote test at test/widget_test.dart:6468 never publishes a real ballot. Passing it cannot demonstrate that a student can complete the action under deployed rules.
- Extracted the proposed Flutter election page and ran the Dart analyzer against this checkout's installed dependencies. **No issues found.** Exercised the proposed election handler in memory across 12 scenario groups, including adding and freezing candidates, wrong constituency, the closing boundary, repeat voting, replacement accounts with the same scholar number, and winner/tie/zero-vote certification.
- Ran additional in-memory checks on the proposed grading, points, store, claims, quiz, library and reaction handlers. Grading, a claim award and a quiz award added to the same house and personal totals, with repeat submission contributing zero extra points. The counter flow rejected early collection, student-confirmed cash and the wrong payment amount. Renewal, replay and return produced one extension. These checks use a transactional test double. They exercise the extracted logic, not Firebase's concurrency implementation.
- **Still to verify before adoption:** emulator rules for each role, composite indexes, lock contention, invalid legacy documents, network loss after commit, physical QR scans, Arabic/RTL layouts, large text and restore from backup. No production access or deployment was part of this review. The guides include implementation code for the selected workflows and describe the remaining UI wiring, school policy choices, migration work, and tests. They are not a single patch to apply to a live school.

