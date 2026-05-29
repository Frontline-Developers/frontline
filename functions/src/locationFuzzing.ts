import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

interface FuzzRequest {
  lat: number;
  lng: number;
}

interface FuzzResponse {
  lat: number;
  lng: number;
}

// Applies ±3km radius randomization to submitted coordinates.
// Called by the client before writing a report to Firestore.
export const fuzzReportLocation = onCall<FuzzRequest, Promise<FuzzResponse>>({ region: 'asia-southeast1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in to submit a report.');
  }

  const { lat, lng } = request.data;
  if (typeof lat !== 'number' || typeof lng !== 'number') {
    throw new HttpsError('invalid-argument', 'lat and lng must be numbers.');
  }

  const radiusKm = 3.0;
  const u = Math.random();
  const v = Math.random();
  const w = (radiusKm / 111.0) * Math.sqrt(u);
  const t = 2 * Math.PI * v;

  const fuzzedLat = lat + w * Math.cos(t);
  const fuzzedLng = lng + (w * Math.sin(t)) / Math.cos((lat * Math.PI) / 180);

  logger.info('fuzzReportLocation: applied ±3km fuzz', { originalLat: lat, originalLng: lng });

  return { lat: fuzzedLat, lng: fuzzedLng };
});
