import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions/v2";

/**
 * Triggered when a new report is written to reports/{reportId}.
 *
 * Queries user_alerts/{uid}/subscriptions for subscriptions whose:
 *   - categories array contains the report's category
 *   - radiusKm >= distance(subscription.lat/lng, report.lat/lng)
 *
 * For each matching subscription that has a stored FCM token in
 * user_tokens/{uid}, sends a push notification via FCM.
 */
export const sendAlertNotifications = onDocumentCreated(
  "reports/{reportId}",
  async (event) => {
    const report = event.data?.data();
    if (!report) return;

    const {category, location, description} = report as {
      category: string;
      location: {latitude: number; longitude: number};
      description: string;
    };

    const db = getFirestore();
    const messaging = getMessaging();

    // Collect all subscriptions across all users.
    const alertsSnap = await db.collectionGroup("subscriptions").get();

    // Filter to subscriptions that match category + radius before any I/O.
    type SubData = {
      userId: string;
      categories: string[];
      lat: number;
      lng: number;
      radiusKm: number;
      locationLabel: string;
    };

    const matched = alertsSnap.docs.filter((doc) => {
      const sub = doc.data() as SubData;
      if (!sub.categories.includes(category)) return false;
      const distKm = _haversineKm(
        sub.lat,
        sub.lng,
        location.latitude,
        location.longitude,
      );
      return distKm <= sub.radiusKm;
    });

    if (matched.length === 0) {
      logger.info(
        `No matching subscriptions for report ${event.params.reportId}`,
      );
      return;
    }

    // Fetch all FCM tokens in parallel.
    const tokenDocs = await Promise.all(
      matched.map((doc) =>
        db.doc(`user_tokens/${(doc.data() as SubData).userId}`).get(),
      ),
    );

    const bodyText =
      description && description.length > 120
        ? `${description.slice(0, 117)}...`
        : (description ?? "");

    const sends: Promise<void>[] = [];

    for (let i = 0; i < matched.length; i++) {
      const sub = matched[i].data() as SubData;
      const fcmToken = tokenDocs[i].data()?.token as string | undefined;
      if (!fcmToken) continue;

      const categoryLabel = _categoryLabel(category);
      sends.push(
        messaging
          .send({
            token: fcmToken,
            notification: {
              title: `${categoryLabel} near ${sub.locationLabel}`,
              body: bodyText || categoryLabel,
            },
            data: {
              reportId: event.params.reportId,
              category,
            },
          })
          .then(() => {
            logger.info(
              `Notified ${sub.userId} for report ${event.params.reportId}`,
            );
          })
          .catch((err) => {
            logger.error(`Failed to notify ${sub.userId}`, err);
          }),
      );
    }

    await Promise.all(sends);
    logger.info(
      `Processed ${sends.length} notifications for report ${event.params.reportId}`,
    );
  },
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function _haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371;
  const dLat = _rad(lat2 - lat1);
  const dLng = _rad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(_rad(lat1)) * Math.cos(_rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function _rad(deg: number): number {
  return (deg * Math.PI) / 180;
}

function _categoryLabel(category: string): string {
  const labels: Record<string, string> = {
    combat: "Combat / strike",
    aid: "Humanitarian aid",
    alert: "Air alert / siren",
    displaced: "Displaced persons",
    infra: "Infrastructure",
    other: "Other",
  };
  return labels[category] ?? category;
}
