/**
 * ASB House Hub - Zero-Trust Elections Module v2
 * Server-authoritative voting, candidate nomination, ballot publishing, and certification.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { randomUUID, createHash } = require("node:crypto");

const db = getFirestore();
const houses = ["ruby", "sapphire", "emerald", "topaz"];
const positions = [
  "headBoy",
  "headGirl",
  "houseCaptain",
  "viceCaptain",
  "culturalSecretary",
  "sportsCaptain",
  "prefect"
];

const fail = (code, message) => {
  throw new HttpsError(code, message);
};

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
  return (
    person?.active === true &&
    person.role === "student" &&
    Number.isInteger(person.grade) &&
    person.grade >= poll.minGrade &&
    person.grade <= poll.maxGrade &&
    houses.includes(person.house) &&
    (poll.house === "all" || person.house === poll.house)
  );
}

function draftSettings(data) {
  const title = boundedText(data.title, 120, "title");
  const { position, minGrade, maxGrade, house, startMs, endMs } = data;
  if (
    !positions.includes(position) ||
    !["all", ...houses].includes(house) ||
    !Number.isInteger(minGrade) ||
    !Number.isInteger(maxGrade) ||
    minGrade < 1 ||
    maxGrade > 12 ||
    minGrade > maxGrade ||
    !Number.isSafeInteger(startMs) ||
    !Number.isSafeInteger(endMs) ||
    startMs < 0 ||
    endMs <= startMs ||
    endMs > 4102444800000
  ) {
    fail("invalid-argument", "Check the position, house, grades and voting window.");
  }
  return { title, position, minGrade, maxGrade, house, startMs, endMs };
}

function publicHeader(draft) {
  const { title, position, minGrade, maxGrade, house, startMs, endMs } = draft;
  return {
    title,
    position,
    minGrade,
    maxGrade,
    house,
    opensAt: Timestamp.fromMillis(startMs),
    closesAt: Timestamp.fromMillis(endMs)
  };
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
      requireState(
        box.status === "published" &&
          now >= box.opensAt.toMillis() &&
          now < box.closesAt.toMillis(),
        "Voting is closed."
      );
      if (!eligible(person, box)) fail("permission-denied", "Outside the eligible electorate.");
      const candidateId = resourceId(data.candidateId);
      requireState(
        box.candidates.some((c) => c.id === candidateId),
        "Candidate is not on this ballot."
      );
      const receipt = randomUUID();
      tx.create(participation, { receipt });
      tx.set(
        poll.collection("counts").doc(candidateId),
        { count: FieldValue.increment(1) },
        { merge: true }
      );
      return { receipt, alreadyRecorded: false };
    }

    if (person.capabilities?.manage_elections !== true) {
      fail("permission-denied", "Election manager required.");
    }
    const current = (await tx.get(draft)).data();
    if (action === "create") {
      const settings = draftSettings(data);
      if (current) {
        requireState(
          current.createdBy === uid &&
            Object.keys(settings).every((k) => current[k] === settings[k]),
          "Draft ID already used. Open the existing draft."
        );
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
      const totals = await tx.getAll(...box.candidates.map((c) => poll.collection("counts").doc(c.id)));
      const rows = box.candidates.map((c, i) => {
        const n = totals[i].exists ? totals[i].get("count") : 0;
        requireState(Number.isSafeInteger(n) && n >= 0, "Invalid count. Review the tally.");
        return { id: c.id, count: n };
      });
      const total = rows.reduce((sum, r) => sum + r.count, 0);
      const max = Math.max(...rows.map((r) => r.count));
      const leaders = total ? rows.filter((r) => r.count === max).map((r) => r.id) : [];
      const outcome = !total ? "no_votes" : leaders.length > 1 ? "tie" : "winner";
      const result = { rows, total, leaders, outcome };
      tx.update(poll, { status: "certified", result, certifiedAt: FieldValue.serverTimestamp() });
      tx.update(draft, { status: "certified", certifiedBy: uid });

      // In winner outcome, award 100 points to winner's genuine house and publish gazette (C8, M10)
      if (outcome === "winner" && leaders.length === 1) {
        const winner = box.candidates.find((c) => c.id === leaders[0]);
        const winnerHouse = (winner?.house || box.house || "ruby").toLowerCase();
        if (winnerHouse && winnerHouse !== "all") {
          tx.set(
            db.collection("house_points").doc(winnerHouse),
            {
              house_name: winnerHouse,
              total_points: FieldValue.increment(100),
              last_updated: FieldValue.serverTimestamp()
            },
            { merge: true }
          );
        }
        const runnerUpCount = rows.length > 1 ? Math.max(...rows.filter((r) => r.id !== leaders[0]).map((r) => r.count)) : 0;
        tx.set(db.collection("election_gazettes").doc(pollId), {
          ballot_id: pollId,
          ballot_title: box.title,
          running_position: box.position,
          winner_scholar_no: winner?.uid || winner?.id || "",
          winner_name: winner?.name || "Elected Candidate",
          winner_house: winnerHouse,
          total_votes_received: max,
          victory_margin_votes: max - runnerUpCount,
          house_points_awarded: 100,
          commissioner_name: person.display_name || "Returning Officer",
          commissioner_role: person.role || "Electoral Commissioner",
          certified_at: FieldValue.serverTimestamp(),
          proclamation_text: `By order of the Electoral Commission, ${winner?.name || "the candidate"} is officially certified as ${box.position}, conferring +100 championship points to ${winnerHouse.toUpperCase()} House.`
        });
      }

      return { pollId, result };
    }

    if (action === "close") {
      const box = (await tx.get(poll)).data();
      requireState(Boolean(box), "Poll not found.");
      requireState(box.status === "published", "Only published polls can be closed.");
      tx.update(poll, { status: "closed", closesAt: FieldValue.serverTimestamp() });
      return { pollId, status: "closed" };
    }

    if (action === "deleteDraft") {
      requireState(current.status === "draft", "Only unconfirmed drafts can be deleted.");
      tx.delete(draft);
      return { pollId, deleted: true };
    }

    requireState(current.status === "draft", "Published candidates and settings are frozen.");
    if (action === "remove") {
      const key = resourceId(data.candidateId);
      tx.update(draft, { candidates: current.candidates.filter((c) => c.id !== key) });
      return { pollId };
    }

    if (action === "add") {
      const scholar = boundedText(data.scholarNo, 64, "scholar number");
      const statement = boundedText(data.statement, 800, "candidate statement");
      const matches = await tx.get(
        db.collection("school_members").where("scholar_no", "==", scholar).limit(2)
      );
      requireState(matches.size === 1, "The roster must contain one matching member.");
      const doc = matches.docs[0];
      const candidate = doc.data();
      requireState(eligible(candidate, current), "Candidate is not eligible for this ballot.");
      const name = boundedText(candidate.display_name, 120, "roster display name");
      const existing = current.candidates.find((c) => c.uid === doc.id);
      const next = { id: existing?.id ?? randomUUID(), uid: doc.id, name, statement, house: candidate.house };
      const list = current.candidates.filter((c) => c.uid !== doc.id);
      requireState(list.length < 20, "This ballot supports up to 20 candidates.");
      tx.update(draft, { candidates: [...list, next] });
      return { pollId, candidateId: next.id };
    }

    if (action === "publish") {
      requireState(current.endMs > Date.now(), "The deadline has passed.");
      requireState(current.candidates.length >= 2, "Add at least two eligible candidates.");
      const people = await tx.getAll(
        ...current.candidates.map((c) => db.collection("school_members").doc(c.uid))
      );
      const candidates = current.candidates.map((c, i) => {
        const registered = people[i].data();
        requireState(eligible(registered, current), "Review a candidate whose membership changed.");
        const name = boundedText(registered.display_name, 120, "roster display name");
        requireState(name === c.name, "A candidate changed name. Refresh their draft entry.");
        return { id: c.id, name, statement: c.statement, house: registered.house };
      });
      tx.create(poll, {
        ...publicHeader(current),
        candidates,
        status: "published",
        publishedAt: FieldValue.serverTimestamp()
      });
      tx.update(draft, { status: "published", publishedBy: uid });
      return { pollId, status: "published" };
    }
    fail("invalid-argument", "Unknown election action.");
  });
});
