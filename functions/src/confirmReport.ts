import {onCall, HttpsError} from "firebase-functions/v2/https";
import {processVote} from "./voteHelper.js";

export const confirmReport = onCall<{reportId: string}>(
  {region: "asia-southeast1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in to vote.");
    }

    const {reportId} = request.data;
    if (typeof reportId !== "string" || !reportId) {
      throw new HttpsError(
        "invalid-argument",
        "reportId must be a non-empty string.",
      );
    }

    return processVote(reportId, request.auth.uid, "confirm");
  },
);
