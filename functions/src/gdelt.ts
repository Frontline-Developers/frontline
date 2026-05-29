import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();

// Fetches GDELT GeoJSON feed every 30 minutes and writes articles to wire_news/.
// TODO: implement GDELT JSON 2.0 feed parsing and deduplication.
export const fetchGdeltNews = onSchedule({ schedule: 'every 30 minutes', region: 'asia-southeast1' }, async () => {
  logger.info('fetchGdeltNews: stub — not yet implemented');
  // Stub: add real GDELT fetch + Firestore writes here.
  await Promise.resolve();
});
