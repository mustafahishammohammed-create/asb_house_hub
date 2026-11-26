# ASB House Hub — Financial & Infrastructure Pricing Guide (BHD)
**Organization:** The Asian School, Kingdom of Bahrain  
**Currency:** Bahraini Dinar (BHD) *(Fixed Peg: 1 USD = 0.376 BHD)*  

> Audit correction — 26 November 2026: Firebase claims below have been corrected. Other vendor fees, waiver conditions, exchange conversions, and AI estimates are historical estimates and were not revalidated in this code audit. They are not a current procurement quote.

---

## 1. Master Pricing & Annual Cost Table

| Service / Item | Upfront Cost (BHD) | Annual Recurring Cost (BHD) | Payable To | Notes / Waivers |
| :--- | :--- | :--- | :--- | :--- |
| **Apple Developer Account** | **37.300 BHD** *(or **0.000 BHD**)* | **37.300 BHD / year** *(or **0.000 BHD**)* | Apple Inc. | **0.000 BHD (FREE)** with the School Educational Fee Waiver. |
| **Google Play Developer Account** | **9.425 BHD** | **0.000 BHD / year** | Google LLC | **One-time lifetime payment** for unlimited Android apps. |
| **Google Firebase Backend** | Usage dependent | Usage dependent | Google Cloud | Blaze is required for Functions and Cloud Storage; allowances do not guarantee a zero bill. |
| **Google Gemini Cloud AI** | **0.000 BHD** | **~1.900 to 5.600 BHD / year** | Google Cloud | Pay-as-you-go based on student queries (~0.350 BHD / month). |
| **Historical subtotal (With Apple School Waiver)** | **9.425 BHD** | **~1.900 to 5.600 BHD / year** | — | Excludes variable Firebase/backend costs. |
| **Historical subtotal (Without Apple Waiver)** | **46.725 BHD** | **~39.200 to 42.900 BHD / year** | — | Excludes variable Firebase/backend costs. |

---

## 2. Apple Developer Account (37.300 BHD/Year vs 0.000 BHD Waiver)

### Pricing:
* **Standard Cost:** **37.300 BHD per year** ($99.00 USD)
* **With Educational Fee Waiver:** **0.000 BHD per year (100% FREE forever)**

### 🎓 Apple Fee Waiver Criteria (The Asian School Bahrain):
1. **Accredited School:** Must be registered as an accredited educational institution in Bahrain.
2. **D-U-N-S® Number:** Must have an official 9-digit D-U-N-S number from Dun & Bradstreet ([dnb.com](https://www.dnb.com/)) at zero cost.
3. **Authorized School Official:** Application submitted by Principal, Director, or authorized IT Administrator.
4. **Free App on App Store:** The app must be 100% free for students with no in-app purchases.

### Step-by-Step Waiver Application:
1. Go to **[developer.apple.com/programs/enroll/](https://developer.apple.com/programs/enroll/)**.
2. Sign in with the school's administrative Apple ID.
3. Select **"Accredited Educational Institution"**.
4. Check the box: **"Request a fee waiver for an accredited educational institution"**.
5. Apple verifies credentials within 2–5 business days and activates the account for **0.000 BHD**.

---

## 3. Google Play Developer Account (9.425 BHD One-Time)

### Pricing:
* **One-Time Registration Fee:** **9.425 BHD** ($25.00 USD)
* **Annual Maintenance Fee:** **0.000 BHD (No recurring cost)**

### Key Details:
* Lifetime account for publishing and updating Android apps.
* Registering as **The Asian School (Organization)** exempts the school from Google's 20-tester testing requirement.

---

## 4. Firebase billing and implementation requirements

The last recorded project decision is Spark; billing was not changed or independently rechecked in this audit. A live read-only inventory found no deployed Functions. Firestore/client fixes can be made within Spark limits, but the planned Firebase Functions require Blaze.

Cloud Storage requires Blaze, including continued legacy bucket access starting 3 February 2026. The former claim that photo storage stays permanently free on Spark was incorrect. Usage allowances depend on service, bucket and location, and are not a guaranteed annual cost. [Official Storage changes](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)

A defensible budget must include measured Firestore reads/writes, Storage capacity and transfer, function execution, Vision requests, logging, and separate Gemini usage. Previous school-usage figures were estimates, not load-test measurements. Set budgets and alerts and review usage; alerts do not cap spending.

See [Blaze requirements and backend readiness](election_audit/BLAZE_REQUIRED_FEATURES.md) for the implementation and verification prerequisites. Paying for Blaze does not repair the missing integrations or authorization faults.

---

## 5. Google Gemini AI Pricing (BHD & Fils Breakdown)

The in-app **House AI Mentor** (Ignis, Zephyr, Sylva, Solis) is powered by Google Gemini Flash.

### Exact Cost Breakdown in BHD / Fils:

* **Cost Per 1 Student Question:** **~0.000048 BHD (0.048 Fils)**
* **Cost Per 1,000 Student Questions:** **~0.045 BHD (45 Fils)**
* **Cost Per 10,000 Student Questions:** **~0.478 BHD (478 Fils)**
* **Estimated Monthly AI Cost (~5,000 questions):** **~0.239 BHD (239 Fils / month)**
* **Estimated Annual AI Cost:** **~2.870 BHD / year**

---

## 6. Historical subtotals (BHD; incomplete budget)

These figures exclude variable Firebase/backend costs and use unverified historical AI/vendor estimates. Recalculate before approval.

### With Apple Fee Waiver (Recommended):
* **Year 1 Total Outlay:** **9.425 BHD** *(Google Play)* + **~2.870 BHD** *(Annual AI)* = **~12.295 BHD**
* **Year 2 & Beyond:** **~2.870 BHD / year** *(historical AI estimate, plus Firebase/backend usage)*

### Without Apple Fee Waiver (Standard Commercial):
* **Year 1 Total Outlay:** **37.300 BHD** *(Apple)* + **9.425 BHD** *(Google Play)* + **~2.870 BHD** *(AI)* = **~49.595 BHD**
* **Year 2 & Beyond:** **37.300 BHD** *(Apple)* + **~2.870 BHD** *(AI)* = **~40.170 BHD / year**
