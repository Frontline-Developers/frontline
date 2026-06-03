import {firestore} from "firebase-admin";

export interface Report {
  userId: string;
  location: firestore.GeoPoint;
  geohash: string;
  category: "combat" | "aid" | "alert" | "displaced" | "infra" | "other";
  description: string;
  mediaUrls: string[];
  status: "pending" | "confirmed" | "disputed" | "withdrawn";
  confirmCount: number;
  disputeCount: number;
  systemConfirms: number;
  systemDisputes: number;
  totalEffectiveVolume: number;
  confidenceRatio: number;
  isDisputed: boolean;
  exifStripped: boolean;
  createdAt: firestore.Timestamp;
}

export interface Interaction {
  type: "confirm" | "dispute";
  token: string;
  createdAt: firestore.FieldValue;
}

export interface WireArticle {
  title: string;
  body?: string;
  url: string;
  source: "wire";
  publishedAt: firestore.Timestamp;
  geohash5?: string;
}

export const CONSENSUS = {
  MIN_VOLUME: 5,
  CONFIRM_RATIO: 0.75,
  DISPUTE_RATIO: 0.6,
} as const;
