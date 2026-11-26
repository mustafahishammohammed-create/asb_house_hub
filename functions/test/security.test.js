"use strict";

// Run only against the local demo project; never use production credentials.
const { test, before, after, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc } = require("firebase/firestore");
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
