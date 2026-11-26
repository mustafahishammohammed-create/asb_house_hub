"use strict";

// Run only against the local demo project; never use production credentials.
const { test, before, after, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, Timestamp: ClientTimestamp } = require("firebase/firestore");
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
  env = await initializeTestEnvironment({ projectId, firestore: {
    host, port: Number(port),
    rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
  } });
  app = initializeApp({ projectId });
  db = getFirestore(app);
  election = require("../elections-v2").schoolElection;
});

beforeEach(async () => { await env.clearFirestore(); });
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
  const client = env.authenticatedContext("student").firestore();
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
  await assertSucceeds(setDoc(doc(alice, "users/bob/notifications/dm-1"), {
    title: "New Message",
    body: "Hello",
    timestamp: ClientTimestamp.now(),
    is_read: false,
    type: "chat_message",
    room_id: "alice_bob",
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

test("rules (O21): zero-price or pre-verified student merch orders are rejected", async () => {
  await db.doc("users/buyer").set(student("66666"));
  const buyer = env.authenticatedContext("buyer", { email: "66666@asianschool.bh" }).firestore();
  await assertFails(setDoc(doc(buyer, "orders/free-verified"), {
    receipt_id: "free-verified",
    items: [{ id: "hoodie", qty: 1 }],
    status: "verified",
    user_id: "buyer",
    total_bhd: 0,
    total_pts: 0,
  }));
  await assertSucceeds(setDoc(doc(buyer, "orders/paid-order"), {
    receipt_id: "paid-order",
    items: [{ id: "hoodie", qty: 1 }],
    status: "ready",
    user_id: "buyer",
    scholar_no: "66666",
    total_bhd: 12.5,
    total_pts: 0,
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
