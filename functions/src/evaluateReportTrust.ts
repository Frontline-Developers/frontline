import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import ngeohash from "ngeohash";
import {parse as parseExif} from "exifr";
import {db, storage} from "./admin.js";
import {haversineKm, speedKmh} from "./geo.js";
import {calculateConsensusStatus} from "./voteHelper.js";
import type {Report} from "./types.js";

const EXIF_DISTANCE_THRESHOLD_KM = 5.0;
const EXIF_TIME_THRESHOLD_MINUTES = 60;
const WIRE_NEWS_WINDOW_HOURS = 24;
const FLASH_MOB_WINDOW_MINUTES = 15;
const FLASH_MOB_MIN_UIDS = 4;
const IMPOSSIBLE_TRAVEL_WINDOW_HOURS = 1;
const IMPOSSIBLE_SPEED_KMH = 900;
const GEOHASH_PRECISION_WIRE = 5;
const GEOHASH_PRECISION_SPIKE = 6;

// Standard GeoFire range-query sentinel: sorts above all geohash characters.
const GEOHASH_RANGE_END = String.fromCharCode(0xf8ff);

const CATEGORY_KEYWORDS: Record<string, string[]> = {
  combat: [
    "attack",
    "conflict",
    "military",
    "violence",
    "shooting",
    "explosion",
    "combat",
    "fighting",
    "war",
  ],
  aid: [
    "relief",
    "humanitarian",
    "aid",
    "assistance",
    "rescue",
    "evacuation",
    "shelter",
    "food",
    "supplies",
  ],
  alert: [
    "alert",
    "warning",
    "danger",
    "flood",
    "fire",
    "emergency",
    "hazard",
    "risk",
    "threat",
  ],
  displaced: [
    "displaced",
    "refugee",
    "evacuated",
    "homeless",
    "migration",
    "exodus",
    "fleeing",
  ],
  infra: [
    "infrastructure",
    "bridge",
    "road",
    "power",
    "blackout",
    "outage",
    "damage",
    "collapse",
    "destroyed",
  ],
  other: [],
};

async function heuristicExifCheck(
  reportId: string,
  report: Report,
  reportRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  if (report.exifStripped || report.mediaUrls.length === 0) return;

  const bucket = storage.bucket();
  for (const mediaPath of report.mediaUrls) {
    try {
      const [buffer] = await bucket.file(mediaPath).download();
      const exif = await parseExif(buffer as Buffer, {gps: true, tiff: true});

      if (exif == null || exif.latitude == null || exif.longitude == null)
        continue;

      const distKm = haversineKm(
        report.location.latitude,
        report.location.longitude,
        exif.latitude as number,
        exif.longitude as number,
      );
      if (distKm > EXIF_DISTANCE_THRESHOLD_KM) continue;

      const exifTime: Date | undefined = exif.DateTimeOriginal as
        | Date
        | undefined;
      if (!exifTime) continue;

      const diffMs = Math.abs(exifTime.getTime() - report.createdAt.toMillis());
      const diffMinutes = diffMs / 60_000;
      if (diffMinutes > EXIF_TIME_THRESHOLD_MINUTES) continue;

      await reportRef.update({systemConfirms: FieldValue.increment(3)});
      logger.info("evaluateReportTrust: EXIF match", {
        reportId,
        distKm,
        diffMinutes,
      });
      return;
    } catch (err) {
      logger.warn("evaluateReportTrust: EXIF parse error", {
        reportId,
        error: String(err),
      });
    }
  }
}

async function heuristicWireCorroboration(
  reportId: string,
  report: Report,
  reportRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  const lat = report.location.latitude;
  const lng = report.location.longitude;

  const geohash5 = ngeohash.encode(lat, lng, GEOHASH_PRECISION_WIRE);
  const neighbors = ngeohash.neighbors(geohash5);
  const cells = [geohash5, ...neighbors];

  const cutoff = Timestamp.fromDate(
    new Date(Date.now() - WIRE_NEWS_WINDOW_HOURS * 60 * 60 * 1000),
  );

  const snap = await db
    .collection("wire_news")
    .where("geohash5", "in", cells)
    .where("publishedAt", ">=", cutoff)
    .get();

  if (snap.empty) return;

  const keywords = CATEGORY_KEYWORDS[report.category] ?? [];
  for (const doc of snap.docs) {
    const {title = "", body = ""} = doc.data() as {
      title?: string;
      body?: string;
    };
    const text = `${title} ${body}`.toLowerCase();
    if (keywords.some((kw) => text.includes(kw))) {
      await reportRef.update({systemConfirms: FieldValue.increment(2)});
      logger.info("evaluateReportTrust: wire corroboration match", {reportId});
      return;
    }
  }
}

async function heuristicSpatialSpike(
  reportId: string,
  report: Report,
  reportRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  const lat = report.location.latitude;
  const lng = report.location.longitude;

  const prefix = ngeohash.encode(lat, lng, GEOHASH_PRECISION_SPIKE);
  const cutoff = Timestamp.fromDate(
    new Date(Date.now() - FLASH_MOB_WINDOW_MINUTES * 60 * 1000),
  );

  const snap = await db
    .collection("reports")
    .where("geohash", ">=", prefix)
    .where("geohash", "<=", prefix + GEOHASH_RANGE_END)
    .where("category", "==", report.category)
    .where("createdAt", ">=", cutoff)
    .get();

  const uids = new Set<string>(
    snap.docs.map((d) => (d.data() as Report).userId),
  );
  uids.add(report.userId);

  if (uids.size < FLASH_MOB_MIN_UIDS) return;

  const updates: Promise<unknown>[] = [];
  for (const doc of snap.docs) {
    if (doc.id !== reportId) {
      updates.push(doc.ref.update({systemConfirms: FieldValue.increment(2)}));
    }
  }
  updates.push(reportRef.update({systemConfirms: FieldValue.increment(2)}));
  await Promise.all(updates);

  logger.info("evaluateReportTrust: spatial spike detected", {
    reportId,
    clusterSize: snap.size,
    distinctUids: uids.size,
  });
}

async function heuristicImpossibleTravel(
  reportId: string,
  report: Report,
  reportRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  const cutoff = Timestamp.fromDate(
    new Date(Date.now() - IMPOSSIBLE_TRAVEL_WINDOW_HOURS * 60 * 60 * 1000),
  );

  const snap = await db
    .collection("reports")
    .where("userId", "==", report.userId)
    .where("createdAt", ">=", cutoff)
    .get();

  for (const doc of snap.docs) {
    if (doc.id === reportId) continue;

    const prev = doc.data() as Report;
    const distKm = haversineKm(
      report.location.latitude,
      report.location.longitude,
      prev.location.latitude,
      prev.location.longitude,
    );
    const timeDeltaMs =
      report.createdAt.toMillis() -
      (prev.createdAt as unknown as {toMillis(): number}).toMillis();
    if (timeDeltaMs <= 0) continue;
    const speed = speedKmh(distKm, timeDeltaMs);

    if (speed > IMPOSSIBLE_SPEED_KMH) {
      await reportRef.update({systemDisputes: FieldValue.increment(5)});
      logger.warn("evaluateReportTrust: impossible travel", {
        reportId,
        speedKmh: speed,
        distKm,
      });
      return;
    }
  }
}

export const evaluateReportTrust = onDocumentCreated(
  {document: "reports/{reportId}", region: "asia-southeast1"},
  async (event) => {
    const reportId = event.params.reportId;
    const report = event.data?.data() as Report | undefined;

    if (!report) {
      logger.warn("evaluateReportTrust: no data in event", {reportId});
      return;
    }

    const reportRef = db.doc(`reports/${reportId}`);

    await Promise.allSettled([
      heuristicExifCheck(reportId, report, reportRef).catch((err) =>
        logger.warn("evaluateReportTrust: exif heuristic error", {
          reportId,
          error: String(err),
        }),
      ),
      heuristicWireCorroboration(reportId, report, reportRef).catch((err) =>
        logger.warn("evaluateReportTrust: wire heuristic error", {
          reportId,
          error: String(err),
        }),
      ),
      heuristicSpatialSpike(reportId, report, reportRef).catch((err) =>
        logger.warn("evaluateReportTrust: spike heuristic error", {
          reportId,
          error: String(err),
        }),
      ),
      heuristicImpossibleTravel(reportId, report, reportRef).catch((err) =>
        logger.warn("evaluateReportTrust: travel heuristic error", {
          reportId,
          error: String(err),
        }),
      ),
    ]);

    // Recalculate derived fields now that all heuristics have applied system signals.
    // Without this, totalEffectiveVolume and confidenceRatio would be stale until
    // the next human vote.
    const updatedSnap = await reportRef.get();
    if (updatedSnap.exists) {
      const updated = updatedSnap.data() as Report;
      const {
        V,
        R,
        status: newStatus,
      } = calculateConsensusStatus({
        confirmCount: updated.confirmCount ?? 0,
        disputeCount: updated.disputeCount ?? 0,
        systemConfirms: updated.systemConfirms ?? 0,
        systemDisputes: updated.systemDisputes ?? 0,
        currentStatus: updated.status,
      });
      await reportRef.update({
        totalEffectiveVolume: V,
        confidenceRatio: R,
        status: newStatus,
      });
    }
  },
);
