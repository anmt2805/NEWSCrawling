const { Firestore, FieldPath, Timestamp } = require("@google-cloud/firestore");
const fs = require("fs");

const CACHE_DOC_TTL_MS = 3 * 24 * 60 * 60 * 1000;
const BATCH_SIZE = 400;
const COLLECTIONS = [
  { name: "alerts", timeField: "sentAt" },
  { name: "severity", timeField: "updatedAt" },
  { name: "translations", timeField: "updatedAt" }
];

let cachedServiceAccount = null;

function loadServiceAccount() {
  if (cachedServiceAccount) return cachedServiceAccount;
  try {
    const serviceJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    const servicePath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    if (serviceJson) {
      cachedServiceAccount = JSON.parse(serviceJson);
      return cachedServiceAccount;
    }
    if (servicePath && fs.existsSync(servicePath)) {
      const raw = fs.readFileSync(servicePath, "utf8");
      cachedServiceAccount = JSON.parse(raw);
      return cachedServiceAccount;
    }
  } catch (error) {
    console.error("Service account parse failed:", error.message || error);
  }
  return null;
}

function getFirestore() {
  const serviceAccount = loadServiceAccount();
  if (serviceAccount?.client_email && serviceAccount?.private_key) {
    return new Firestore({
      projectId: serviceAccount.project_id,
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: serviceAccount.private_key
      }
    });
  }
  return new Firestore();
}

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    if (!Number.isNaN(parsed)) return new Date(parsed);
  }
  return null;
}

function computeExpiresAt(baseDate) {
  const baseMs = baseDate ? baseDate.getTime() : Date.now();
  return Timestamp.fromDate(new Date(baseMs + CACHE_DOC_TTL_MS));
}

async function backfillCollection(db, config) {
  let updated = 0;
  let scanned = 0;
  let lastDoc = null;

  while (true) {
    let query = db
      .collection(config.name)
      .orderBy(FieldPath.documentId())
      .limit(BATCH_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    let writes = 0;

    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() || {};
      if (data.expiresAt) continue;
      const baseDate = toDate(data[config.timeField]);
      const expiresAt = computeExpiresAt(baseDate);
      batch.set(doc.ref, { expiresAt }, { merge: true });
      writes += 1;
    }

    if (writes > 0) {
      await batch.commit();
      updated += writes;
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < BATCH_SIZE) break;
  }

  return { updated, scanned };
}

async function run() {
  const db = getFirestore();
  let totalUpdated = 0;
  let totalScanned = 0;

  for (const config of COLLECTIONS) {
    const result = await backfillCollection(db, config);
    totalUpdated += result.updated;
    totalScanned += result.scanned;
    console.log(
      `[${config.name}] scanned=${result.scanned} updated=${result.updated}`
    );
  }

  console.log(
    `Done. scanned=${totalScanned} updated=${totalUpdated} ttlDays=3`
  );
}

run().catch((error) => {
  console.error("Backfill failed:", error.message || error);
  process.exitCode = 1;
});
