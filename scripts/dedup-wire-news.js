#!/usr/bin/env node
// One-time cleanup: removes duplicate wire_news docs that share the same title,
// keeping only the highest-priority source per story.

const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({ projectId: 'frontline-549fb' });
const db = admin.firestore();

const SOURCE_PRIORITY = {
  'reuters.com': 10, 'apnews.com': 10,
  'bbc.com': 9, 'bbc.co.uk': 9, 'kyivindependent.com': 9,
  'theguardian.com': 8, 'aljazeera.com': 8, 'nytimes.com': 8,
  'pravda.com.ua': 8, 'ukrinform.net': 8, 'rferl.org': 8,
  'washingtonpost.com': 7, 'cnn.com': 7, 'axios.com': 7,
};

function priority(domain) { return SOURCE_PRIORITY[domain] ?? 1; }
function key(title) {
  return title.toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 60);
}

async function run() {
  const snap = await db.collection('wire_news').get();
  console.log(`${snap.size} total docs`);

  const best = new Map(); // key → { id, domain }
  const all  = new Map(); // key → [{ id, domain }, ...]

  for (const doc of snap.docs) {
    const { title, sourceDomain } = doc.data();
    const k = key(title ?? '');
    if (!all.has(k)) all.set(k, []);
    all.get(k).push({ id: doc.id, domain: sourceDomain ?? '' });

    const cur = best.get(k);
    if (!cur || priority(sourceDomain) > priority(cur.domain)) {
      best.set(k, { id: doc.id, domain: sourceDomain ?? '' });
    }
  }

  const toDelete = [];
  for (const [k, docs] of all.entries()) {
    const keepId = best.get(k).id;
    for (const doc of docs) {
      if (doc.id !== keepId) toDelete.push(doc.id);
    }
  }

  console.log(`Deleting ${toDelete.length} duplicate docs, keeping ${best.size} unique stories`);
  if (toDelete.length === 0) { console.log('Nothing to delete.'); return; }

  // Firestore batch limit is 500
  for (let i = 0; i < toDelete.length; i += 500) {
    const batch = db.batch();
    toDelete.slice(i, i + 500).forEach(id => batch.delete(db.collection('wire_news').doc(id)));
    await batch.commit();
  }
  console.log('Done.');
}

run().catch(err => { console.error(err); process.exit(1); });
