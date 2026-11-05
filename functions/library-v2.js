/**
 * ASB House Hub - Zero-Trust Library Module v2
 * Server-authoritative book checkouts, renewals, and returns.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

const store = getFirestore();
const loanPeriodMs = 14 * 86400000;

function loanCheck(ok, code, message) {
  if (!ok) throw new HttpsError(code, message);
}

function loanId(value) {
  loanCheck(
    typeof value === "string" && /^[a-zA-Z0-9_-]{1,128}$/.test(value),
    "invalid-argument",
    "Invalid ID."
  );
  return value;
}

exports.schoolLibrary = onCall(async ({ auth, data }) => {
  loanCheck(auth?.uid, "unauthenticated", "Sign in to continue.");
  const uid = auth.uid;
  const id = loanId(data?.loanId);
  const loanRef = store.collection("library_loans_v2").doc(id);

  return store.runTransaction(async (tx) => {
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
        loanCheck(
          loan.copyId === copyId &&
            loan.borrower === borrower &&
            loan.issuedBy === uid,
          "already-exists",
          "Loan ID already used."
        );
        return { loanId: id, state: loan.state, dueMs: loan.dueAt.toMillis() };
      }
      const copyRef = store.collection("library_copies_v2").doc(copyId);
      const copy = (await tx.get(copyRef)).data();
      const member = (await tx.get(store.collection("school_members").doc(borrower))).data();
      loanCheck(member?.active === true, "failed-precondition", "Borrower is inactive or missing.");
      loanCheck(
        copy &&
          typeof copy.title === "string" &&
          copy.title.length > 0 &&
          copy.hold === false &&
          !copy.currentLoanId,
        "failed-precondition",
        "Copy unavailable."
      );
      const dueMs = now + loanPeriodMs;
      tx.update(copyRef, { currentLoanId: id });
      tx.create(loanRef, {
        copyId,
        title: copy.title,
        borrower,
        issuedBy: uid,
        state: "open",
        version: 0,
        dueAt: Timestamp.fromMillis(dueMs)
      });
      return { loanId: id, state: "open", dueMs };
    }

    if (data.action === "return") {
      loanCheck(staff, "permission-denied", "Librarian required.");
    } else {
      loanCheck(
        data.action === "renew" && loan?.borrower === uid,
        "permission-denied",
        "Borrower account required."
      );
    }

    loanCheck(loan, "not-found", "Loan missing.");
    if (data.action === "return" && loan.state === "returned") {
      return { state: "returned" };
    }
    loanCheck(loan.state === "open", "failed-precondition", "This loan is closed.");
    const copyRef = store.collection("library_copies_v2").doc(loan.copyId);
    const copy = (await tx.get(copyRef)).data();
    loanCheck(copy?.currentLoanId === id, "failed-precondition", "Librarian must reconcile this copy.");

    if (data.action === "return") {
      tx.update(copyRef, { currentLoanId: null });
      tx.update(loanRef, {
        state: "returned",
        returnedBy: uid,
        returnedAt: Timestamp.fromMillis(now)
      });
      return { state: "returned" };
    }

    if (data.version === 0 && loan.version === 1) {
      return { dueMs: loan.dueAt.toMillis() };
    }
    loanCheck(
      data.version === 0 &&
        loan.version === 0 &&
        copy.hold === false &&
        loan.dueAt.toMillis() > now,
      "failed-precondition",
      "Contact the librarian to renew."
    );

    const dueMs = loan.dueAt.toMillis() + loanPeriodMs;
    tx.update(loanRef, { version: 1, dueAt: Timestamp.fromMillis(dueMs) });
    return { dueMs };
  });
});
