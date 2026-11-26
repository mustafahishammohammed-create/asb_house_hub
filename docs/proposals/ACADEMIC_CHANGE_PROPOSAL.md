# Academics, attendance and school communications

This companion to the app review traces actions from the person pressing the button to the student who should see the result. Paths and line numbers refer to the reviewed checkout. The code below is proposed for a future implementation. Security rules, server commands, new client screens and data migration must be tested together in an isolated Firebase project.

## Where the workflows break

| Feature | What happens in this checkout | Suggested change |
|---|---|---|
| Class routing | Home combines class and division or invents a fallback (`lib/screens/home_screen.dart` 1642, 1664, 2369). Exam publication writes under keys such as `Grade 10` (`lib/services/auth_service.dart` 1206–1264). A pupil reading `Grade 10 B` can miss a grade-wide exam. | Keep a trusted section ID and numeric grade separately. Resolve the student from `school_members/{uid}`. Route section work by section, grade exams by grade and the academic year. Show an enrollment message if either value is missing. |
| Homework | Add, delete and status controls appear in the shared tab (`academics_screen.dart` 1736, 2040, 2143, 2270). Status cycles back from graded to pending. The service writes the shared assignment, catches denial, updates the cache and attempts a client-generated merit claim (`auth_service.dart` 922–994). One child's work has no durable independent record. | Teacher publishes a task. Each student submits once into their own document. Their teacher grades that submission. Derive the award once from the published task. See the working paths below. |
| Timetable | The day view exposes period management and a prefilled weekly template (`academics_screen.dart` 447, 996, 1067, 1145). Clearing a day deletes documents sequentially and catches failure (`auth_service.dart` 706–732). A partial delete can look successful. | Only assigned staff edit a draft version. Preview template teachers, rooms and times. Validate overlaps and switch one `published_version` pointer once all periods are saved. Retain the previous version for recovery. |
| Examinations | Invalid range endpoints silently expand to the first or last supported grade. The ID only distinguishes subject and time (`auth_service.dart` 1206–1236). The client can also treat local demo data as published when Firebase is unavailable (1264–1293). | Use roster-derived grade choices, reject invalid ranges and room/section conflicts, generate one stable exam ID per operation, and report published only when its batch commits. Record a cancellation or new revision under the same ID. |
| Report cards and honours | All authenticated accounts can read the report collection. Omitting the scholar filter opens a whole-class query (`firestore.rules` 611–624, `auth_service.dart` 1397–1418). Publication derives its ID from scholar and term, omits the academic year and resets the claim flag. Honours accepts caller-supplied GPA and points, awarding before trying to mark the card (`auth_service.dart` 1436–1497, 1518–1551). | Store each version under the trusted owner's UID, school year and term. Give the issuing teacher class-limited access. Compute merit from the published result on the server with a unique award per owner/year/term. Record corrections with issuer, timestamp and reason. |
| Attendance and leave | The general class wildcard makes confidential records readable to all signed-in users even though a more specific rule tests the scholar (`firestore.rules` 616–624). Cache lookup can return the last person's whole attendance list (`auth_service.dart` 1578–1613). The UI labels approved leave “Approved (Excused)” (`academics_screen.dart` 5820), but approval only updates a leave record and local cache (`auth_service.dart` 4749–4787). | Restrict all overlapping reads, require real enrollment, and perform review and attendance changes together. A separate reviewer permission grants access to the prescription. A normal class teacher needs the attendance status only. |
| Medical evidence | Requests carry a Base64 photo and the shared device cache stores whole requests (`lib/models/medical_leave_request.dart` 95–101, `auth_service.dart` 4657–4704, 4709–4745). Some forms invent scholar `2310910` when identity is absent (`academics_screen.dart` 5767, 6158, 6911). | Disable these actions while enrollment is unresolved. Store private attachments separately, scoped by authenticated UID and request ID. Fetch on demand, verify owner, type, actual size and reviewer scope, and keep diagnosis out of attendance documents and global preferences. |
| Notices | The publisher sends `target_audience`, `attachment_url` and `date` outside the rule allowlist, returns true even on exception, and the form closes before writing. The feed queries the newest five across all students (`firestore.rules` 418–430, 739–742, `auth_service.dart` 2430–2440, 4626–4652, `home_screen.dart` 3914–3969). | Split grade feeds or use one query with a server-validated visibility field. Bind membership to the route and show errors without losing the draft. A label alone cannot protect a circular. |
| Events | Campus events are streamed and browsed (`auth_service.dart` 1785–1804, `lib/screens/events_screen.dart` 43–66). No matching campus-event publisher was found. The event DTO exports extra fields outside the announcement validator (`lib/models/campus_event.dart` 78–92, `firestore.rules` 744–747). House scope is absent from the list filter. The separate event wall serves a different workflow. | Add a staff composer, preview, publish, edit and cancel. Keep drafts private. Query public and authorized house feeds. Use server timestamps and enforce venue, valid category and start before end. Show concluded/cancelled rather than leaving the manual live flag active forever. |
| Student profile and conduct | Metadata lookup can accept the first result by full name. The profile opens conduct controls using cached role, name or scholar attributes (`lib/widgets/student_profile_modal.dart` 81–145, 289, 462, 664). Multiple people can share a name. | Pass a roster-backed UID into every action, allow search by name for discovery, and ask staff to select the identified person and class. Show student-visible merits separately from private conduct notes. Require the assigned staff capability on the server before changing points. |
| Offline and empty views | The academic assignment builder (`academics_screen.dart` 1669–1684) substitutes cached items for a real empty snapshot. Timetable, report and attendance writers often only refresh caches for non-empty snapshots (`auth_service.dart` 598, 1424, 1653). | Replace cached results even when an authorized remote list is empty. Distinguish loading, offline, permission failure, and a genuinely empty class. Keep reports, prescriptions and personal attendance out of SharedPreferences. |

**Status note (2026-11-11).** The **Events** row is implemented for Spark scope: staff composer with preview/publish/edit/cancel, private drafts, house-scoped student reads, optional from-grade/to-grade audience targeting enforced against `users.grade`, server timestamps, venue/category/time validation, concluded/cancelled rendering, and self-owned registration records with a staff participant list. Rules were compiled and deployed to `asb-house-hub`. Grade bands are applied client-side to event lists (Firestore rules are not filters) and enforced by rules on direct reads and RSVPs. The remaining limits are no authenticated end-to-end Firebase run, no device-calendar or push reminder, and no automatic points for attendance. Evidence: `development_plan/M8_VERIFICATION.md`.

## Homework from publication through grading

Assumptions for the example: the registrar has provisioned `school_members/{uid}` with `active`, `role`, `class_id` and the other trusted fields described in the main guide. A new server-managed `academic_classes/{classId}/instructors/{uid}` document with `active: true` grants teaching access only to that class. No client can provision either collection. The staff workflow must create those assignments before enabling teacher controls. Use slash-free stable class IDs from the roster. Only the Admin SDK can change award or graded records. The sample allows one text submission before the deadline, a score from 0–100 and a fixed homework merit of 20 per graded task; school policy can change those decisions.

**Firestore rules.** Insert the following inside the existing database documents match. These are new paths. Keep the global default deny and retire the old `classes/{classId}/{allSubcollections=**}` grant after cutting over each old reader. A narrower rule cannot revoke a permission granted by a second matching block. Do not expose membership provisioning through client-writable fields.

~~~text
function academicActive() {
  return request.auth != null &&
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.active == true;
}
function teachesSection(c) {
  return academicActive() &&
    exists(/databases/$(database)/documents/academic_classes/$(c)/instructors/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/academic_classes/$(c)/instructors/$(request.auth.uid)).data.active == true;
}
function studiesIn(c) {
  return academicActive() &&
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.role == 'student' &&
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.class_id == c;
}
match /academic_classes/{c}/instructors/{teacherUid} {
  allow get: if academicActive() && request.auth.uid == teacherUid;
}
match /academic_classes/{c}/tasks/{task} {
  allow read: if studiesIn(c) || teachesSection(c);
  allow create: if teachesSection(c) &&
    request.resource.data.keys().hasAll(['title','subject','description','due_date','created_by','created_at','points_reward']) &&
    request.resource.data.keys().hasOnly(['title','subject','description','due_date','created_by','created_at','points_reward']) &&
    request.resource.data.title is string && request.resource.data.title.size() > 0 && request.resource.data.title.size() <= 150 &&
    request.resource.data.subject is string && request.resource.data.subject.size() > 0 &&
    request.resource.data.subject.size() <= 80 &&
    request.resource.data.description is string && request.resource.data.description.size() <= 3000 &&
    request.resource.data.due_date is timestamp && request.resource.data.due_date > request.time &&
    request.resource.data.created_by == request.auth.uid &&
    request.resource.data.created_at == request.time && request.resource.data.points_reward == 20;
  match /submissions/{studentUid} {
    allow get: if teachesSection(c) || (studiesIn(c) && request.auth.uid == studentUid);
    allow list: if teachesSection(c);
    allow create: if studiesIn(c) && request.auth.uid == studentUid &&
      request.resource.data.keys().hasAll(['body','status','submitted_at']) &&
      request.resource.data.keys().hasOnly(['body','status','submitted_at']) &&
      request.resource.data.body is string && request.resource.data.body.size() > 0 &&
      request.resource.data.body.size() <= 4000 && request.resource.data.status == 'submitted' &&
      request.resource.data.submitted_at == request.time &&
      get(/databases/$(database)/documents/academic_classes/$(c)/tasks/$(task)).data.due_date >= request.time;
  }
}
~~~

**Flutter.** Put these top-level functions in a proposed academic service library that imports `cloud_firestore/cloud_firestore.dart` and `firebase_auth/firebase_auth.dart`. Supply a `DocumentReference` obtained from `FirebaseFirestore.instance.collection('academic_classes').doc(classId).collection('tasks').doc(taskId)`. The teacher form generates `taskId` with `.doc().id` once on opening, and retains it through retry. The transaction either creates the task or recognizes an identical preceding commit. Changing a published task requires a separate staff correction workflow.

~~~dart
Future<void> publishClassTask(
  DocumentReference<Map<String, dynamic>> task, {
  required String title,
  required String subject,
  required String description,
  required DateTime due,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Sign in first');
  final fields = <String, dynamic>{
    'title': title.trim(), 'subject': subject.trim(),
    'description': description.trim(), 'created_by': user.uid,
    'points_reward': 20, 'due_date': Timestamp.fromDate(due.toUtc()),
  };
  if (fields['title'] == '' || fields['subject'] == '') {
    throw ArgumentError('Enter a title and subject');
  }
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(task);
    if (snap.exists) {
      if (fields.entries.every((e) => snap.data()?[e.key] == e.value)) return;
      throw StateError('This task already exists with different content');
    }
    tx.set(task, {...fields, 'created_at': FieldValue.serverTimestamp()});
  });
}

Future<void> submitClassTask(
  DocumentReference<Map<String, dynamic>> task, String answer,
) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('Sign in first');
  final body = answer.trim();
  if (body.isEmpty || body.length > 4000) {
    throw ArgumentError('Enter an answer of up to 4000 characters');
  }
  final ref = task.collection('submissions').doc(uid);
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final previous = await tx.get(ref);
    if (previous.exists) {
      if (previous.data()?['body'] == body) return;
      throw StateError('A different submission already exists');
    }
    tx.set(ref, {
      'body': body, 'status': 'submitted',
      'submitted_at': FieldValue.serverTimestamp(),
    });
  });
}
~~~

In `AssignmentsTab`, stream tasks for the enrolled class. On the student's task detail subscribe to `task.collection('submissions').doc(uid).snapshots()`. Show **Submit** for an absent submission, **Submitted** for a recorded answer, and the published score for a graded one. A teacher selects **Review submissions** on a task, lists that task's submissions, then selects the student UID from the saved document ID. Retire `_cycleAssignmentStatus` and the old awarding call, and remove edit/delete actions until there is a staff-only revision/archive flow. Preserve the input and show a retry action on failure. Transactions require a connection, so clearly label an offline draft.

**Teacher grading and merit.** Proposed CommonJS module `functions/academicReview.js`. After the existing `admin.initializeApp()` in the functions entry point, add `Object.assign(exports, require('./academicReview'));`. Install the compatible Flutter `cloud_functions` package during implementation and call `FirebaseFunctions.instance.httpsCallable('gradeClassSubmission').call({'classId': classId, 'taskId': taskId, 'studentUid': studentUid, 'score': score})`. Surface the callable's code and a localized action to the reviewer. On the Admin SDK all authorization below is explicit.

~~~javascript
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {createHash} = require('node:crypto');
const db = getFirestore();
const id = (v) => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const houses = new Set(['ruby', 'sapphire', 'emerald', 'topaz']);
function fail(code, message) { throw new HttpsError(code, message); }

exports.gradeClassSubmission = onCall(async (req) => {
  const teacherUid = req.auth?.uid;
  if (!teacherUid) fail('unauthenticated', 'Sign in first.');
  const {classId, taskId, studentUid, score} = req.data || {};
  if (![classId, taskId, studentUid].every(id) ||
      !Number.isInteger(score) || score < 0 || score > 100) {
    fail('invalid-argument', 'Invalid section, task, student or score.');
  }
  const members = db.collection('school_members');
  const section = db.collection('academic_classes').doc(classId);
  const task = section.collection('tasks').doc(taskId);
  const submission = task.collection('submissions').doc(studentUid);
  const sourceKey = createHash('sha256').update(submission.path).digest('hex');
  const award = db.collection('activity_point_events_v2').doc('grade_' + sourceKey);

  return db.runTransaction(async (tx) => {
    const [teacher, assignment, pupil, taskSnap, answer, ledger] = await tx.getAll(
      members.doc(teacherUid), section.collection('instructors').doc(teacherUid),
      members.doc(studentUid), task, submission, award);
    if (teacher.data()?.active !== true || assignment.data()?.active !== true) {
      fail('permission-denied', 'This class requires an assigned teacher.');
    }
    if (!answer.exists || !taskSnap.exists) fail('not-found', 'Task or submission missing.');
    if (answer.get('status') === 'graded' && ledger.exists && answer.get('score') === score) {
      return {status: 'graded', score};
    }
    if (ledger.exists || answer.get('status') !== 'submitted') {
      fail('failed-precondition', 'Use a reviewed correction for an existing grade.');
    }
    const student = pupil.data();
    if (student?.active !== true || student.role !== 'student' || student.class_id !== classId ||
        !houses.has(student.house) || !id(student.scholar_no)) {
      fail('failed-precondition', 'Resolve enrollment or transfer with the registrar.');
    }
    const points = taskSnap.get('points_reward');
    if (points !== 20) fail('failed-precondition', 'Unknown reward policy.');
    const timestamp = FieldValue.serverTimestamp();
    tx.update(submission, {status: 'graded', score, graded_by: teacherUid, graded_at: timestamp});
    tx.create(award, {source: 'grade', sourceId: submission.path, uid: studentUid,
      house: student.house, points, reviewerUid: teacherUid, createdAt: timestamp});
    tx.set(db.collection('activity_house_totals_v2').doc(student.house), {
      house_name: student.house, total_points: FieldValue.increment(points),
      academics_points: FieldValue.increment(points), last_updated: timestamp,
    }, {merge: true});
    tx.set(db.collection('activity_contributors_v2').doc(studentUid), {
      total_contributed: FieldValue.increment(points), merits_count: FieldValue.increment(1),
      last_updated: timestamp,
    }, {merge: true});
    return {status: 'graded', score};
  });
});
~~~

This example uses the same point ledger and UID-based contributor and house totals as the activities guide. Reconcile the opening balance before switching the leaderboard reader. Legacy writers use either the scholar number or a house/scholar key (`auth_service.dart` 2643, 3023, 3190–3192). In the latter function a write precedes a subsequent transaction read and the error path reports success (3194–3228). Restrict legacy score writes at cutover. For report honours, use a separate award type and unique owner/year/term key, read the authoritative published report in that transaction and validate the configured threshold there.

## Leave review that affects the attendance register

Proposed policy: a reviewer can approve up to 31 consecutive **school-local dates** per request. The authoritative calendar holds one document per date including closures. Unmarked and absent school days become excused. An existing present, late, mixed-period or independently excused record requires an explicit reconciliation; that conflict prevents the whole approval so the reviewer can see exactly what needs attention. Keep the submitted diagnosis separate from the public class and teacher register. The school should choose its own limits, treatment of overlapping requests and attendance denominator.

Use a new `academic_leave_requests/{leaveId}` document with `student_uid`, `class_id`, `from_day` and `through_day` (YYYY-MM-DD), `status`, `reason` and `created_at`. The student-facing form takes dates from the school calendar, not the device clock. Submit under a persistent request ID, verify the current student's membership and never accept another person's scholar number or name. A server import populates `academic_classes/{classId}/calendar/{day}` with `instructional: true/false`. The example writes `academic_classes/{classId}/students/{uid}/days/{day}`. Redirect the attendance tab AND staff attendance editor to this path together. Freeze edits to the old path during the transition. If staff correct an approved day later, require an audited correction with the expected record version.

Append the following to the proposed academic functions module. This block uses `db`, `id`, `fail`, `onCall` and `FieldValue` from the grading example.

~~~javascript
function schoolDates(first, last) {
  const parse = (value) => {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      fail('invalid-argument', 'Use a school-calendar date.');
    }
    const ms = Date.parse(value + 'T00:00:00Z');
    if (!Number.isFinite(ms) || new Date(ms).toISOString().slice(0, 10) !== value) {
      fail('invalid-argument', 'Invalid calendar date.');
    }
    return ms;
  };
  const start = parse(first), end = parse(last), dayMs = 86400000;
  if (end < start || end - start > 30 * dayMs) fail('invalid-argument', 'Choose 1 to 31 days.');
  return Array.from({length: 1 + (end - start) / dayMs},
    (_, n) => new Date(start + n * dayMs).toISOString().slice(0, 10));
}
exports.reviewClassLeave = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) fail('unauthenticated', 'Sign in first.');
  const {leaveId, decision} = req.data || {};
  if (!id(leaveId) || !['approved','rejected'].includes(decision)) {
    fail('invalid-argument', 'Invalid request or decision.');
  }
  const leave = db.collection('academic_leave_requests').doc(leaveId);
  return db.runTransaction(async (tx) => {
    const [actor, request] = await tx.getAll(db.collection('school_members').doc(uid), leave);
    if (actor.data()?.active !== true || actor.data()?.capabilities?.review_medical !== true) {
      fail('permission-denied', 'School medical reviewer required.');
    }
    if (!request.exists) fail('not-found', 'Leave request missing.');
    const r = request.data();
    if (r.status === decision) return {status: decision};
    if (r.status !== 'pending') fail('failed-precondition', 'A decision is already recorded.');
    const stamp = FieldValue.serverTimestamp();
    const outcome = {status: decision, reviewed_by: uid, reviewed_at: stamp};
    if (decision === 'rejected') {
      tx.update(leave, outcome);
      return {status: decision};
    }
    if (!id(r.class_id) || !id(r.student_uid)) fail('failed-precondition', 'Invalid roster link.');
    const days = schoolDates(r.from_day, r.through_day);
    const section = db.collection('academic_classes').doc(r.class_id);
    const calendar = await tx.getAll(...days.map(d => section.collection('calendar').doc(d)));
    if (calendar.some(s => typeof s.data()?.instructional !== 'boolean')) {
      fail('failed-precondition', 'Complete the section calendar first.');
    }
    const openDays = calendar.filter(s => s.get('instructional')).map(s => s.id);
    if (!openDays.length) fail('failed-precondition', 'The request contains no school days.');
    const register = section.collection('students').doc(r.student_uid).collection('days');
    const current = await tx.getAll(...openDays.map(d => register.doc(d)));
    for (const snap of current) {
      if (!snap.exists) continue;
      const data = snap.data();
      if (data.status !== 'absent' ||
          Object.values(data.period_breakdown || {}).some(status => status !== 'absent')) {
        fail('failed-precondition', 'Review the existing attendance for ' + snap.id);
      }
    }
    for (const snap of current) {
      const prior = snap.data() || {};
      const breakdown = Object.fromEntries(
        Object.keys(prior.period_breakdown || {}).map(key => [key, 'excused']));
      tx.set(snap.ref, {day: snap.id, status: 'excused', period_breakdown: breakdown,
        source_leave: leaveId, marked_at: stamp, marked_by: uid}, {merge: true});
    }
    tx.update(leave, {...outcome, applied_days: openDays});
    return {status: decision};
  });
});
~~~

Rules for the example. Clients may only create their own pending request. The reviewer list uses the specific medical capability. A student listing their requests must supply `where('student_uid', isEqualTo: uid)`. Use a registrar-controlled, school-wide medical reviewer capability only when this matches actual policy. Otherwise scope the capability by section or campus. The optional evidence upload needs its own access rules and on-demand authorized download before enabling that UI.

~~~text
function medicalReviewer() {
  return academicActive() &&
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.get('capabilities', {}).get('review_medical', false) == true;
}
match /academic_leave_requests/{leaveId} {
  allow read: if medicalReviewer() ||
    (academicActive() && resource.data.student_uid == request.auth.uid);
  allow create: if studiesIn(request.resource.data.class_id) &&
    request.resource.data.keys().hasAll(['student_uid','class_id','from_day','through_day','reason','status','created_at']) &&
    request.resource.data.keys().hasOnly(['student_uid','class_id','from_day','through_day','reason','status','created_at']) &&
    request.resource.data.student_uid == request.auth.uid && request.resource.data.status == 'pending' &&
    request.resource.data.reason is string && request.resource.data.reason.size() > 0 &&
    request.resource.data.reason.size() <= 1000 &&
    request.resource.data.from_day is string && request.resource.data.from_day.matches('[0-9]{4}-[0-9]{2}-[0-9]{2}') &&
    request.resource.data.through_day is string && request.resource.data.through_day.matches('[0-9]{4}-[0-9]{2}-[0-9]{2}') &&
    request.resource.data.created_at == request.time;
}
match /academic_classes/{c}/students/{uid}/days/{day} {
  allow read: if teachesSection(c) || (studiesIn(c) && request.auth.uid == uid);
}
~~~

For the attendance history, parse `day` as a school-local date and read `status` and `period_breakdown`; the v1 parser expects `date`. Keep prescription URLs, doctor details and sensitive reasons out of these records. Use authenticated, storage-rule-checked SDK reads for evidence. Do not display an excused confirmation until the reviewer command acknowledges the register update. For staff manual attendance, use a separate class-scoped server command with optimistic revision checking, exact dates, a trusted student ID and an audit trail; direct client writes to the v2 register are denied in this sample.


## School notices and events with an actual audience

Use two new collections plus a staff composer. Only a published document enters these collections; keep staff drafts private. In this example an eligible publisher is an active school member whose server-owned capability is `publish_bulletins`. All students can see school-wide notices, including grades outside the three named bands. The school can choose separate publishing capabilities for events and circulars.

~~~text
function schoolPublisher() {
  return academicActive() &&
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.get('capabilities', {}).get('publish_bulletins', false) == true;
}
function schoolBand() {
  let grade = get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.grade;
  return grade >= 6 && grade <= 8 ? 'middle' :
    (grade >= 9 && grade <= 10 ? 'secondary' :
    (grade >= 11 && grade <= 12 ? 'senior' : 'all'));
}
match /school_notices_v2/{notice} {
  allow read: if schoolPublisher() || (academicActive() &&
    (resource.data.audience == 'all' || resource.data.audience == schoolBand()));
  allow create: if schoolPublisher() &&
    request.resource.data.keys().hasOnly(['title','content','category','audience','created_at','author_uid']) &&
    request.resource.data.title is string && request.resource.data.title.size() > 0 && request.resource.data.title.size() <= 200 &&
    request.resource.data.content is string && request.resource.data.content.size() > 0 && request.resource.data.content.size() <= 5000 &&
    request.resource.data.category in ['Academic','Sports','Examination','Holiday & Closure','General'] &&
    request.resource.data.audience in ['all','middle','secondary','senior'] &&
    request.resource.data.created_at == request.time && request.resource.data.author_uid == request.auth.uid;
}
match /school_events_v2/{event} {
  allow read: if schoolPublisher() || (academicActive() &&
    (resource.data.house_scope == 'all' ||
    resource.data.house_scope == get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.house));
  allow create: if schoolPublisher() &&
    request.resource.data.keys().hasOnly(['title','description','category','house_scope','start_time','end_time','venue','created_at','author_uid']) &&
    request.resource.data.title is string && request.resource.data.title.size() > 0 && request.resource.data.title.size() <= 200 &&
    request.resource.data.description is string && request.resource.data.description.size() <= 3000 &&
    request.resource.data.venue is string && request.resource.data.venue.size() > 0 && request.resource.data.venue.size() <= 120 &&
    request.resource.data.category in ['cultural','sports','academic','arts','tech'] &&
    request.resource.data.house_scope in ['all','ruby','sapphire','emerald','topaz'] &&
    request.resource.data.start_time is timestamp && request.resource.data.end_time is timestamp &&
    request.resource.data.start_time < request.resource.data.end_time &&
    request.resource.data.created_at == request.time && request.resource.data.author_uid == request.auth.uid;
}
~~~

Flutter code for the two publication actions and feeds. Add to the proposed academic service library with the Firestore and Auth imports. `draftId` is a new Firestore auto-ID generated once when the composer opens. Save it with a school-approved draft if drafts must survive a restart. Transaction retries recognize the same payload. Avoid auto-retrying a changed draft over a published document.

~~~dart
Future<void> _publishSchoolItem(
  String collection, String draftId, Map<String, dynamic> fields,
) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('Sign in first');
  final firestore = FirebaseFirestore.instance;
  final ref = firestore.collection(collection).doc(draftId);
  final content = {...fields, 'author_uid': uid};
  await firestore.runTransaction((tx) async {
    final saved = await tx.get(ref);
    if (saved.exists) {
      if (content.entries.every((e) => saved.data()?[e.key] == e.value)) return;
      throw StateError('This publication already exists with different content');
    }
    tx.set(ref, {...content, 'created_at': FieldValue.serverTimestamp()});
  });
}

const noticeAudiences = {
  'All Students': 'all', 'Middle School (6-8)': 'middle',
  'Secondary (9-10)': 'secondary', 'Senior Secondary (11-12)': 'senior',
};

Future<void> publishSchoolCircular({
  required String draftId, required String title, required String content,
  required String category, required String audienceLabel,
}) {
  final audience = noticeAudiences[audienceLabel];
  if (audience == null || title.trim().isEmpty || content.trim().isEmpty) {
    throw ArgumentError('Choose an audience and supply a title and message');
  }
  return _publishSchoolItem('school_notices_v2', draftId, {
    'title': title.trim(), 'content': content.trim(), 'category': category,
    'audience': audience,
  });
}

Stream<QuerySnapshot<Map<String, dynamic>>> noticesForGrade(int grade) {
  final band = grade >= 6 && grade <= 8 ? 'middle'
      : grade >= 9 && grade <= 10 ? 'secondary'
      : grade >= 11 && grade <= 12 ? 'senior' : 'all';
  return FirebaseFirestore.instance.collection('school_notices_v2')
      .where('audience', whereIn: {'all', band}.toList())
      .orderBy('created_at', descending: true).limit(5).snapshots();
}

Future<void> publishCampusEvent({
  required String draftId, required String title, required String description,
  required String category, required String house, required String venue,
  required DateTime start, required DateTime end,
}) {
  if (title.trim().isEmpty || venue.trim().isEmpty || !end.isAfter(start)) {
    throw ArgumentError('Enter a title, venue and valid start/end times');
  }
  return _publishSchoolItem('school_events_v2', draftId, {
    'title': title.trim(), 'description': description.trim(), 'category': category,
    'house_scope': house.toLowerCase(), 'venue': venue.trim(),
    'start_time': Timestamp.fromDate(start.toUtc()), 'end_time': Timestamp.fromDate(end.toUtc()),
  });
}

Stream<QuerySnapshot<Map<String, dynamic>>> eventsForHouse(String house) =>
    FirebaseFirestore.instance.collection('school_events_v2')
      .where('house_scope', whereIn: {'all', house.toLowerCase()}.toList())
      .orderBy('start_time').snapshots();
~~~

In `home_screen.dart` 3954–3972 await `publishSchoolCircular` inside the open modal, disable Publish while pending, show a form error on exception, and pop only after the write succeeds. Replace the `date` string at line 3757 with a localized date from the `created_at` timestamp. The checked-in notice form has no attachment picker. Add an explicitly scoped attachment workflow if required. In `events_screen.dart` 43–66 add **Create event** for the authorized staff user, pass local school date/time and house scope into `publishCampusEvent`, and read `eventsForHouse` for a pupil. Use `CampusEvent.fromMap(doc.data(), docId: doc.id)` with the new stream. Register, deploy and verify the `audience ASC / created_at DESC` and `house_scope ASC / start_time ASC` composite indexes in the isolated project. Review index errors separately from an empty feed. Search or list archives with pagination in a large deployment. Staff editing and cancellation still require a revision-checked command and explicit status rendering before rollout.

## Migration and release checks

1. Snapshot existing rules, school records and staff permissions. Build a roster reconciliation table for UID, scholar, academic year, grade and section. Flag ambiguous names, duplicate scholars, invalid dates and records currently attached only to a fallback ID. Resolve those with school staff.
2. Import class-scoped tasks without attributing a shared legacy status to every student. Import individual submissions or awards only where a separate source actually identifies a pupil. Keep unresolved work in a staff reconciliation queue. Include the school year in report IDs and retain report history.
3. Copy and reconcile existing attendance by scholar and date. Review already-approved leaves without matching register entries individually. Never populate future, closure or present school days from legacy approvals without reconciling the calendar. Restrict old and new records before exposing v2 data. Revoke broad reads on retired paths and purge stale per-account caches on account change.
4. Seed verified memberships, staff assignments, school calendars, publication capabilities and indexes. Query in the emulator as the actual student/teacher accounts. Integrate one vertical workflow at a time with versioned clients. Block outdated mutating clients during cutover; avoid old and new points writers running together. Keep a read-only export for rollback and record reconciliation counts.
5. Test one teacher and two students in the same class plus an unrelated user. The students see the same task and can submit different answers. A second submit racing the first produces one reviewable submission. An unrelated teacher cannot grade. Two simultaneous grading commands create one award and one set of point increments. A different score after grading requests a correction. Try expired deadlines and revoked memberships directly against Firestore.
6. Test a three-day leave with one school closure, an existing mixed attendance record, opposing reviewers and a dropped response after commit. No partial register changes on conflict. Only approved instructional days get excused. An inactive pupil cannot upload or submit a new request. Ensure the school medical reviewer owns the decision in the audit log.
7. Publish a grade 9–10 circular and a Ruby event. Check the actual feed and try to open the document from a grade 7 Sapphire account. A failed publication retains text. A real empty result clears yesterday's entries. Switching from medical staff to a pupil on a shared device must clear the previous person's details before the first frame.
8. Publish the same term for two school years, schedule an exam for Grade 10 sections A and B, clear an entire timetable day and review the UI on another device. Verify the correct section membership, date, school-local time, revision, language and actor. A signed-out device or unknown enrollment must show a recovery path instead of an invented scholar or class.

These code blocks implement the proposed task, submission, grading, leave-review, notice and event publication paths. Staff roster administration, attendance correction, secure attachment intake, historical imports, notice/event revisions and the corresponding full Flutter forms are specified integration work. The two embedded CommonJS blocks passed a Node syntax check. In-memory checks exercised leap day, invalid dates, reversed and oversized ranges, grading replay, conflicting grades, an attendance conflict, school closures and leave replay. These checks used a test double. Firestore rule evaluation, SDK transactions under contention, indexes, Flutter UI and device behavior still need validation in an isolated project.
