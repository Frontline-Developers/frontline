// Mock firebase-admin BEFORE any imports that transitively use it.
const mockGet = jest.fn();
const mockSet = jest.fn();
const mockUpdate = jest.fn();
const mockTx = {get: mockGet, set: mockSet, update: mockUpdate};
const mockRunTransaction = jest.fn();
const mockDocFn = jest.fn();

jest.mock("../admin.js", () => ({
  db: {runTransaction: mockRunTransaction, doc: mockDocFn},
  storage: {},
}));

import {confirmReport} from "../confirmReport.js";

// Helper: build a minimal Report-shaped Firestore snapshot
function makeReportSnap(overrides: Record<string, unknown> = {}) {
  return {
    exists: true,
    data: () => ({
      userId: "report-owner",
      status: "pending",
      confirmCount: 0,
      disputeCount: 0,
      systemConfirms: 0,
      systemDisputes: 0,
      ...overrides,
    }),
  };
}

describe("confirmReport — exported shape", () => {
  test("is defined", () => {
    expect(confirmReport).toBeDefined();
  });

  test('is a function (Firebase v2 callable functions are typeof "function")', () => {
    expect(typeof confirmReport).toBe("function");
  });
});

describe("confirmReport — auth guard", () => {
  test("throws unauthenticated when request has no auth", async () => {
    // Simulate calling the internal handler with no auth context.
    // The callable handler is exposed via .run() in firebase-functions v2.
    const handler = (
      confirmReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    await expect(
      handler({data: {reportId: "r1"}, auth: undefined}),
    ).rejects.toMatchObject({code: "unauthenticated"});
  });
});

describe("confirmReport — input validation", () => {
  test("throws invalid-argument when reportId is missing", async () => {
    const handler = (
      confirmReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    await expect(handler({data: {}, auth: {uid: "u1"}})).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("throws invalid-argument when reportId is empty string", async () => {
    const handler = (
      confirmReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    await expect(
      handler({data: {reportId: ""}, auth: {uid: "u1"}}),
    ).rejects.toMatchObject({code: "invalid-argument"});
  });

  test("throws invalid-argument when reportId is not a string", async () => {
    const handler = (
      confirmReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    await expect(
      handler({data: {reportId: 42}, auth: {uid: "u1"}}),
    ).rejects.toMatchObject({code: "invalid-argument"});
  });
});

describe("confirmReport — duplicate vote prevention", () => {
  test("throws already-exists when interaction doc already exists", async () => {
    mockDocFn.mockImplementation((path: string) => ({path}));
    mockRunTransaction.mockImplementation(
      async (fn: (tx: unknown) => Promise<unknown>) => {
        const interactionSnap = {exists: true}; // user already voted
        const reportSnap = makeReportSnap();
        mockGet
          .mockResolvedValueOnce(interactionSnap)
          .mockResolvedValueOnce(reportSnap);
        return fn(mockTx);
      },
    );

    const handler = (
      confirmReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    await expect(
      handler({data: {reportId: "r1"}, auth: {uid: "u1"}}),
    ).rejects.toMatchObject({code: "already-exists"});
  });
});

describe("confirmReport — happy path", () => {
  beforeEach(() => {
    // resetAllMocks clears mockResolvedValueOnce queues; clearAllMocks does not.
    jest.resetAllMocks();
    mockDocFn.mockImplementation((path: string) => ({path}));
  });

  test("resolves successfully for a fresh vote", async () => {
    mockRunTransaction.mockImplementation(
      async (fn: (tx: unknown) => Promise<unknown>) => {
        const interactionSnap = {exists: false}; // no prior vote
        const reportSnap = makeReportSnap({confirmCount: 0});
        mockGet
          .mockResolvedValueOnce(interactionSnap)
          .mockResolvedValueOnce(reportSnap);
        mockSet.mockResolvedValue(undefined);
        mockUpdate.mockResolvedValue(undefined);
        return fn(mockTx);
      },
    );

    const handler = (
      confirmReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    const result = await handler({data: {reportId: "r1"}, auth: {uid: "u1"}});
    expect(result).toHaveProperty("status");
    expect(result).toHaveProperty("totalEffectiveVolume");
    expect(result).toHaveProperty("confidenceRatio");
  });

  test("returns pending status when V < 5 after vote", async () => {
    mockRunTransaction.mockImplementation(
      async (fn: (tx: unknown) => Promise<unknown>) => {
        const interactionSnap = {exists: false};
        // confirmCount=1 → after vote C_eff=2, D_eff=0, V=2 < 5 → pending
        const reportSnap = makeReportSnap({
          confirmCount: 1,
          disputeCount: 0,
          systemConfirms: 0,
          systemDisputes: 0,
        });
        mockGet
          .mockResolvedValueOnce(interactionSnap)
          .mockResolvedValueOnce(reportSnap);
        mockSet.mockResolvedValue(undefined);
        mockUpdate.mockResolvedValue(undefined);
        return fn(mockTx);
      },
    );

    const handler = (
      confirmReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    const result = await handler({data: {reportId: "r1"}, auth: {uid: "u1"}});
    expect(result.status).toBe("pending");
  });

  test("returns confirmed status when V >= 5 and R >= 0.75", async () => {
    mockRunTransaction.mockImplementation(
      async (fn: (tx: unknown) => Promise<unknown>) => {
        const interactionSnap = {exists: false};
        // confirmCount=3, systemConfirms=0 → after vote C_eff=4, D_eff=1, V=5, R=0.8 → confirmed
        const reportSnap = makeReportSnap({
          confirmCount: 3,
          disputeCount: 1,
          systemConfirms: 0,
          systemDisputes: 0,
        });
        mockGet
          .mockResolvedValueOnce(interactionSnap)
          .mockResolvedValueOnce(reportSnap);
        mockSet.mockResolvedValue(undefined);
        mockUpdate.mockResolvedValue(undefined);
        return fn(mockTx);
      },
    );

    const handler = (
      confirmReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    const result = await handler({data: {reportId: "r1"}, auth: {uid: "u1"}});
    expect(result.status).toBe("confirmed");
  });

  test("writes an interaction document with a token", async () => {
    mockRunTransaction.mockImplementation(
      async (fn: (tx: unknown) => Promise<unknown>) => {
        const interactionSnap = {exists: false};
        const reportSnap = makeReportSnap();
        mockGet
          .mockResolvedValueOnce(interactionSnap)
          .mockResolvedValueOnce(reportSnap);
        mockSet.mockResolvedValue(undefined);
        mockUpdate.mockResolvedValue(undefined);
        return fn(mockTx);
      },
    );

    const handler = (
      confirmReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    await handler({data: {reportId: "r1"}, auth: {uid: "u1"}});

    expect(mockSet).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        type: "confirm",
        token: expect.any(String),
      }),
    );
  });
});
