import {HttpsError} from "firebase-functions/v2/https";
import {FieldValue} from "firebase-admin/firestore";
import {randomBytes} from "crypto";
import {db} from "./admin.js";
import {CONSENSUS, Report} from "./types.js";

export interface ConsensusParams {
  confirmCount: number;
  disputeCount: number;
  systemConfirms: number;
  systemDisputes: number;
  currentStatus: string;
}

export interface ConsensusResult {
  status: string;
  cEff: number;
  dEff: number;
  V: number;
  R: number;
}

export function calculateConsensusStatus(
  params: ConsensusParams,
): ConsensusResult {
  const {
    confirmCount,
    disputeCount,
    systemConfirms,
    systemDisputes,
    currentStatus,
  } = params;

  const cEff = confirmCount + systemConfirms;
  const dEff = disputeCount + systemDisputes;
  const V = cEff + dEff;
  const R = V === 0 ? 0 : cEff / V;

  let status = currentStatus;

  if (currentStatus !== "withdrawn") {
    if (V < CONSENSUS.MIN_VOLUME) {
      status = "pending";
    } else if (R >= CONSENSUS.CONFIRM_RATIO) {
      status = "confirmed";
    } else if (dEff / V >= CONSENSUS.DISPUTE_RATIO) {
      status = "disputed";
    }
    // else: volume met but neither threshold — keep current status
  }

  return {status, cEff, dEff, V, R};
}

export function randomHex(bytes: number): string {
  return randomBytes(bytes).toString("hex");
}

export async function processVote(
  reportId: string,
  userId: string,
  voteType: "confirm" | "dispute",
): Promise<{
  status: string;
  totalEffectiveVolume: number;
  confidenceRatio: number;
}> {
  return db.runTransaction(async (tx) => {
    const reportRef = db.doc(`reports/${reportId}`);
    const interactionRef = db.doc(`reports/${reportId}/interactions/${userId}`);

    const interactionSnap = await tx.get(interactionRef);
    if (interactionSnap.exists) {
      throw new HttpsError(
        "already-exists",
        "You have already voted on this report.",
      );
    }

    const reportSnap = await tx.get(reportRef);
    if (!reportSnap.exists) {
      throw new HttpsError("not-found", "Report not found.");
    }
    const report = reportSnap.data() as Report;

    const newConfirmCount =
      report.confirmCount + (voteType === "confirm" ? 1 : 0);
    const newDisputeCount =
      report.disputeCount + (voteType === "dispute" ? 1 : 0);

    const {
      status: newStatus,
      V,
      R,
    } = calculateConsensusStatus({
      confirmCount: newConfirmCount,
      disputeCount: newDisputeCount,
      systemConfirms: report.systemConfirms ?? 0,
      systemDisputes: report.systemDisputes ?? 0,
      currentStatus: report.status,
    });

    tx.set(interactionRef, {
      type: voteType,
      token: randomHex(16),
      createdAt: FieldValue.serverTimestamp(),
    });

    const countField = voteType === "confirm" ? "confirmCount" : "disputeCount";
    tx.update(reportRef, {
      [countField]: FieldValue.increment(1),
      totalEffectiveVolume: V,
      confidenceRatio: R,
      status: newStatus,
    });

    return {status: newStatus, totalEffectiveVolume: V, confidenceRatio: R};
  });
}
