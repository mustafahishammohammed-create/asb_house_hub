"use strict";

// Run only against the local demo project; never use production credentials.
const { test, before, after, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc, Timestamp: ClientTimestamp } = require("firebase/firestore");
const { ref: storageRef, uploadBytes, uploadString, getBytes, deleteObject } = require("firebase/storage");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

const projectId = "demo-asb-audit";
let env, app, db, election;
const student = (scholar = "12345") => ({
  scholar_no: scholar, full_name: "Test Scholar", role: "student",
  house_name: "ruby", grade: 10, class_verified: false,
});
const member = (extra = {}) => ({
  scholar_no: "12345", display_name: "Test Scholar", role: "student",
  house: "ruby", grade: 10, active: true,
  capabilities: { manage_elections: false }, ...extra,
});

before(async () => {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST || "", /^(127\.0\.0\.1|localhost):\d+$/,
    "Run with firebase emulators:exec --project demo-asb-audit --config firebase.audit.json");
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(":");
  const storageEnv = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
  const config = {
    projectId,
    firestore: {
      host, port: Number(port),
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
    },
  };
  if (storageEnv) {
    const [sHost, sPort] = storageEnv.split(":");
    config.storage = {
      host: sHost,
      port: Number(sPort),
      rules: fs.readFileSync(path.join(__dirname, "../../storage.rules"), "utf8"),
    };
  }
  env = await initializeTestEnvironment(config);
  app = initializeApp({ projectId });
  db = getFirestore(app);
  election = require("../elections-v2").schoolElection;
});

beforeEach(async () => {
  await env.clearFirestore();
  if (process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    await env.clearStorage();
  }
});
after(async () => {
  if (env) await env.cleanup();
  if (app) await deleteApp(app);
});

test("rules: a student can provision a nonprivileged roster row", async () => {
  await db.doc("users/student").set(student());
  const client = env.authenticatedContext("student").firestore();
  await assertSucceeds(setDoc(doc(client, "school_members/student"), member()));
});

test("rules: a student cannot grant library or unknown capabilities", async () => {
  await db.doc("users/student").set(student());
  const client = env.authenticatedContext("student").firestore();
  for (const capability of ["manage_library", "future_admin"]) {
    await assertFails(setDoc(doc(client, "school_members/student"), member({
      capabilities: { manage_elections: false, [capability]: true },
    })));
  }
});

test("rules: teaching staff cannot promote themselves to super admin via roster", async () => {
  await db.doc("users/teacher").set({ ...student(), role: "teacher" });
  const client = env.authenticatedContext("teacher").firestore();
  await assertFails(setDoc(doc(client, "school_members/teacher"), member({ role: "admin" })));
});

test("rules: super admins can provision staff capabilities", async () => {
  const client = env.authenticatedContext("administrator", { admin: true }).firestore();
  await assertSucceeds(setDoc(doc(client, "school_members/librarian"), member({
    role: "staff", capabilities: { manage_library: true },
  })));
});

test("rules: a deactivated member cannot reactivate their roster record", async () => {
  await db.doc("users/student").set(student());
  await db.doc("school_members/student").set(member({ active: false }));
  const client = env.authenticatedContext("student").firestore();
  await assertFails(updateDoc(doc(client, "school_members/student"), { active: true }));
});

test("rules: outsiders cannot read messages or forge read receipts", async () => {
  await db.doc("chats/room").set({ participants: ["alice", "bob"] });
  await db.doc("chats/room/messages/message").set({
    sender_id: "alice", sender_name: "Alice", text: "Private message",
    timestamp: Timestamp.now(), is_read: false,
  });
  const client = env.authenticatedContext("outsider").firestore();
  await assertFails(getDoc(doc(client, "chats/room/messages/message")));
  await assertFails(updateDoc(doc(client, "chats/room/messages/message"), { is_read: true }));
  const recipient = env.authenticatedContext("bob").firestore();
  await assertSucceeds(updateDoc(doc(recipient, "chats/room/messages/message"), { is_read: true }));
});

test("rules: clients cannot write election tallies or participation", async () => {
  const client = env.authenticatedContext("student").firestore();
  await assertFails(setDoc(doc(client, "election_polls_v2/poll/counts/candidate"), { count: 100 }));
  await assertFails(setDoc(doc(client, "election_polls_v2/poll/participation/key"), { receipt: "fake" }));
});

test("rules: class wildcard cannot expose another scholar's report card or attendance", async () => {
  await db.doc("users/student").set(student());
  const client = env.authenticatedContext("student", { email: "12345@asianschool.bh" }).firestore();
  await db.doc("classes/10A/report_cards/private").set({ scholar_no: "99999", grades: { Math: 90 } });
  await db.doc("classes/10A/attendance/99999/records/day").set({ scholar_no: "99999", status: "absent" });
  await assertFails(getDoc(doc(client, "classes/10A/report_cards/private")));
  await assertFails(getDoc(doc(client, "classes/10A/attendance/99999/records/day")));
  await db.doc("classes/10A/report_cards/own").set({ scholar_no: "12345", grades: { Math: 95 } });
  await assertSucceeds(getDoc(doc(client, "classes/10A/report_cards/own")));
});

test("rules: the class catch-all cannot bypass assignment validation", async () => {
  const client = env.authenticatedContext("administrator", { admin: true }).firestore();
  await assertFails(setDoc(doc(client, "classes/10A/assignments/invalid"), { title: 42 }));
});

const call = (uid, action, data = {}) => election.run({ auth: { uid }, data: { action, pollId: "poll", ...data } });
async function seedElection() {
  await db.doc("school_members/manager").set(member({ role: "admin", capabilities: { manage_elections: true } }));
  await db.doc("school_members/candidate-a").set(member({ scholar_no: "20001", display_name: "Candidate A" }));
  await db.doc("school_members/candidate-b").set(member({ scholar_no: "20002", display_name: "Candidate B", house: "topaz" }));
  await db.doc("school_members/voter").set(member());
  await call("manager", "create", { title: "Test ballot", position: "headBoy", minGrade: 9, maxGrade: 12,
    house: "all", startMs: Date.now() - 60000, endMs: Date.now() + 3600000 });
  const a = await call("manager", "add", { scholarNo: "20001", statement: "Candidate A statement" });
  await call("manager", "add", { scholarNo: "20002", statement: "Candidate B statement" });
  await call("manager", "publish");
  return a.candidateId;
}

test("election: duplicate votes award only one tally and return the same receipt", async () => {
  const candidateId = await seedElection();
  const results = await Promise.all([call("voter", "vote", { candidateId }), call("voter", "vote", { candidateId })]);
  assert.equal(results[0].receipt, results[1].receipt);
  assert.equal((await db.doc(`election_polls_v2/poll/counts/${candidateId}`).get()).get("count"), 1);
});

test("election: cancelled ballots cannot be certified or award points", async () => {
  const candidateId = await seedElection();
  await call("voter", "vote", { candidateId });
  await call("manager", "cancel");
  await assert.rejects(call("manager", "certify"), { code: "failed-precondition" });
  assert.equal((await db.doc("house_points/ruby").get()).exists, false);
});

test("election: certification records the real scholar number and awards exactly once", async () => {
  const candidateId = await seedElection();
  await call("voter", "vote", { candidateId });
  await call("manager", "close");
  await call("manager", "certify");
  await call("manager", "certify");
  assert.equal((await db.doc("election_gazettes/poll").get()).get("winner_scholar_no"), "20001");
  assert.equal((await db.doc("house_points/ruby").get()).get("total_points"), 100);
});

test("election: candidate addition and removal are auditable", async () => {
  await seedElection();
  const events = (await db.collection("election_polls_v2/poll/audit").get()).docs.map(d => d.get("event"));
  assert.equal(events.filter(e => e === "add").length, 2);
  await call("manager", "create", { pollId: "draft", title: "Draft", position: "headBoy", minGrade: 9, maxGrade: 12,
    house: "all", startMs: Date.now() - 1000, endMs: Date.now() + 60000 });
  const candidate = await call("manager", "add", { pollId: "draft", scholarNo: "20001", statement: "Statement" });
  await call("manager", "remove", { pollId: "draft", candidateId: candidate.candidateId });
  const removed = (await db.collection("election_polls_v2/draft/audit").get()).docs.some(d => d.get("event") === "remove");
  assert.equal(removed, true);
});

test("rules (O02): account cannot self-register a forged scholar_no and access victim records", async () => {
  const outsideClient = env.authenticatedContext("evil-uid", { email: "attacker@outside.test", email_verified: true }).firestore();
  await assertFails(setDoc(doc(outsideClient, "users/evil-uid"), student("99999")));
  await db.doc("classes/10A/report_cards/victim").set({ scholar_no: "99999", grades: { Math: 95 } });
  await assertFails(getDoc(doc(outsideClient, "classes/10A/report_cards/victim")));

  const validClient = env.authenticatedContext("real-uid", { email: "54321@asianschool.bh" }).firestore();
  await assertSucceeds(setDoc(doc(validClient, "users/real-uid"), student("54321")));

  // A matching users profile without the school email binding is not enough.
  await db.doc("users/profile-only").set(student("99999"));
  const profileOnly = env.authenticatedContext("profile-only", { email: "attacker@outside.test" }).firestore();
  await assertFails(getDoc(doc(profileOnly, "classes/10A/report_cards/victim")));

  // A matching email without the users profile binding is not enough either.
  const emailOnly = env.authenticatedContext("email-only", { email: "99999@asianschool.bh" }).firestore();
  await assertFails(getDoc(doc(emailOnly, "classes/10A/report_cards/victim")));
});

test("rules (O04): suspended or deactivated staff loses privileged read/write access", async () => {
  await db.doc("users/suspended-teacher").set({ ...student("40001"), role: "teacher", status: "suspended" });
  await db.doc("medical_leaves/private-leave").set({ scholar_no: "12345", student_name: "Private Student", status: "pending" });
  const suspendedClient = env.authenticatedContext("suspended-teacher").firestore();
  await assertFails(getDoc(doc(suspendedClient, "medical_leaves/private-leave")));

  await db.doc("users/inactive-member").set({ ...student("40002"), role: "teacher", status: "active" });
  await db.doc("school_members/inactive-member").set(member({ scholar_no: "40002", role: "teacher", active: false }));
  const inactiveClient = env.authenticatedContext("inactive-member").firestore();
  await assertFails(getDoc(doc(inactiveClient, "medical_leaves/private-leave")));

  // Suspension also revokes ordinary content reads, but the account can still
  // read its own profile so the client can explain the suspension.
  await db.doc("users/suspended-student").set({ ...student("40003"), status: "suspended" });
  await db.doc("announcements/notice").set({ title: "Notice", body: "Body", timestamp: Timestamp.now() });
  const suspendedStudent = env.authenticatedContext("suspended-student", { email: "40003@asianschool.bh" }).firestore();
  await assertSucceeds(getDoc(doc(suspendedStudent, "users/suspended-student")));
  await assertFails(getDoc(doc(suspendedStudent, "announcements/notice")));
});

test("rules (O07): arbitrary student cannot spoof notifications to other users, chat partner can", async () => {
  await db.doc("users/alice").set(student("11111"));
  const alice = env.authenticatedContext("alice", { email: "11111@asianschool.bh" }).firestore();
  await assertFails(setDoc(doc(alice, "users/victim/notifications/spoof"), {
    title: "Urgent Notice",
    body: "Fake fee notice",
    timestamp: ClientTimestamp.now(),
    priority: "urgent",
  }));

  await db.doc("chats/alice_bob").set({ participants: ["alice", "bob"] });
  await assertFails(setDoc(doc(alice, "users/bob/notifications/dm-missing-sender"), {
    title: "New Message",
    body: "Hello",
    timestamp: ClientTimestamp.now(),
    is_read: false,
    type: "chat_message",
    room_id: "alice_bob",
  }));
  await assertFails(setDoc(doc(alice, "users/bob/notifications/dm-spoofed-sender"), {
    title: "New Message",
    body: "Hello",
    timestamp: ClientTimestamp.now(),
    is_read: false,
    type: "chat_message",
    room_id: "alice_bob",
    sender_id: "bob",
  }));
  await assertSucceeds(setDoc(doc(alice, "users/bob/notifications/dm-1"), {
    title: "New Message",
    body: "Hello",
    timestamp: ClientTimestamp.now(),
    is_read: false,
    type: "chat_message",
    room_id: "alice_bob",
    sender_id: "alice",
  }));
});

test("rules (O08): student cannot self-assert AI verified status on house_claims create", async () => {
  await db.doc("users/student-a").set({ ...student("33333"), house_name: "topaz" });
  const client = env.authenticatedContext("student-a", { email: "33333@asianschool.bh" }).firestore();
  await assertFails(setDoc(doc(client, "house_claims/forged-ai"), {
    scholar_no: "33333",
    student_name: "Test Scholar",
    house_name: "topaz",
    activity_title: "Debate Winner",
    points: 100,
    cert_url: "https://example.test/cert.jpg",
    status: "pending",
    ai_status: "verified",
    ai_confidence: 100,
    auto_validated: true,
  }));
  await assertFails(setDoc(doc(client, "house_claims/wrong-name"), {
    scholar_no: "33333",
    student_name: "Someone Else",
    house_name: "topaz",
    activity_title: "Debate Winner",
    points: 100,
    cert_url: "uploading://wrong-name",
    status: "pending",
    ai_status: "pending_scan",
  }));
  await assertSucceeds(setDoc(doc(client, "house_claims/clean-claim"), {
    scholar_no: "33333",
    student_name: "Test Scholar",
    house_name: "topaz",
    activity_title: "Debate Winner",
    points: 100,
    cert_url: "uploading://clean-claim",
    status: "pending",
    ai_status: "pending_scan",
  }));

  // Reviewer decisions must be pending-only, attributable, timestamped, and
  // must leave the claim's identity and points untouched.
  await db.doc("house_claims/review-me").set({
    scholar_no: "33333",
    student_name: "Test Scholar",
    house_name: "topaz",
    activity_title: "Debate Winner",
    points: 100,
    cert_url: "https://example.test/review.jpg",
    status: "pending",
    ai_status: "pending_scan",
    created_at: Timestamp.now(),
  });
  await db.doc("users/teacher-reviewer").set({ ...student("49002"), role: "teacher" });
  const reviewer = env.authenticatedContext("teacher-reviewer").firestore();
  await assertFails(updateDoc(doc(reviewer, "house_claims/review-me"), {
    status: "approved",
  }));
  await assertFails(updateDoc(doc(reviewer, "house_claims/review-me"), {
    status: "approved",
    reviewer_id: "someone-else",
    verified_at: ClientTimestamp.now(),
  }));
  await assertSucceeds(updateDoc(doc(reviewer, "house_claims/review-me"), {
    status: "approved",
    reviewer_id: "teacher-reviewer",
    verified_at: ClientTimestamp.now(),
  }));
  await assertFails(updateDoc(doc(reviewer, "house_claims/review-me"), {
    status: "rejected",
    reviewer_id: "teacher-reviewer",
    verified_at: ClientTimestamp.now(),
    rejection_reason: "Changed my mind",
  }));
  await assertFails(updateDoc(doc(reviewer, "house_claims/review-me"), {
    points: 500,
  }));
});

test("rules (O12/O13): Blaze election audits and library v2 collections reject direct client tampering", async () => {
  await db.doc("school_members/manager").set(member({ role: "admin", capabilities: { manage_elections: true } }));
  await db.doc("election_polls_v2/p1/audit/a1").set({ event: "add", actor: "manager" });
  const mgr = env.authenticatedContext("manager").firestore();
  await assertSucceeds(getDoc(doc(mgr, "election_polls_v2/p1/audit/a1")));
  await assertFails(setDoc(doc(mgr, "election_polls_v2/p1/audit/a2"), { event: "fake" }));

  await db.doc("library_loans_v2/l1").set({ borrower: "u1", issuedBy: "lib" });
  const u1 = env.authenticatedContext("u1").firestore();
  const u2 = env.authenticatedContext("u2").firestore();
  await assertSucceeds(getDoc(doc(u1, "library_loans_v2/l1")));
  await assertFails(getDoc(doc(u2, "library_loans_v2/l1")));
  await assertFails(setDoc(doc(u1, "library_loans_v2/l2"), { borrower: "u1" }));
});

test("rules (O19): admin can persist current SportsTrophyRecord payload", async () => {
  const adminClient = env.authenticatedContext("admin-user", { admin: true }).firestore();
  await assertSucceeds(setDoc(doc(adminClient, "sports_trophies/t1"), {
    trophy_id: "t1",
    title: "Inter-House Football",
    tournament_title: "Inter-House Football",
    sport_type: "football",
    winning_house: "ruby",
    runner_up_house: "topaz",
    points_awarded: 100,
    runner_up_points: 50,
    mvp_scholar_no: null,
    mvp_name: null,
    awarded_at: new Date().toISOString(),
    commissioner_name: "Sports Department",
    trophy_tier: "goldCup",
  }));
});

test("rules (O21): zero-price, pre-verified, or mismatched student merch orders are rejected", async () => {
  await db.doc("users/buyer").set(student("66666"));
  const buyer = env.authenticatedContext("buyer", { email: "66666@asianschool.bh" }).firestore();
  const validOrder = {
    receipt_id: "paid-order",
    items: [{ id: "hoodie", qty: 1 }],
    status: "placed",
    user_id: "buyer",
    scholar_no: "66666",
    house: "ruby",
    total_bhd: 12.5,
    total_pts: 0,
  };
  await assertFails(setDoc(doc(buyer, "orders/free-verified"), {
    ...validOrder,
    receipt_id: "free-verified",
    status: "verified",
    total_bhd: 0,
  }));
  await assertFails(setDoc(doc(buyer, "orders/ready-order"), {
    ...validOrder,
    receipt_id: "ready-order",
    status: "ready",
  }));
  await assertFails(setDoc(doc(buyer, "orders/no-price"), {
    ...validOrder,
    receipt_id: "no-price",
    total_bhd: 0,
  }));
  await assertFails(setDoc(doc(buyer, "orders/other-scholar"), {
    ...validOrder,
    receipt_id: "other-scholar",
    scholar_no: "77777",
  }));
  await assertFails(setDoc(doc(buyer, "orders/other-house"), {
    ...validOrder,
    receipt_id: "other-house",
    house: "topaz",
  }));
  await assertFails(setDoc(doc(buyer, "orders/missing-owner"), {
    ...validOrder,
    receipt_id: "missing-owner",
    user_id: "someone-else",
  }));
  await assertSucceeds(setDoc(doc(buyer, "orders/paid-order"), validOrder));

  // Admin tooling may still import a verified order for fulfilment.
  const admin = env.authenticatedContext("order-admin", { admin: true }).firestore();
  await assertSucceeds(setDoc(doc(admin, "orders/admin-import"), {
    ...validOrder,
    receipt_id: "admin-import",
    status: "verified",
  }));
});

test("rules (O27/O28): chat room non-member probing fails and photo messages succeed for members", async () => {
  await db.doc("users/u1").set(student("77771"));
  const u1 = env.authenticatedContext("u1", { email: "77771@asianschool.bh" }).firestore();
  await assertFails(getDoc(doc(u1, "chats/victimA_victimB")));
  await assertSucceeds(getDoc(doc(u1, "chats/staff1_u1")));

  await db.doc("chats/staff1_u1").set({ participants: ["staff1", "u1"] });
  await assertSucceeds(setDoc(doc(u1, "chats/staff1_u1/messages/m1"), {
    sender_id: "u1",
    sender_name: "Test Scholar",
    text: "",
    attachment_url: "data:image/jpeg;base64,AA==",
    timestamp: ClientTimestamp.now(),
    is_read: false,
    push_alert_triggered: true,
  }));
});

test("rules (O33): user without integer grade cannot RSVP to grade-restricted events", async () => {
  await db.doc("events/senior-event").set({
    status: "published",
    house_scope: "all",
    grade_min: 11,
    grade_max: 12,
    end_time: Timestamp.fromMillis(Date.now() + 60000),
  });
  const noGradeClient = env.authenticatedContext("no-grade").firestore();
  await assertFails(setDoc(doc(noGradeClient, "events/senior-event/registrations/no-grade"), {
    uid: "no-grade",
    event_id: "senior-event",
  }));

  await db.doc("users/senior-kid").set({ ...student("88888"), grade: 11 });
  const seniorClient = env.authenticatedContext("senior-kid", { email: "88888@asianschool.bh" }).firestore();
  await assertSucceeds(setDoc(doc(seniorClient, "events/senior-event/registrations/senior-kid"), {
    uid: "senior-kid",
    event_id: "senior-event",
  }));
});

test("rules (O16): report card honours merit claim enforces GPA >= 3.80 and one-time flip", async () => {
  await db.doc("users/honour-kid").set(student("91001"));
  await db.doc("classes/10A/report_cards/low-gpa").set({
    scholar_no: "91001",
    overall_gpa: 3.4,
    is_merit_claimed: false,
  });
  await db.doc("classes/10A/report_cards/high-gpa").set({
    scholar_no: "91001",
    overall_gpa: 3.9,
    is_merit_claimed: false,
  });

  const kid = env.authenticatedContext("honour-kid", { email: "91001@asianschool.bh" }).firestore();
  await assertFails(updateDoc(doc(kid, "classes/10A/report_cards/low-gpa"), { is_merit_claimed: true }));
  await assertSucceeds(updateDoc(doc(kid, "classes/10A/report_cards/high-gpa"), { is_merit_claimed: true }));
  await assertFails(updateDoc(doc(kid, "classes/10A/report_cards/high-gpa"), { is_merit_claimed: false }));
});

test("rules (O29): student cannot initiate a DM directly with another student", async () => {
  await db.doc("users/student-1").set(student("92001"));
  await db.doc("users/student-2").set(student("92002"));
  await db.doc("users/teacher-1").set({ ...student("49001"), role: "teacher" });

  const s1 = env.authenticatedContext("student-1", { email: "92001@asianschool.bh" }).firestore();
  await assertFails(setDoc(doc(s1, "chats/student-1_student-2"), {
    participants: ["student-1", "student-2"],
  }));
  await assertSucceeds(setDoc(doc(s1, "chats/student-1_teacher-1"), {
    participants: ["student-1", "teacher-1"],
  }));
});

test("rules (Batch 1 O04): suspended accounts cannot mutate own notifications or read own orders", async () => {
  await db.doc("users/suspended-1").set({ ...student("41001"), status: "suspended" });
  await db.doc("users/suspended-1/notifications/n1").set({
    title: "Notice",
    body: "Original",
    timestamp: Timestamp.now(),
    sender_id: "staff-1",
    is_read: false,
  });
  await db.doc("orders/ord-1").set({
    receipt_id: "ord-1",
    items: [{ id: "cap", qty: 1 }],
    status: "placed",
    user_id: "suspended-1",
    scholar_no: "41001",
    total_bhd: 5.0,
    total_pts: 0,
  });

  const susp = env.authenticatedContext("suspended-1", { email: "41001@asianschool.bh" }).firestore();
  await assertFails(updateDoc(doc(susp, "users/suspended-1/notifications/n1"), { is_read: true }));
  await assertFails(deleteDoc(doc(susp, "users/suspended-1/notifications/n1")));
  await assertFails(getDoc(doc(susp, "orders/ord-1")));
});

test("rules (Batch 1 O07): notifications enforce category/priority, house scope, and class recipient scope", async () => {
  await db.doc("users/alice").set({ ...student("11112"), house_name: "ruby", class_id: "10A", class_verified: true });
  await db.doc("users/bob").set({ ...student("11113"), house_name: "sapphire", class_id: "10B", class_verified: true });
  await db.doc("users/ruby-captain").set({ ...student("22221"), role: "house_captain", house_name: "ruby" });
  await db.doc("users/rep-10a").set({ ...student("22222"), role: "class_representative", class_id: "10A", class_verified: true });
  await db.doc("chats/alice_bob").set({ participants: ["alice", "bob"] });

  const alice = env.authenticatedContext("alice", { email: "11112@asianschool.bh" }).firestore();
  await assertFails(setDoc(doc(alice, "users/bob/notifications/urgent-chat"), {
    title: "Fake Urgent Alert",
    body: "Admin action required",
    timestamp: ClientTimestamp.now(),
    type: "chat_message",
    category: "system",
    priority: "urgent",
    room_id: "alice_bob",
    sender_id: "alice",
  }));

  const rubyCapt = env.authenticatedContext("ruby-captain", { email: "22221@asianschool.bh" }).firestore();
  await assertFails(setDoc(doc(rubyCapt, "users/bob/notifications/cross-house"), {
    title: "House Notice",
    body: "Wrong house",
    timestamp: ClientTimestamp.now(),
    category: "house",
    priority: "normal",
    sender_id: "ruby-captain",
  }));
  await assertSucceeds(setDoc(doc(rubyCapt, "users/alice/notifications/same-house"), {
    title: "Ruby Assembly",
    body: "Meet at 3pm",
    timestamp: ClientTimestamp.now(),
    category: "house",
    priority: "high",
    sender_id: "ruby-captain",
  }));

  const rep = env.authenticatedContext("rep-10a", { email: "22222@asianschool.bh" }).firestore();
  await assertFails(setDoc(doc(rep, "users/bob/notifications/wrong-class"), {
    title: "10A Update",
    body: "Out of scope recipient",
    timestamp: ClientTimestamp.now(),
    type: "class_announcement",
    category: "class",
    priority: "normal",
    room_id: "10A",
    sender_id: "rep-10a",
  }));
  await assertSucceeds(setDoc(doc(rep, "users/alice/notifications/in-class"), {
    title: "10A Update",
    body: "Homework due tomorrow",
    timestamp: ClientTimestamp.now(),
    type: "class_announcement",
    category: "class",
    priority: "normal",
    room_id: "10A",
    sender_id: "rep-10a",
  }));
});

test("rules (Batch 1 O08/O21/O44): block claim self-approval, ocr_keywords spoofing, free order points, and verify administrator parity", async () => {
  await db.doc("users/ruby-capt").set({ ...student("31001"), role: "house_captain", house_name: "ruby" });
  await db.doc("users/sapphire-kid").set({ ...student("31002"), house_name: "sapphire" });
  await db.doc("house_claims/capt-own").set({
    scholar_no: "31001",
    student_name: "Test Scholar",
    house_name: "ruby",
    activity_title: "Science Fair",
    points: 50,
    cert_url: "https://example.test/c1.jpg",
    status: "pending",
    ai_status: "pending_scan",
  });
  await db.doc("house_claims/rival-claim").set({
    scholar_no: "31002",
    student_name: "Test Scholar",
    house_name: "sapphire",
    activity_title: "Chess",
    points: 25,
    cert_url: "https://example.test/c2.jpg",
    status: "pending",
    ai_status: "pending_scan",
  });

  const capt = env.authenticatedContext("ruby-capt", { email: "31001@asianschool.bh" }).firestore();
  await assertFails(setDoc(doc(capt, "house_claims/with-ocr"), {
    scholar_no: "31001",
    student_name: "Test Scholar",
    house_name: "ruby",
    activity_title: "Olympiad",
    points: 50,
    cert_url: "uploading://with-ocr",
    status: "pending",
    ocr_keywords: ["Principal", "ASB"],
  }));
  await assertFails(updateDoc(doc(capt, "house_claims/capt-own"), {
    status: "approved",
    reviewer_id: "ruby-capt",
    verified_at: ClientTimestamp.now(),
  }));
  await assertFails(getDoc(doc(capt, "house_claims/rival-claim")));

  // Order create rejects nonzero free total_pts; administrator updates medical leaves
  await db.doc("users/ord-kid").set(student("66667"));
  const kid = env.authenticatedContext("ord-kid", { email: "66667@asianschool.bh" }).firestore();
  await assertFails(setDoc(doc(kid, "orders/free-pts"), {
    receipt_id: "free-pts",
    items: [{ id: "cap", qty: 1 }],
    status: "placed",
    user_id: "ord-kid",
    scholar_no: "66667",
    house: "ruby",
    total_bhd: 5.0,
    total_pts: 250,
  }));

  await db.doc("users/admin-officer").set({ ...student("49010"), role: "administrator" });
  await db.doc("medical_leaves/l1").set({ scholar_no: "66667", student_name: "Test Scholar", status: "pending" });
  const adminOfficer = env.authenticatedContext("admin-officer").firestore();
  await assertSucceeds(getDoc(doc(adminOfficer, "medical_leaves/l1")));
});

test("storage rules (O09/O04): enforce UID claim ownership, raster MIME allowlist, no overwrites, and active school_members", async () => {
  if (!process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    return;
  }
  await db.doc("users/s-owner").set(student("55001"));
  await db.doc("users/s-other").set(student("55002"));
  await db.doc("users/s-deact").set(student("55003"));
  await db.doc("school_members/s-deact").set(member({ scholar_no: "55003", active: false }));

  const ownerStorage = env.authenticatedContext("s-owner", { email: "55001@asianschool.bh" }).storage();
  const otherStorage = env.authenticatedContext("s-other", { email: "55002@asianschool.bh" }).storage();
  const deactStorage = env.authenticatedContext("s-deact", { email: "55003@asianschool.bh" }).storage();

  const jpgBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);
  const validClaim = storageRef(ownerStorage, "house_claims/s-owner/55001_claim1.jpg");
  await assertSucceeds(uploadBytes(validClaim, jpgBytes, { contentType: "image/jpeg" }));

  // Overwrite, delete, SVG XSS, wrong scholar prefix, other UID, deactivated member, and unlisted paths must all fail
  await assertFails(uploadBytes(validClaim, jpgBytes, { contentType: "image/jpeg" }));
  await assertFails(deleteObject(validClaim));
  await assertFails(uploadString(storageRef(ownerStorage, "house_claims/s-owner/55001_xss.svg"), "<svg/>", "raw", { contentType: "image/svg+xml" }));
  await assertFails(uploadBytes(storageRef(ownerStorage, "house_claims/s-owner/99999_spoof.jpg"), jpgBytes, { contentType: "image/jpeg" }));
  await assertFails(uploadBytes(storageRef(otherStorage, "house_claims/s-owner/55002_hijack.jpg"), jpgBytes, { contentType: "image/jpeg" }));
  await assertFails(getBytes(storageRef(otherStorage, "house_claims/s-owner/55001_claim1.jpg")));
  await assertFails(uploadBytes(storageRef(deactStorage, "house_claims/s-deact/55003_blocked.jpg"), jpgBytes, { contentType: "image/jpeg" }));
  await assertFails(uploadBytes(storageRef(ownerStorage, "unlisted_folder/file.jpg"), jpgBytes, { contentType: "image/jpeg" }));
});
