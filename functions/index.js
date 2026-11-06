/**
 * ASB House Hub - Background Certificate Verification Service
 * Autonomous Lead Backend Engineer Implementation
 * 
 * Uses Firebase Cloud Functions (v2) and Google Cloud Vision API to automatically
 * analyze uploaded competition certificates, detect institutional seals/signatures,
 * and synchronize verification statuses in Firestore.
 */

const { onObjectFinalized } = require("firebase-functions/v2/storage");
const admin = require("firebase-admin");
const vision = require("@google-cloud/vision");

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// Export zero-trust server-authoritative modules
exports.schoolElection = require("./elections-v2").schoolElection;
exports.schoolLibrary = require("./library-v2").schoolLibrary;

// Initialize Google Cloud Vision API Client
const visionClient = new vision.ImageAnnotatorClient();

/**
 * Cloud Storage Trigger: verifyCertificateSignature
 * Listens specifically for finalized object uploads in the `house_claims/` bucket path.
 */
exports.verifyCertificateSignature = onObjectFinalized(async (event) => {
  const filePath = event.data.name || "";
  const bucketName = event.data.bucket;

  // 1. Path Filtering: Target only uploads inside house_claims/{houseName}/{fileName}
  if (!filePath.startsWith("house_claims/")) {
    console.log(`[Skip] Upload not in house_claims directory: ${filePath}`);
    return null;
  }

  const parts = filePath.split("/");
  if (parts.length < 3) {
    console.log(`[Skip] Upload structure invalid or missing fileName: ${filePath}`);
    return null;
  }

  const houseName = parts[1].toLowerCase().trim();
  const rawFileName = parts.slice(2).join("/"); // Expected format: scholarNo_claimId.jpg (e.g., 123456_abc123.jpg)
  const fileName = rawFileName.split("/").pop() || rawFileName;

  // Ignore non-image uploads or temporary files
  if (!fileName.match(/\.(jpg|jpeg|png|webp|pdf)$/i)) {
    console.log(`[Skip] Non-supported file extension: ${fileName}`);
    return null;
  }

  // 2. Filename Parsing: Extract scholarNo and claimId
  const nameWithoutExt = fileName.substring(0, fileName.lastIndexOf("."));
  const nameParts = nameWithoutExt.split("_");
  
  if (nameParts.length < 2) {
    console.error(`[Error] Invalid filename format "${fileName}". Expected format: scholarNo_claimId.jpg`);
    return null;
  }

  const scholarNo = nameParts[0];
  const claimId = nameParts.slice(1).join("_"); // Support claimIds that may contain underscores
  const claimRef = db.collection("house_claims").doc(claimId);

  console.log(`[Processing] Verifying claim "${claimId}" for Scholar #${scholarNo} (${houseName} House)...`);

  const gcsUri = `gs://${bucketName}/${filePath}`;
    let aiStatus = "unrecognized";
    let aiConfidence = 0.0;
    let aiMarkers = [];
    let logMsg = "";

    try {
      // 3. Core AI Logic - Primary Check: Logo Detection
      console.log(`[Vision API] Running Logo Detection on ${gcsUri}...`);
      const [logoResult] = await visionClient.logoDetection(gcsUri);
      const logos = logoResult.logoAnnotations || [];

      // Institutional markers indicating official Asian School seal or recognized entity
      const institutionalLogoMarkers = [
        "the asian school",
        "asian school",
        "asb",
        "official school stamp",
        "school seal",
        "ministry of education"
      ];

      let matchFound = false;
      for (const logo of logos) {
        const desc = (logo.description || "").toLowerCase();
        const score = (logo.score * 100).toFixed(1);
        console.log(` -> Detected Logo: "${desc}" (Confidence: ${score}%)`);

        if (institutionalLogoMarkers.some((marker) => desc.includes(marker))) {
          matchFound = true;
          aiStatus = "verified";
          aiConfidence = parseFloat(score);
          aiMarkers.push(logo.description);
          logMsg = `Verified via Institutional Logo Detection: "${logo.description}" (${score}% confidence)`;
          break;
        }
      }

      // 4. Core AI Logic - Fallback Check: Document Text Detection (OCR)
      if (!matchFound) {
        console.log(`[Vision API] No primary logo matched. Running Fallback Document Text Detection (OCR)...`);
        const [textResult] = await visionClient.documentTextDetection(gcsUri);
        const fullText = (textResult.fullTextAnnotation && textResult.fullTextAnnotation.text)
          ? textResult.fullTextAnnotation.text.toLowerCase()
          : "";

        // Keywords signifying official school approval or authentic certification
        const institutionalTextMarkers = [
          "principal",
          "official seal",
          "the asian school",
          "asian school bahrain",
          "asb.edu.bh",
          "asianschool.bh",
          "certificate of merit",
          "inter-house"
        ];

        const matchedPhrases = institutionalTextMarkers.filter((marker) => fullText.includes(marker));

        if (matchedPhrases.length > 0) {
          aiStatus = "verified";
          aiConfidence = 85.0;
          aiMarkers = matchedPhrases;
          logMsg = `Verified via Fallback Text Detection (Found markers: ${matchedPhrases.join(", ")})`;
        } else {
          aiStatus = "unrecognized";
          aiConfidence = 15.0;
          logMsg = "AI Scan: No school markers, official seals, or recognized signatures detected.";
        }
      }

      // 5. Firestore Synchronization: Record AI metadata while preserving human-in-the-loop 'pending' status
      await claimRef.set({
        scholar_no: scholarNo,
        house_name: houseName,
        file_path: filePath,
        status: "pending", // Preserved in staff moderation queue for final human approval
        ai_status: aiStatus,
        ai_confidence: aiConfidence,
        ai_markers: aiMarkers,
        ai_summary: logMsg,
        ai_processed_at: admin.firestore.FieldValue.serverTimestamp(),
        verificationLogs: admin.firestore.FieldValue.arrayUnion(logMsg),
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        verified_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      console.log(`[Success] Claim "${claimId}" AI scanned. AI Status: ${aiStatus} (${aiConfidence}%) | Summary: "${logMsg}"`);
      return null;

    } catch (error) {
      // 6. Graceful Error Handling: Prevent unhandled rejections and flag for human review
      console.error(`[Fatal Error] Vision API processing failed for claim "${claimId}":`, error);

      const errorLogMsg = `Error during Vision API processing: ${error.message || "Timeout / API Failure"}`;

      await claimRef.set({
        scholar_no: scholarNo,
        house_name: houseName,
        file_path: filePath,
        status: "pending", // Kept in pending queue so staff can review manually
        ai_status: "error",
        ai_confidence: 0.0,
        ai_summary: errorLogMsg,
        ai_processed_at: admin.firestore.FieldValue.serverTimestamp(),
        verificationLogs: admin.firestore.FieldValue.arrayUnion(errorLogMsg),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      return null;
    }
});
