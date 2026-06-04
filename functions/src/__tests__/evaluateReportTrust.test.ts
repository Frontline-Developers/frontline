// Mocks must be established before imports.
const mockIncrement = jest.fn().mockReturnValue({_increment: true});
const mockUpdate = jest.fn().mockResolvedValue(undefined);
const mockDocGet = jest.fn().mockResolvedValue({
  exists: true,
  data: () => ({
    confirmCount: 0,
    disputeCount: 0,
    systemConfirms: 0,
    systemDisputes: 0,
    status: "pending",
  }),
});
const mockDocRef = {update: mockUpdate, get: mockDocGet, path: "reports/r1"};
const mockDocFn = jest.fn().mockReturnValue(mockDocRef);

const mockCollectionGet = jest.fn();
const mockCollectionWhere = jest.fn();
const mockCollectionRef = {
  where: mockCollectionWhere,
  get: mockCollectionGet,
};
mockCollectionWhere.mockReturnValue(mockCollectionRef);

const mockCollectionFn = jest.fn().mockReturnValue(mockCollectionRef);

jest.mock("../admin.js", () => ({
  db: {
    doc: mockDocFn,
    collection: mockCollectionFn,
  },
  storage: {
    bucket: jest.fn().mockReturnValue({
      file: jest.fn().mockReturnValue({
        download: jest.fn().mockResolvedValue([Buffer.from("fake-image-data")]),
      }),
    }),
  },
}));

jest.mock("firebase-admin/firestore", () => ({
  FieldValue: {
    increment: mockIncrement,
    serverTimestamp: jest.fn().mockReturnValue({_serverTimestamp: true}),
  },
  Timestamp: {
    fromDate: jest.fn().mockImplementation((d: Date) => ({
      toDate: () => d,
      toMillis: () => d.getTime(),
    })),
    now: jest
      .fn()
      .mockReturnValue({toDate: () => new Date(), toMillis: () => Date.now()}),
  },
}));

jest.mock("ngeohash", () => ({
  encode: jest.fn().mockReturnValue("w3gv2c"),
  neighbors: jest
    .fn()
    .mockReturnValue([
      "w3gv2b",
      "w3gv25",
      "w3gv26",
      "w3gv27",
      "w3gv28",
      "w3gv29",
      "w3gv24",
      "w3gv23",
    ]),
  decode: jest.fn().mockReturnValue({latitude: 13.75, longitude: 100.5}),
}));

jest.mock("exifr", () => ({
  parse: jest.fn().mockResolvedValue(null), // no EXIF by default
}));

import {evaluateReportTrust} from "../evaluateReportTrust.js";
import * as exifr from "exifr";

const MOCK_REPORT_ID = "r1";
const MOCK_LOCATION = {latitude: 13.7563, longitude: 100.5018};
const MOCK_CREATED_AT = {
  toDate: () => new Date("2026-01-01T12:00:00Z"),
  toMillis: () => new Date("2026-01-01T12:00:00Z").getTime(),
};

function makeEvent(overrides: Record<string, unknown> = {}) {
  return {
    params: {reportId: MOCK_REPORT_ID},
    data: {
      data: () => ({
        userId: "u1",
        location: MOCK_LOCATION,
        geohash: "w3gv2c9b",
        category: "alert",
        mediaUrls: [],
        status: "pending",
        confirmCount: 0,
        disputeCount: 0,
        systemConfirms: 0,
        systemDisputes: 0,
        isDisputed: false,
        exifStripped: false,
        createdAt: MOCK_CREATED_AT,
        description: "Test report",
        ...overrides,
      }),
    },
  };
}

describe("evaluateReportTrust — exported shape", () => {
  test("is defined", () => {
    expect(evaluateReportTrust).toBeDefined();
  });

  test('is a Cloud Function (typeof "function" — Firebase v2 CloudFunction is callable)', () => {
    expect(typeof evaluateReportTrust).toBe("function");
  });
});

describe("evaluateReportTrust — EXIF heuristic (heuristic 1)", () => {
  beforeEach(() => jest.clearAllMocks());

  test("adds +3 systemConfirms when EXIF GPS matches fuzzed location within 5 km", async () => {
    (exifr.parse as jest.Mock).mockResolvedValueOnce({
      latitude: 13.7563, // same as report location → 0 km distance
      longitude: 100.5018,
      DateTimeOriginal: new Date("2026-01-01T11:50:00Z"), // 10 min before createdAt
    });

    const event = makeEvent({mediaUrls: ["reports/u1/r1/photo.jpg"]});
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    expect(mockUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        systemConfirms: expect.anything(),
      }),
    );
    // Verify the increment was called with +3
    expect(mockIncrement).toHaveBeenCalledWith(3);
  });

  test("does NOT add systemConfirms when EXIF GPS is far from report location", async () => {
    (exifr.parse as jest.Mock).mockResolvedValueOnce({
      latitude: 35.6762, // Tokyo — far from Bangkok
      longitude: 139.6503,
      DateTimeOriginal: new Date("2026-01-01T12:00:00Z"),
    });

    const event = makeEvent({mediaUrls: ["reports/u1/r1/photo.jpg"]});
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    expect(mockIncrement).not.toHaveBeenCalledWith(3);
  });

  test("skips EXIF check when exifStripped is true", async () => {
    const event = makeEvent({
      exifStripped: true,
      mediaUrls: ["reports/u1/r1/photo.jpg"],
    });
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    // exifr.parse should not have been called
    expect(exifr.parse).not.toHaveBeenCalled();
  });

  test("skips EXIF check when mediaUrls is empty", async () => {
    const event = makeEvent({mediaUrls: []});
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    expect(exifr.parse).not.toHaveBeenCalled();
  });

  test("does NOT add systemConfirms when EXIF timestamp differs by more than 60 minutes", async () => {
    (exifr.parse as jest.Mock).mockResolvedValueOnce({
      latitude: 13.7563, // same location
      longitude: 100.5018,
      DateTimeOriginal: new Date("2026-01-01T09:00:00Z"), // 3 hours before — too old
    });

    const event = makeEvent({mediaUrls: ["reports/u1/r1/photo.jpg"]});
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    expect(mockIncrement).not.toHaveBeenCalledWith(3);
  });
});

describe("evaluateReportTrust — wire news heuristic (heuristic 2)", () => {
  beforeEach(() => jest.clearAllMocks());

  test("adds +2 systemConfirms when a matching wire article exists in the same region", async () => {
    const mockArticleDoc = {
      data: () => ({
        title: "Flooding alert in Bangkok area",
        body: "Heavy rain triggers flooding alert",
        publishedAt: {toMillis: () => Date.now()},
        geohash5: "w3gv2",
      }),
    };
    mockCollectionGet.mockResolvedValueOnce({
      empty: false,
      docs: [mockArticleDoc],
    });

    const event = makeEvent({category: "alert"});
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    expect(mockIncrement).toHaveBeenCalledWith(2);
  });

  test("does NOT add systemConfirms when wire_news query returns empty", async () => {
    mockCollectionGet.mockResolvedValueOnce({empty: true, docs: []});

    const event = makeEvent({category: "alert"});
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    expect(mockIncrement).not.toHaveBeenCalledWith(2);
  });
});

describe("evaluateReportTrust — flash mob heuristic (heuristic 3)", () => {
  beforeEach(() => jest.clearAllMocks());

  test("adds +2 systemConfirms to all cluster reports when 4+ distinct UIDs in same geohash6 cell", async () => {
    const clusterDocs = [
      {
        id: "r2",
        ref: {update: jest.fn()},
        data: () => ({userId: "u2", category: "alert"}),
      },
      {
        id: "r3",
        ref: {update: jest.fn()},
        data: () => ({userId: "u3", category: "alert"}),
      },
      {
        id: "r4",
        ref: {update: jest.fn()},
        data: () => ({userId: "u4", category: "alert"}),
      },
    ];
    // First wire_news call returns empty, second reports call returns cluster
    mockCollectionGet
      .mockResolvedValueOnce({empty: true, docs: []}) // wire_news
      .mockResolvedValueOnce({empty: false, docs: clusterDocs}); // reports cluster

    const event = makeEvent({category: "alert"});
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    // The current report and each cluster doc should get +2
    expect(mockIncrement).toHaveBeenCalledWith(2);
  });

  test("does NOT add systemConfirms when fewer than 4 distinct UIDs in cluster", async () => {
    // Only 2 other reports in cluster → 3 distinct UIDs total (including current) → below threshold
    const clusterDocs = [
      {
        id: "r2",
        ref: {update: jest.fn()},
        data: () => ({userId: "u2", category: "alert"}),
      },
      {
        id: "r3",
        ref: {update: jest.fn()},
        data: () => ({userId: "u2", category: "alert"}),
      }, // same UID — doesn't count
    ];
    mockCollectionGet
      .mockResolvedValueOnce({empty: true, docs: []})
      .mockResolvedValueOnce({empty: false, docs: clusterDocs});

    const event = makeEvent({category: "alert"});
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    expect(mockIncrement).not.toHaveBeenCalledWith(2);
  });
});

describe("evaluateReportTrust — impossible travel heuristic (heuristic 4)", () => {
  beforeEach(() => jest.clearAllMocks());

  test("adds +5 systemDisputes when previous report implies impossible speed", async () => {
    // Previous report was in Tokyo 30 minutes ago — Bangkok→Tokyo in 30 min is impossible
    const prevCreatedAt = new Date("2026-01-01T11:30:00Z"); // 30 min before MOCK_CREATED_AT
    const prevDoc = {
      id: "prev-report",
      data: () => ({
        userId: "u1",
        location: {latitude: 35.6762, longitude: 139.6503}, // Tokyo
        createdAt: {toMillis: () => prevCreatedAt.getTime()},
      }),
    };
    mockCollectionGet
      .mockResolvedValueOnce({empty: true, docs: []}) // wire_news
      .mockResolvedValueOnce({empty: false, docs: []}) // flash mob
      .mockResolvedValueOnce({empty: false, docs: [prevDoc]}); // impossible travel

    const event = makeEvent();
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    expect(mockIncrement).toHaveBeenCalledWith(5);
  });

  test("does NOT add systemDisputes when previous report is nearby (plausible travel)", async () => {
    // Previous report 500m away 30 minutes ago — trivially reachable
    const prevCreatedAt = new Date("2026-01-01T11:30:00Z");
    const prevDoc = {
      id: "prev-report",
      data: () => ({
        userId: "u1",
        location: {latitude: 13.7568, longitude: 100.5023}, // ~90m from MOCK_LOCATION
        createdAt: {toMillis: () => prevCreatedAt.getTime()},
      }),
    };
    mockCollectionGet
      .mockResolvedValueOnce({empty: true, docs: []})
      .mockResolvedValueOnce({empty: false, docs: []})
      .mockResolvedValueOnce({empty: false, docs: [prevDoc]});

    const event = makeEvent();
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    expect(mockIncrement).not.toHaveBeenCalledWith(5);
  });

  test("skips self when userId matches but doc ID matches reportId", async () => {
    // The current report appears in the query result — should be skipped
    const selfDoc = {
      id: MOCK_REPORT_ID, // same as the triggering report
      data: () => ({
        userId: "u1",
        location: MOCK_LOCATION,
        createdAt: MOCK_CREATED_AT,
      }),
    };
    mockCollectionGet
      .mockResolvedValueOnce({empty: true, docs: []})
      .mockResolvedValueOnce({empty: false, docs: []})
      .mockResolvedValueOnce({empty: false, docs: [selfDoc]});

    const event = makeEvent();
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await handler(event);

    expect(mockIncrement).not.toHaveBeenCalledWith(5);
  });
});

describe("evaluateReportTrust — resilience", () => {
  beforeEach(() => jest.clearAllMocks());

  test("completes without throwing even when all Firestore queries return empty", async () => {
    mockCollectionGet.mockResolvedValue({empty: true, docs: []});

    const event = makeEvent();
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await expect(handler(event)).resolves.not.toThrow();
  });

  test("completes without throwing even when exifr.parse throws", async () => {
    (exifr.parse as jest.Mock).mockRejectedValueOnce(new Error("Corrupt EXIF"));
    mockCollectionGet.mockResolvedValue({empty: true, docs: []});

    const event = makeEvent({mediaUrls: ["reports/u1/r1/photo.jpg"]});
    const handler = (
      evaluateReportTrust as unknown as {
        run: (...args: unknown[]) => Promise<unknown>;
      }
    ).run;
    await expect(handler(event)).resolves.not.toThrow();
  });
});
