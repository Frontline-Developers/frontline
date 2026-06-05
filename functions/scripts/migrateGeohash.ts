/**
 * One-time migration: convert flat-string `geohash` fields to the nested map
 * structure that geoflutterfire_plus expects — {geohash: string, geopoint: GeoPoint}.
 *
 * Usage (from the functions/ directory):
 *   npx ts-node --project scripts/tsconfig.json scripts/migrateGeohash.ts
 *
 * The script is idempotent: documents that already have the nested structure
 * are skipped. Progress and counts are logged to stdout.
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS to point to a service account JSON,
 * or run inside the project's gcloud auth context.
 */

import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const BATCH_SIZE = 400; // Firestore max is 500; keep headroom

async function migrate(): Promise<void> {
  console.log('Scanning reports collection…');

  const snapshot = await db.collection('reports').get();
  const total = snapshot.size;
  console.log(`Found ${total} documents.`);

  let skipped = 0;
  let updated = 0;
  let errors = 0;

  const docs = snapshot.docs;

  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = docs.slice(i, i + BATCH_SIZE);
    let batchCount = 0;

    for (const doc of chunk) {
      const data = doc.data();
      const geohash = data['geohash'];

      // Already migrated or missing entirely — skip.
      if (typeof geohash !== 'string') {
        skipped++;
        continue;
      }

      const location = data['location'] as admin.firestore.GeoPoint | undefined;
      if (!location) {
        console.warn(`  [SKIP] ${doc.id} — has string geohash but no location GeoPoint`);
        skipped++;
        continue;
      }

      batch.update(doc.ref, {
        geohash: {
          geohash,
          geopoint: location,
        },
      });
      batchCount++;
    }

    if (batchCount > 0) {
      try {
        await batch.commit();
        updated += batchCount;
        console.log(`  Committed batch (docs ${i + 1}–${Math.min(i + BATCH_SIZE, total)}): ${batchCount} updated`);
      } catch (err) {
        console.error(`  Batch commit failed:`, err);
        errors += batchCount;
      }
    }
  }

  console.log('\nDone.');
  console.log(`  Updated : ${updated}`);
  console.log(`  Skipped : ${skipped}`);
  console.log(`  Errors  : ${errors}`);
}

migrate().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
