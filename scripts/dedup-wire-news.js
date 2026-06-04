#!/usr/bin/env node
// One-time cleanup: removes duplicate wire_news docs that share the same title,
// keeping only the highest-priority source per story.

const admin = require("../functions/node_modules/firebase-admin");
const isProd = process.argv.includes("--prod");
if (!process.env.FIRESTORE_EMULATOR_HOST && !isProd) {
  process.env.FIRESTORE_EMULATOR_HOST = "localhost:8080";
}
if (
  !process.env.FIRESTORE_EMULATOR_HOST &&
  isProd &&
  !process.argv.includes("--yes-delete")
) {
  throw new Error("Refusing to run against production without --yes-delete");
}
admin.initializeApp({ projectId: "frontline-549fb" });
const db = admin.firestore();

const SOURCE_PRIORITY = {
  "reuters.com": 10,
  "apnews.com": 10,
  "bbc.com": 9,
  "bbc.co.uk": 9,
  "kyivindependent.com": 9,
  "theguardian.com": 8,
  "aljazeera.com": 8,
  "nytimes.com": 8,
  "pravda.com.ua": 8,
  "ukrinform.net": 8,
  "rferl.org": 8,
  "washingtonpost.com": 7,
  "cnn.com": 7,
  "axios.com": 7,
};

function priority(domain) {
  return SOURCE_PRIORITY[domain] ?? 1;
}
function key(title) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 60);
}

async function run() {
  const snap = await db.collection("wire_news").get();
  console.log(`${snap.size} total docs`);

  // Pass 1: deduplicate by normalised title (keep highest-priority source).
  const bestByTitle = new Map(); // titleKey → { id, domain }
  const allByTitle = new Map();  // titleKey → [{ id, domain }, ...]

  for (const doc of snap.docs) {
    const { title, sourceDomain } = doc.data();
    const k = key(title ?? "");
    if (!allByTitle.has(k)) allByTitle.set(k, []);
    allByTitle.get(k).push({ id: doc.id, domain: sourceDomain ?? "" });

    const cur = bestByTitle.get(k);
    if (!cur || priority(sourceDomain) > priority(cur.domain)) {
      bestByTitle.set(k, { id: doc.id, domain: sourceDomain ?? "" });
    }
  }

  const toDelete = new Set();
  for (const [k, docs] of allByTitle.entries()) {
    const keepId = bestByTitle.get(k).id;
    for (const doc of docs) {
      if (doc.id !== keepId) toDelete.add(doc.id);
    }
  }

  // Pass 2: deduplicate by imageUrl among the docs that survived pass 1.
  // Two articles with the same og:image are the same story under a different headline.
  const seenImages = new Map(); // imageUrl → { id, priority }
  for (const doc of snap.docs) {
    if (toDelete.has(doc.id)) continue;
    const { imageUrl, sourceDomain } = doc.data();
    if (!imageUrl) continue;
    const existing = seenImages.get(imageUrl);
    if (!existing) {
      seenImages.set(imageUrl, { id: doc.id, pri: priority(sourceDomain ?? "") });
    } else if (priority(sourceDomain ?? "") > existing.pri) {
      toDelete.add(existing.id);
      seenImages.set(imageUrl, { id: doc.id, pri: priority(sourceDomain ?? "") });
    } else {
      toDelete.add(doc.id);
    }
  }

  const deleteIds = [...toDelete];
  const kept = snap.size - deleteIds.length;
  console.log(`Deleting ${deleteIds.length} duplicate docs, keeping ${kept} unique stories`);
  if (deleteIds.length === 0) {
    console.log("Nothing to delete.");
    return;
  }

  // Firestore batch limit is 500
  for (let i = 0; i < deleteIds.length; i += 500) {
    const batch = db.batch();
    deleteIds
      .slice(i, i + 500)
      .forEach((id) => batch.delete(db.collection("wire_news").doc(id)));
    await batch.commit();
  }
  console.log("Done.");
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
