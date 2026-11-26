# Activities, houses and merchandise

Read-only review of the current Flutter and Firebase source. Paths below are relative to the project containing this guide. Search for the named method if a line moves. All code in this document is proposed for review in an isolated Firebase emulator project. The backend examples use CommonJS, the installed Firebase Functions v2 API, the existing Admin SDK instance and the proposed server-managed school_members/{uid} directory. A signed-in account needs an active member record. Staff actions additionally require the named capability to be true. A school administrator must provision these records through a trusted administrative process.

## Where the workflows break

| Priority | What happens today | First change |
|---|---|---|
| Critical · checkout and collection | Both checkout paths build a receipt on the phone using a truncated clock and generate a QR with zero points. The pass calls a cash order “PAID (BHD)” whenever its points total is zero. Order creation even permits a student to supply “ready” or “verified”. A student can show a paid-looking pass before the school receives any money. See `lib/screens/merch_store_tab.dart` lines 118, 839–887, 1108–1114, 2190–2229 and `firestore.rules` lines 653–670. | Server prices and reserves available size variants. Display a reservation. Staff records collection of the actual amount. Fulfil against a single authoritative order. |
| Critical · voucher scanning | The wallet's own signed cash QR fails `validateVoucherToken` at zero points. The parser can also accept older unsigned payloads. `claimStoreVoucher` reads first and updates later, so two counters can both receive success. A missing order or failed database request can still generate local success. See `lib/services/voucher_security_service.dart` lines 82–96, 104–200 and 428–550, and `lib/screens/id_scanner_screen.dart` around 250 and 393. | Look up an opaque receipt, verify the holder at the counter, require payment, and transact once. A repeated scan displays “already collected”. |
| High · claims and OCR | Upload happens before the claim document is written. The trigger derives the target from the filename and merges identity, house and status using Admin access. A late delivery can replace an approved decision. The queue reads only pending and the gallery only approved. A successful OCR result moves a claim to verified, where neither screen shows it. A keyword in an image is enough to pass the heuristic. See `functions/index.js` lines 25–67 and 110–174, `storage.rules` lines 22–32 and 51, `lib/services/auth_service.dart` lines 2526–2618. | Allocate a server-bound claim and a single-owner attachment path first. Track scanner observations independently of the staff decision. |
| High · claim awards and discipline | The existing claim transaction guards approved claims but can proceed for a missing or rejected claim. It trusts incoming house and points. The profile and notification are updated after the transaction. Conduct also commits totals before creating the conduct log. Retrying after a partial failure can double-credit or double-deduct. See `lib/services/auth_service.dart` lines 2609–2744 and 3001–3120. | Record the source event, audited award, appropriate projections and inbox entry in one transaction. Use a stable source-specific document ID. |
| High · house arena | Every fifth tap sets all four *spirit* counters from one phone. Concurrent taps can erase another house's progress. Any signed-in user can submit permitted values. These counters differ from championship points. Brain Blitz directly writes championship points and personal totals from the client. Student house-point writes can be denied. See `lib/screens/house_arena_screen.dart` lines 361–374 and 495–534, `firestore.rules` lines 788–795 and 813–822. | Choose whether spirit is cosmetic or schoolwide. If shared, accept one rate-limited increment for the member's house. Route official quiz awards through server-scored sessions. |
| High · mini-game rewards | The signing key and cooldown are on the device. The award method commits the local cooldown and points first, then attempts a Firestore read after a transaction write, catches the failure, and reports points awarded. Its contributor key also differs from the scholar-only key used for conduct and claims. See `lib/services/gamification_security_service.dart` lines 26–62 and `lib/services/auth_service.dart` lines 3123–3228. | Compute rewards from challenge answers on the server and credit once per participant and eligible interval. Show official points only after the server replies. |
| High · fixtures and scoring | Fixture creation writes keys such as tournament_title and scheduled_at which isValidFixture excludes. The write exception is swallowed and the creator sees a cached new fixture. The scoring batch computes both scores from a previously fetched fixture and can lose simultaneous scores. Its catch also reports success. See `lib/models/sports_tournament.dart` lines 149–171, `firestore.rules` lines 379–396 and 678–689, `lib/services/auth_service.dart` lines 3973–4050 and 4509–4537. | Create fixtures through a role-checked endpoint, read back persisted state, and commit score plus commentary against the latest fixture in one transaction. |
| High · certification and trophies | Match certification takes final scores and staff identity from the client. A credential embedded in the app signs the result. Trophy awards generate a fresh record on each request, allowing a repeated championship award and another pair of increments. See `lib/services/sports_security_service.dart` and `lib/services/auth_service.dart` lines 4052–4150 and 4403–4480. | Certify the persisted score once. Publish the winner from the certified tournament outcome. Use a unique trophy ID per season, division, tournament and award rather than a timestamp. |
| High · event wall | The home screen filters what it displays after loading posts. All signed-in users can read the collection, including pending posts. A signed-in user can replace likes and liked_by for other users. See `lib/screens/home_screen.dart` around lines 4177–4208 and 4504, and `firestore.rules` lines 831–850. | Separate published and moderated views. Use one reaction per UID. Limit pending reads to the author and assigned moderators. |

## Copyable backend for reservations, payment at the counter and pickup

The proposed checkout assumes the school accepts payment at pickup. There is no identified payment gateway in these checkout paths. The cash confirmation is a staff attestation. A future payment gateway needs a separate verified webhook. Each variant, including size, gets a distinct ID. Seed `store_catalog_v2/{variantId}` with active (boolean), label (string), unitFils and available (nonnegative integers). For example, 1.250 BHD is 1250 fils. A student may have one open reservation. The cart may contain up to 12 distinct variants and five of each. Review those limits with the school.

Put the next JavaScript block after the existing `db` declaration in the proposed version of `functions/index.js`, or move it to a module that receives the initialized database. Include the two imports once. Other blocks below reuse these helpers. Private documents contain order lines and counter state. They must only be readable through the owner or staff paths described below.

```js
const { onCall: activityCall, HttpsError: ActivityError } = require("firebase-functions/v2/https");
const { createHash: activityHash } = require("node:crypto");
const activityTime = () => admin.firestore.FieldValue.serverTimestamp();

function rejectActivity(code, message) {
  throw new ActivityError(code, message);
}

function memberUid(req) {
  if (!req.auth) rejectActivity("unauthenticated", "Sign in to continue.");
  return req.auth.uid;
}

function safeKey(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,100}$/.test(value)) {
    rejectActivity("invalid-argument", "Invalid identifier.");
  }
  return value;
}

function digestActivity(value) {
  return activityHash("sha256").update(JSON.stringify(value)).digest("hex");
}

async function activityMember(tx, uid, capability) {
  const member = (await tx.get(db.collection("school_members").doc(uid))).data();
  if (member?.active !== true || (capability && member.capabilities?.[capability] !== true)) {
    rejectActivity("permission-denied", "This account cannot perform this action.");
  }
  return member;
}

function cartLines(raw) {
  if (!Array.isArray(raw) || raw.length < 1 || raw.length > 12) {
    rejectActivity("invalid-argument", "Select one to twelve variants.");
  }
  const seen = new Set();
  return raw.map((line) => {
    const variantId = safeKey(line?.variantId);
    const qty = line?.qty;
    const quotedFils = line?.quotedFils;
    if (seen.has(variantId) || !Number.isInteger(qty) || qty < 1 || qty > 5 ||
        !Number.isSafeInteger(quotedFils) || quotedFils < 0 || quotedFils > 1000000) {
      rejectActivity("invalid-argument", "Invalid quantity, quoted price or duplicate variant.");
    }
    seen.add(variantId);
    return { variantId, qty, quotedFils };
  }).sort((a, b) => a.variantId.localeCompare(b.variantId, "en"));
}

exports.reserveStoreOrderV2 = activityCall(async (req) => {
  const uid = memberUid(req);
  const key = safeKey(req.data?.requestId);
  if (key.length < 20) rejectActivity("invalid-argument", "Use a new random request ID.");
  const lines = cartLines(req.data?.lines);
  const orderId = digestActivity([uid, key]);
  const signature = digestActivity(lines);
  const order = db.collection("store_orders_v2").doc(orderId);
  const slot = db.collection("store_open_orders_v2").doc(uid);

  return db.runTransaction(async (tx) => {
    await activityMember(tx, uid);
    const prior = (await tx.get(order)).data();
    if (prior) {
      if (prior.signature !== signature) rejectActivity("already-exists", "This request ID belongs to a different cart.");
      return { orderId, state: prior.state, totalFils: prior.totalFils };
    }
    if ((await tx.get(slot)).exists) rejectActivity("failed-precondition", "Finish or cancel your existing reservation.");
    const refs = lines.map((line) => db.collection("store_catalog_v2").doc(line.variantId));
    const products = await tx.getAll(...refs);
    const details = lines.map((line, i) => {
      const product = products[i].data();
      if (product?.active !== true || !Number.isSafeInteger(product.available) ||
          product.available < line.qty || typeof product.label !== "string" || !product.label.trim()) {
        rejectActivity("failed-precondition", "A selected variant is unavailable. Refresh the cart.");
      }
      if (product.unitFils !== line.quotedFils) {
        rejectActivity("failed-precondition", "The price changed. Review the new total.");
      }
      return { variantId: line.variantId, label: product.label, qty: line.qty, unitFils: product.unitFils };
    });
    const totalFils = details.reduce((sum, item) => sum + item.qty * item.unitFils, 0);
    for (const [i, item] of details.entries()) {
      tx.update(refs[i], { available: products[i].get("available") - item.qty });
    }
    tx.create(order, { uid, signature, lines: details, totalFils, currency: "BHD", state: "reserved", createdAt: activityTime() });
    tx.create(slot, { orderId });
    return { orderId, state: "reserved", totalFils };
  });
});

exports.changeStoreOrderV2 = activityCall(async (req) => {
  const actor = memberUid(req);
  const orderId = safeKey(req.data?.orderId);
  const op = req.data?.operation;
  if (!["cancel", "confirmPayment", "collect"].includes(op)) rejectActivity("invalid-argument", "Unknown operation.");
  const ref = db.collection("store_orders_v2").doc(orderId);

  return db.runTransaction(async (tx) => {
    const member = await activityMember(tx, actor, op === "cancel" ? null : "manageStore");
    const order = (await tx.get(ref)).data();
    if (!order) rejectActivity("not-found", "No matching reservation.");
    if (op === "cancel" && order.uid !== actor && member.capabilities?.manageStore !== true) {
      rejectActivity("permission-denied", "Only the owner or store staff may cancel.");
    }

    if (op === "confirmPayment") {
      if (req.data?.receivedFils !== order.totalFils) rejectActivity("failed-precondition", "Check the amount received.");
      if (["ready", "collected"].includes(order.state)) return { state: order.state, changed: false };
      if (order.state !== "reserved") rejectActivity("failed-precondition", "The order is closed.");
      tx.update(ref, { state: "ready", cashierUid: actor, paidAt: activityTime() });
      return { state: "ready", changed: true };
    }

    const next = op === "cancel" ? "cancelled" : "collected";
    if (order.state === next) return { state: next, changed: false };
    const expected = op === "cancel" ? "reserved" : "ready";
    if (order.state !== expected) rejectActivity("failed-precondition", "This action is unavailable for the current state.");
    const slot = db.collection("store_open_orders_v2").doc(order.uid);
    if ((await tx.get(slot)).get("orderId") !== orderId) rejectActivity("data-loss", "Reservation requires staff reconciliation.");

    if (op === "cancel") {
      const refs = order.lines.map((line) => db.collection("store_catalog_v2").doc(line.variantId));
      const stock = await tx.getAll(...refs);
      for (const [i, snap] of stock.entries()) {
        const current = snap.data()?.available;
        const restored = current + order.lines[i].qty;
        if (!Number.isSafeInteger(current) || current < 0 || !Number.isSafeInteger(restored)) {
          rejectActivity("data-loss", "Stock requires staff reconciliation.");
        }
        tx.update(refs[i], { available: restored });
      }
    }
    tx.delete(slot);
    tx.update(ref, { state: next, closedByUid: actor, closedAt: activityTime() });
    return { state: next, changed: true };
  });
});
```

### Connect both checkout buttons and the scanner

1. Add the FlutterFire `cloud_functions` package using a version compatible with this app's locked FlutterFire packages. Replace the local order creation at both checkout sites. Generate a Firestore auto-ID without writing a document and store it with the pending cart attempt, namespaced by Firebase Auth UID. Keep it across timeouts, restarts and retries. A materially changed cart starts a new reviewed attempt. Supply catalogue variant IDs and integer quoted prices. Clear the cart only after reserveStoreOrderV2 acknowledges the order.
2. Query store_orders_v2 with `where('uid', isEqualTo: signedInUid)` for a student's locker. Show total due and “Reserved · Pay at pickup” while reserved. Show “Payment received · Ready for pickup”, “Collected” or “Cancelled” according to the returned state. Staff must check the physical student ID against the owner before handing anything over. A QR is a lookup receipt and can be photographed.
3. Show a staff-only payment confirmation with the actual amount collected. Staff can cancel abandoned unpaid reservations and return stock. Keep inactive catalogue variants until all reservations are closed. Add a refund procedure before accepting refunds of paid orders. Changing a paid order into “cancelled” would require a separate financial record and policy. For a future timed release, have a scheduled worker recheck the order deadline and state in the same transaction as stock restoration.
4. For a first scanner request, only a successful `collect` response with `changed == true` authorizes a physical handover. A lost response must display “Check collection history” and fetch the authoritative record for counter reconciliation. Disable repeat taps while waiting. Route the old QR format to an explicit legacy lookup screen with no automatic fulfilment. Remove fallback orders and the hard-coded scholar identity from both checkout paths.

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

String newCartAttemptId() =>
    FirebaseFirestore.instance.collection('store_orders_v2').doc().id;

Future<Map<String, dynamic>> reserveCart({
  required String savedAttemptId,
  required List<Map<String, dynamic>> variants,
}) async {
  final reply = await FirebaseFunctions.instance
      .httpsCallable('reserveStoreOrderV2')
      .call({'requestId': savedAttemptId, 'lines': variants});
  return Map<String, dynamic>.from(reply.data as Map);
}

String storeReceiptQr(String orderId) => 'ASB2-STORE:$orderId';

Future<bool> collectFromQr(String raw) async {
  final match = RegExp(r'^ASB2-STORE:([a-f0-9]{64})$').firstMatch(raw.trim());
  if (match == null) throw const FormatException('Unrecognized store receipt.');
  final reply = await FirebaseFunctions.instance.httpsCallable('changeStoreOrderV2')
      .call({'operation': 'collect', 'orderId': match.group(1)!});
  return (reply.data as Map)['changed'] == true;
}
```

## Copyable claim submission and award

Use one workflow for students, reviewers and the leaderboard. The example accepts a JPEG certificate. Convert a supported photo to JPEG before upload, or extend both the backend and Storage rules together for another supported type. Render untrusted uploads with an image decoder in a controlled reviewer view. A MIME label alone cannot attest to the content or authenticity. The school decides whether OCR is worth running. Manual review below works independently of Vision.

```js
const activityHouses = new Set(["ruby", "sapphire", "emerald", "topaz"]);

function activityText(value, max, label) {
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) {
    rejectActivity("invalid-argument", "Invalid " + label + ".");
  }
  return value.trim();
}

exports.beginHouseClaimV2 = activityCall(async (req) => {
  const uid = memberUid(req);
  const requestId = safeKey(req.data?.requestId);
  const title = activityText(req.data?.title, 150, "activity title");
  const claimId = digestActivity([uid, requestId]);
  const path = ["claims_v2", uid, claimId, "certificate.jpg"].join("/");
  const ref = db.collection("activity_claims_v2").doc(claimId);
  return db.runTransaction(async (tx) => {
    const member = await activityMember(tx, uid);
    const old = (await tx.get(ref)).data();
    if (old) {
      if (old.title !== title) rejectActivity("already-exists", "Request ID belongs to another claim.");
      return { claimId, path, state: old.state };
    }
    if (!activityHouses.has(member.house)) rejectActivity("failed-precondition", "Assign a house on the school roster.");
    tx.create(ref, { uid, house: member.house, title, path, state: "awaiting_file", createdAt: activityTime() });
    return { claimId, path, state: "awaiting_file" };
  });
});

// Uses onObjectFinalized imported by the existing functions/index.js.
exports.queueHouseClaimV2 = onObjectFinalized({ retry: true }, async (event) => {
  const object = event.data;
  const parts = (object.name || "").split("/");
  if (parts.length !== 4 || parts[0] !== "claims_v2" || parts[3] !== "certificate.jpg") return;
  const [, uid, id] = parts;
  if (!uid || !/^[a-f0-9]{64}$/.test(id)) return;
  const ref = db.collection("activity_claims_v2").doc(id);
  await db.runTransaction(async (tx) => {
    const claim = (await tx.get(ref)).data();
    if (!claim || claim.uid !== uid || claim.path !== object.name || claim.state !== "awaiting_file") return;
    const size = Number(object.size);
    const allowed = object.contentType === "image/jpeg" && Number.isSafeInteger(size) && size > 0 && size <= 5 * 1024 * 1024;
    tx.update(ref, { state: allowed ? "pending" : "invalid_file",
      objectGeneration: String(object.generation), receivedAt: activityTime() });
  });
});

exports.reviewHouseClaimV2 = activityCall(async (req) => {
  const reviewerUid = memberUid(req);
  const claimId = safeKey(req.data?.claimId);
  const decision = req.data?.decision;
  if (!["approved", "rejected"].includes(decision)) rejectActivity("invalid-argument", "Choose a decision.");
  const points = decision === "approved" ? req.data?.points : 0;
  if (decision === "approved" && (!Number.isInteger(points) || points < 1 || points > 500)) {
    rejectActivity("invalid-argument", "Choose 1 to 500 points.");
  }
  const reason = activityText(req.data?.reason, 250, "review reason");
  const ref = db.collection("activity_claims_v2").doc(claimId);
  return db.runTransaction(async (tx) => {
    await activityMember(tx, reviewerUid, "reviewHouseClaims");
    const claim = (await tx.get(ref)).data();
    if (!claim) rejectActivity("not-found", "Claim not found.");
    if (claim.uid === reviewerUid) rejectActivity("permission-denied", "A different reviewer must decide this claim.");
    if (claim.state === decision && claim.points === points && claim.reason === reason) {
      return { state: decision, changed: false };
    }
    if (claim.state !== "pending") rejectActivity("failed-precondition", "Refresh the claim to see its current decision.");
    if (!activityHouses.has(claim.house)) rejectActivity("data-loss", "Claim requires reconciliation.");
    const eventId = "claim_" + claimId;
    if (decision === "approved") {
      const inc = admin.firestore.FieldValue.increment;
      tx.create(db.collection("activity_point_events_v2").doc(eventId), {
        source: "claim", sourceId: claimId, uid: claim.uid, house: claim.house, points,
        reviewerUid, createdAt: activityTime(),
      });
      tx.set(db.collection("activity_house_totals_v2").doc(claim.house), {
        house_name: claim.house, total_points: inc(points),
      }, { merge: true });
      tx.set(db.collection("activity_contributors_v2").doc(claim.uid), {
        total_contributed: inc(points), merits_count: inc(1),
      }, { merge: true });
    }
    tx.update(ref, { state: decision, reason, points, reviewerUid, reviewedAt: activityTime() });
    tx.set(db.collection("users").doc(claim.uid).collection("notifications").doc(eventId), {
      title: decision === "approved" ? "House claim approved" : "House claim reviewed",
      body: decision === "approved" ? ("Your house received " + points + " points.") : reason,
      type: "claim_reviewed", is_read: false, timestamp: activityTime(),
    });
    return { state: decision, changed: true };
  });
});
```

**Storage rules fragment**. Merge into the existing bucket match and remove overlapping broad read permissions, including the authenticated catch-all in storage.rules. A second matching allow grants access even if the following match denies it. The Firestore rule-call references the default database, as used by this app. Configure the cross-service permission when prompted in the staging project. The rule fixes the path, MIME, maximum size, owner, state and create-only policy.

```text
match /claims_v2/{uid}/{claimId}/{fileName} {
  function member() {
    return firestore.get(/databases/(default)/documents/school_members/$(request.auth.uid)).data;
  }
  function claim() {
    return firestore.get(/databases/(default)/documents/activity_claims_v2/$(claimId)).data;
  }
  allow create: if fileName == 'certificate.jpg' && request.auth != null && request.auth.uid == uid &&
    member().active == true && claim().uid == uid && claim().state == 'awaiting_file' &&
    request.resource.size > 0 && request.resource.size <= 5 * 1024 * 1024 &&
    request.resource.contentType == 'image/jpeg';
  allow get: if fileName == 'certificate.jpg' && request.auth != null && member().active == true && claim().uid == uid &&
    (request.auth.uid == uid || member().capabilities.reviewHouseClaims == true);
}
```

Wire the student form to beginHouseClaimV2, then upload to the returned path using Firebase Storage putData with image/jpeg. The submission ID is the same across retries. Show “Awaiting attachment” until the queue function sets pending. After a timeout or “already exists”, refresh the claim and check the existing attachment before retrying. Poll or subscribe for the resulting state. List the student's decisions with a uid equality filter. Reviewers query state == pending, fetch the exact certificate with authenticated SDK reads, confirm evidence and supply the adjudicated points and reason to reviewHouseClaimV2. Use a private reviewer gallery. If the school wants public recognition, publish consented names and achievements to a separate projection, omitting evidence, contact details and scholar numbers. Snapshot the house at submission as a stated school policy.

For optional OCR, store the result in a staff-only subcollection keyed by upload generation. Verify that the reviewed path and generation match the recorded object. OCR can tag “text found”, “no match” or “service error”. Only the review callable decides the award. During migration quarantine incomplete claims generated solely by the old trigger, retain immutable audit copies, and resolve ambiguous legacy states with a reviewer. Lock old upload paths and stop the old trigger before releasing migrated claims to avoid late status overwrites.

## Copyable fixture, scoring and certification workflow

These handlers preserve the tournament model's existing field names and its four sport IDs. They support scoring, starting, postponing and certifying a fixture. The sample uses a schoolwide manageSports capability. If the school designates a referee for each specific match, add an assigned referee UID check to every match action. The sample records team points in head-to-head track fixtures. Timed heats, individual results and multi-house meets need a dedicated event and ranking model before showing an official track awards table.

```js
const sportPoints = {
  football: { goal: 1 },
  basketball: { point: 1, basket: 2, threePointer: 3 },
  volleyball: { point: 1, ace: 1 },
  trackAndField: { point: 1 },
};

exports.createFixtureV2 = activityCall(async (req) => {
  const uid = memberUid(req);
  const d = req.data || {};
  const title = activityText(d.title, 120, "tournament title");
  const venue = activityText(d.venue, 100, "venue");
  if (!Object.hasOwn(sportPoints, d.sport) || !activityHouses.has(d.houseA) ||
      !activityHouses.has(d.houseB) || d.houseA === d.houseB ||
      !Number.isSafeInteger(d.startMs) || d.startMs < Date.UTC(2000, 0, 1) ||
      d.startMs >= Date.UTC(2100, 0, 1)) rejectActivity("invalid-argument", "Check the fixture details.");
  const ref = db.collection("sport_fixtures_v2").doc(digestActivity([uid, safeKey(d.requestId)]));
  const signature = digestActivity([title, venue, d.sport, d.houseA, d.houseB, d.startMs]);
  return db.runTransaction(async (tx) => {
    await activityMember(tx, uid, "manageSports");
    const old = (await tx.get(ref)).data();
    if (old && old.createSignature !== signature) rejectActivity("already-exists", "Request ID belongs to a different fixture.");
    if (!old) tx.create(ref, { fixture_id: ref.id, tournament_title: title, venue, sport_type: d.sport,
      house_a: d.houseA, house_b: d.houseB, scheduled_at: admin.firestore.Timestamp.fromMillis(d.startMs),
      score_a: 0, score_b: 0, status: "upcoming", is_certified: false, revision: 0, createSignature: signature });
    return { fixtureId: ref.id };
  });
});

exports.applyMatchActionV2 = activityCall(async (req) => {
  const uid = memberUid(req);
  const d = req.data || {};
  const ref = db.collection("sport_fixtures_v2").doc(safeKey(d.fixtureId));
  const eventId = digestActivity([uid, safeKey(d.requestId)]);
  const audit = ref.collection("actions").doc(eventId);
  if (!["start", "score", "postpone", "certify"].includes(d.op)) rejectActivity("invalid-argument", "Unknown match action.");
  const signature = digestActivity([d.op, d.house ?? null, d.eventType ?? null, d.expectRevision ?? null]);
  return db.runTransaction(async (tx) => {
    const member = await activityMember(tx, uid, "manageSports");
    const fixture = (await tx.get(ref)).data();
    const prior = (await tx.get(audit)).data();
    if (!fixture) rejectActivity("not-found", "Fixture not found.");
    if (prior) {
      if (prior.signature !== signature) rejectActivity("already-exists", "Request ID belongs to a different action.");
      return { changed: false, revision: prior.revision };
    }
    if (fixture.is_certified || fixture.status === "completed") rejectActivity("failed-precondition", "Fixture is final.");
    const revision = fixture.revision + 1;
    let a = fixture.score_a, b = fixture.score_b;
    let status = fixture.status, type = "periodChange", house = fixture.house_a;
    let period = "";
    const extra = {};
    if (d.op === "score") {
      const table = sportPoints[fixture.sport_type];
      if (status !== "live" || ![fixture.house_a, fixture.house_b].includes(d.house) ||
          !table || !Object.hasOwn(table, d.eventType)) rejectActivity("failed-precondition", "Check the match, house and event.");
      if (d.house === fixture.house_a) a += table[d.eventType];
      else b += table[d.eventType];
      if (!Number.isSafeInteger(a) || !Number.isSafeInteger(b) || a > 999 || b > 999) {
        rejectActivity("failed-precondition", "Review the score before adding another event.");
      }
      type = d.eventType;
      house = d.house;
      period = "Live play";
    } else {
      if (d.expectRevision !== fixture.revision) rejectActivity("failed-precondition", "Match updated. Review the latest score.");
      if (d.op === "start" && ["upcoming", "postponed"].includes(status)) {
        status = "live"; period = "Match started";
      } else if (d.op === "postpone" && ["upcoming", "live"].includes(status)) {
        status = "postponed"; period = "Match postponed";
      } else if (d.op === "certify" && status === "live") {
        status = "completed"; period = "Final score certified";
        extra.is_certified = true;
        extra.certified_at = activityTime();
        extra.certified_by = member.display_name || "Sports staff";
      } else rejectActivity("failed-precondition", "This transition is unavailable.");
    }
    tx.update(ref, { score_a: a, score_b: b, status, revision, ...extra });
    tx.create(audit, { uid, signature, revision, operation: d.op, at: activityTime() });
    tx.create(ref.collection("events").doc(eventId), { event_id: eventId, fixture_id: ref.id,
      event_type: type, house_name: house, period_description: period,
      score_a_after: a, score_b_after: b, timestamp: activityTime(), revision });
    return { changed: true, revision };
  });
});
```

Switch getSportsFixturesStream and getLiveMatchEventsStream to sport_fixtures_v2 and its events children. Store the revision alongside the fixture model, subscribe to the fixture document while the HUD is open, and render its authoritative score and status. In Upcoming show **Start match** to staff. In Live show eligible scoring options based on the sport and **Certify these scores**. In Postponed show **Resume**. For a tied final, show a draw or the school's tie-break procedure. Submit the displayed revision with start, postpone and certify. On a conflict, refresh and ask the referee to review the changed score. Keep a request ID per tap and retain it across timeouts. Remove local certification tokens from the official verification display. For inaccurate events, add staff-only correction events referencing the original event and a reason. Preserve the original score trail and require a controlled new certification for any amendment of a final result.

Persist the timer if it is an official clock. The timer currently runs on the HUD device in `lib/screens/live_match_hud_screen.dart` around lines 71–105. The server should store period, remaining duration at pause and the last start timestamp. On reconnect, derive remaining time from those values. If the timer is only a personal stopwatch, label it accordingly.

### Other coupled records

- **Trophies and individual awards.** Give each tournament a stable season, division and tournament ID. Bind eligibility to registered fixtures or entrant lists. Generate a trophy key from season, division, tournament and award category. In one staff-only transaction read the certified outcome and existing trophy, then create the trophy, both house-point events, totals, and a notice with a deterministic ID. Reject the same winning and runner-up house. For MVP, require the student UID to be a participant in the selected match. Store one award per fixture and category. Corrections post reversing events. The roster and a certified outcome must exist before issuing these awards.
- **Conduct.** Use a staff capability and classroom assignment when relevant. Resolve student UID, current house and name from trusted membership. The client should supply only the student lookup, reason, positive magnitude, merit/demerit type, and a durable request ID. Validate limits server-side. In a single transaction create the conduct record and ledger event, update house and contributor projections, and create the student's notification. Read all inputs before writes. A new attempt must return the original result if its inputs match, or report a conflicting reuse. Decide explicitly whether demerits can take a house below zero. If balances have a floor, record the effective signed delta beside the requested magnitude to make reconciliation possible.
- **Brain Blitz.** Start one server session for (school UID, activity, allowed interval), timestamp it on the server and return questions without answer keys. Keep the answer key and scoring policy in a server-private collection. Receive answer choices and session ID. Verify actor, eligibility, deadline, choice count, and cooldown, then calculate the score on the server. In the same transaction mark the session complete and post one ledger event and its projections. A second device retries the same submission or receives the existing receipt. Persist cooldown on accepted completion and optionally prevent repeated starts using the open session. If the school cannot verify a competitive game outcome, keep those results in a personal practice scoreboard. The current Blitz end screen uses a denominator of 100 despite combo multipliers. Derive the maximum from the actual questions and multipliers or show plain points.
- **Spirit.** If house spirit is global, replace all-house snapshot writes with a callable using a stable action ID, server-derived house, a per-UID time window and a capped increment. Record the request and increment only that house in one transaction. Display cosmetic tapping feedback immediately, then reconcile the shared counter. A request ID on its own cannot enforce a rate limit because a user can create new IDs. Keep the Cup Oracle clearly labeled as a simulation and give it read-only access to real standings.
- **Wall.** Use “My submissions”, a public approved query and a staff moderation queue. Moderation writes the decision and reviewer once. Store likes as `event_wall_v2/{post}/reactions/{uid}` with an explicit requested state such as liked=true so retries are safe. Check published state on the server and update the aggregate iff this changes the reaction. A viewer only needs their own reaction and the published count. The current 20-document limit runs before client-side filtering, which can fill an entire page with pending posts and hide older approved posts. Query published first, then paginate.
- **Wallet and recognition.** “Buy & Save to Wallet” opens a Flutter pass sheet. Label this “View school pickup pass”. A native-wallet button should correspond to a signed, installed pass that can be updated or revoked. Recognition boards should publish a small student-facing projection according to school visibility settings. Keep the underlying conduct records, certificates, cash and private member identities scoped to the people who process them.

## Copyable daily Brain Blitz scoring

This school policy gives one scored attempt per member per published challenge. Seed a single immutable challenge key per school date (for example `blitz_20261105`). Staff place the private document at `activity_quizzes_v2/{challengeId}` with `opensAt` and `closesAt` timestamps, an integer `durationSec` from 30 to 900, and 1–10 questions. Each question has prompt, options (2–5 non-empty strings), and correct (zero-based option index). Award ten points per correct answer in this version. Once opened, publish a new revision as a different challenge only under an explicit retake policy. The scoring code snapshots questions into the student's private attempt, so a later edit cannot change their marks. Students discover the challenge ID from a published school calendar entry. A teacher creating that entry must publish the corresponding challenge first. The two callables expose only the public question fields and the student's own receipt.

```js
function usableQuiz(quiz) {
  return quiz && typeof quiz.opensAt?.toMillis === "function" &&
    typeof quiz.closesAt?.toMillis === "function" && Number.isInteger(quiz.durationSec) &&
    quiz.durationSec >= 30 && quiz.durationSec <= 900 && Array.isArray(quiz.questions) &&
    quiz.questions.length >= 1 && quiz.questions.length <= 10 &&
    quiz.questions.every((q) => q && typeof q.prompt === "string" && q.prompt.trim() &&
      Array.isArray(q.options) && q.options.length >= 2 && q.options.length <= 5 &&
      q.options.every((s) => typeof s === "string" && s.trim()) &&
      Number.isInteger(q.correct) && q.correct >= 0 && q.correct < q.options.length);
}

function quizAttempt(uid, id) {
  return db.collection("activity_quiz_attempts_v2").doc(digestActivity([uid, id]));
}

function visibleAttempt(a) {
  if (a.state === "scored") return { state: "scored", points: a.points, maximum: a.questions.length * 10 };
  return { state: a.deadlineMs > Date.now() ? "open" : "expired", deadlineMs: a.deadlineMs,
    questions: a.questions.map(({ prompt, options }) => ({ prompt, options })) };
}

exports.startBlitzV2 = activityCall(async (req) => {
  const uid = memberUid(req);
  const id = safeKey(req.data?.challengeId);
  const ref = quizAttempt(uid, id);
  return db.runTransaction(async (tx) => {
    const member = await activityMember(tx, uid);
    const existing = (await tx.get(ref)).data();
    if (existing) return visibleAttempt(existing);
    const q = (await tx.get(db.collection("activity_quizzes_v2").doc(id))).data();
    const now = Date.now();
    if (!usableQuiz(q) || now < q.opensAt.toMillis() || now >= q.closesAt.toMillis()) {
      rejectActivity("failed-precondition", "This challenge is unavailable.");
    }
    if (!activityHouses.has(member.house)) rejectActivity("failed-precondition", "A roster house is required.");
    const attempt = { uid, house: member.house, challengeId: id, state: "open", questions: q.questions,
      deadlineMs: Math.min(q.closesAt.toMillis(), now + 1000 * q.durationSec) };
    tx.create(ref, attempt);
    return visibleAttempt(attempt);
  });
});

exports.finishBlitzV2 = activityCall(async (req) => {
  const uid = memberUid(req);
  const id = safeKey(req.data?.challengeId);
  const ref = quizAttempt(uid, id);
  return db.runTransaction(async (tx) => {
    await activityMember(tx, uid);
    const a = (await tx.get(ref)).data();
    if (!a) rejectActivity("not-found", "Start the challenge first.");
    if (a.state === "scored") return visibleAttempt(a);
    if (Date.now() >= a.deadlineMs) rejectActivity("deadline-exceeded", "The challenge has ended.");
    const choices = req.data?.choices;
    if (!Array.isArray(choices) || choices.length !== a.questions.length ||
        choices.some((choice, i) => !Number.isInteger(choice) || choice < -1 || choice >= a.questions[i].options.length)) {
      rejectActivity("invalid-argument", "Invalid answer choices.");
    }
    // The client may send -1 for an unanswered question.
    const points = 10 * a.questions.filter((q, i) => q.correct === choices[i]).length;
    tx.update(ref, { state: "scored", points, scoredAt: activityTime() });
    if (points > 0) {
      const inc = admin.firestore.FieldValue.increment;
      tx.create(db.collection("activity_point_events_v2").doc("blitz_" + ref.id), {
        source: "blitz", sourceId: ref.id, uid, house: a.house, points, createdAt: activityTime(),
      });
      tx.set(db.collection("activity_house_totals_v2").doc(a.house), {
        house_name: a.house, total_points: inc(points),
      }, { merge: true });
      tx.set(db.collection("activity_contributors_v2").doc(uid), {
        total_contributed: inc(points), merits_count: inc(1),
      }, { merge: true });
    }
    return { state: "scored", points, maximum: a.questions.length * 10 };
  });
});
```

Replace the hard-coded answer bank and instance-local score writes for the official mode in house_arena_screen.dart. Use startBlitzV2 for both “Play” and “Resume”. Pass full answer choices to finishBlitzV2 once and display the returned points and maximum. Allow users to skip questions. Buffer choices per UID and challenge for a reconnect before the original deadline. Clearing cache cannot reset the server's timer. A free-practice mode can still run offline if it is explicitly labeled. Multiple-question quizzes do not prove who physically used a device. For a higher-stakes competition, the school needs its normal supervision process.

## Firestore access for these samples

Inside the existing Firestore database match, use the following fragments for the new collection names. The capability map and school membership are server-managed. The matching rules for school_members must deny writes from client SDKs, including from the user themselves. Guard any bootstrap or roster-management endpoint independently. Students only need single-record access to their own membership to render their UI. The Admin SDK in the callables validates every operation separately.

```text
function hasActivityMember() {
  return request.auth != null &&
    exists(/databases/$(database)/documents/school_members/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.active == true;
}
function hasActivityCapability(name) {
  return hasActivityMember() &&
    get(/databases/$(database)/documents/school_members/$(request.auth.uid)).data.capabilities.get(name, false) == true;
}
match /store_catalog_v2/{id} {
  allow read: if hasActivityMember();
}
match /store_orders_v2/{id} {
  allow read: if hasActivityMember() && (resource.data.uid == request.auth.uid || hasActivityCapability('manageStore'));
}
match /activity_claims_v2/{id} {
  allow read: if hasActivityMember() && (resource.data.uid == request.auth.uid || hasActivityCapability('reviewHouseClaims'));
  match /staff_scan/{scanId} {
    allow get: if hasActivityCapability('reviewHouseClaims');
  }
}
match /sport_fixtures_v2/{id} {
  allow read: if hasActivityMember();
  match /events/{eventId} { allow read: if hasActivityMember(); }
  match /actions/{id2} { allow read: if hasActivityCapability('manageSports'); }
}
match /activity_house_totals_v2/{id} {
  allow read: if hasActivityMember();
}
match /activity_contributors_v2/{uid} {
  allow get: if hasActivityMember() && (uid == request.auth.uid || hasActivityCapability('reviewHouseClaims'));
}
```

All other access to these new collections should default to deny. The private quiz, quiz attempts (including the answer keys), open orders, and point event ledger need no client reads or writes. Expose a minimal staff-only reconciler if required. Secure the existing users/{uid}/notifications wildcard against forged messages before displaying these receipts as official. Owner read/mark-read privileges should apply only to the user's own inbox with a narrow update key list. Review overlapping wildcard grants across the whole ruleset. New matches alone cannot close a broader grant.

## Migration and checks before adoption

1. Export a staging snapshot. Inventory existing orders, school houses, fixture and event schemas, scholarship IDs, contributor aliases and OCR statuses. Determine ownership from the verified school roster. Route collisions, unresolvable receipts, ambiguous cash records, and already-awarded claims to staff. Reject automatic conversion of a local pass or legacy ready state into a paid order. Start with actual inventory counts per size.
2. Reconcile a one-time opening points balance for each house and contributor. Keep supporting evidence and the season/date of cutover. Map existing awards to “already counted” records where identity is known. Write deterministic import IDs, then replay the import in staging and compare the balances. Separate legacy house totals from spendable credit, league-table points, spirit and practices. Point totals in the code examples apply to a single season. If the school wants historical seasons, include a server-resolved season ID in the ledger, projection keys, standings queries and cutover before opening another season.
3. Update the HUD, referee entry, claim form, reviewer queue, approved gallery, activity panel, wallet, scanner, ID lookup and every standings reader including both direct reads in lib/screens/house_leaderboard_screen.dart (around 220 and 327). Use the public house aggregate and the authenticated user's private contributor aggregate. Implement a consented public leaderboard projection before publishing student rankings. Update category breakdowns from the same ledger. A missing or stale snapshot should show “Standings unavailable” or its last successful refresh time. The current leaderboard labels even cached fallback points “verified”.
4. Roll backend and migrated data into a staging Firebase project. Use dual **reads** if needed. At a planned cutover, stop old writers across supported clients and restrict direct writes to the legacy and v2 collections. This includes house_points, house_contributors, sports_fixtures/events, users.points_contributed, orders, claim status, spirit and reaction aggregates. Preserve demo-only local actions behind an explicit demo repository. Prevent old binaries from continuing to write after migration.
5. Run two-device tests and emulator tests with actual security rules before any rollout. No production orders, claims, certificates or points were exercised for this report.

| Scenario to run | Expected result |
|---|---|
| Two students reserve the last shirt at once | One reservation, one stock decrement, and an actionable unavailable message for the other. |
| Reserve a cart, lose network response and relaunch | Same request ID returns the same order. Changed cart or stale quoted price requires explicit review. |
| Cancel versus collect/confirm payment at two counters | Exactly one valid state sequence. Cancellation restores stock once. Pickup requires settled payment. Two physical scans produce one first-time success. |
| Hand a QR from one student to another | Staff can see the actual owner before collection, verify the physical holder and decline handover. Private order reads by unrelated students fail. |
| Upload another student's claim, overwrite a certificate or retry an old finalize event | Unrelated upload and overwrite fail. The repeated event leaves the current human decision intact. |
| Approve a pending claim simultaneously on two devices | One decision, one notification, one ledger entry and one set of projection increments. Rejected and missing claims receive zero points. |
| Two refs add a goal from the same old screen | Two events and two awarded goals once accepted. A retried request ID returns its earlier receipt. Certifying a stale revision fails. |
| Submit the same quiz from two devices, then clear app storage | Exactly one score and award, and the new session shows the existing result. Timeouts do not generate local points. Direct client reads of answer keys fail. |
| Cross-role and disabled-account attempts | Students cannot confirm cash, score fixtures, view another student's private evidence, update other houses, or modify a review. A disabled membership loses access. |
| New posts fill the moderation queue | Existing approved posts still display. Author can see their pending post. Another student cannot retrieve it or replace another user's likes. |

The callable modules and rules are review copies. They still need the listed UI wiring, roster capability provisioning, dataset reconciliation, emulator execution and a school decision on cash collection, award policies, consent and season boundaries.
