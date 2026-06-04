// Mirror of confirmReport.test.ts — tests the dispute path specifically.
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

import {disputeReport} from "../disputeReport.js";

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

describe("disputeReport — exported shape", () => {
  test("is defined", () => {
    expect(disputeReport).toBeDefined();
  });

  test('is a function (Firebase v2 callable functions are typeof "function")', () => {
    expect(typeof disputeReport).toBe("function");
  });
});

describe("disputeReport — auth guard", () => {
  test("throws unauthenticated when request has no auth", async () => {
    const handler = (
      disputeReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    await expect(
      handler({data: {reportId: "r1"}, auth: undefined}),
    ).rejects.toMatchObject({code: "unauthenticated"});
  });
});

describe("disputeReport — input validation", () => {
  test("throws invalid-argument when reportId is missing", async () => {
    const handler = (
      disputeReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    await expect(handler({data: {}, auth: {uid: "u1"}})).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });
});

describe("disputeReport — duplicate vote prevention", () => {
  test("throws already-exists when user already voted", async () => {
    mockDocFn.mockImplementation((path: string) => ({path}));
    mockRunTransaction.mockImplementation(
      async (fn: (tx: unknown) => Promise<unknown>) => {
        const interactionSnap = {exists: true};
        const reportSnap = makeReportSnap();
        mockGet
          .mockResolvedValueOnce(interactionSnap)
          .mockResolvedValueOnce(reportSnap);
        return fn(mockTx);
      },
    );

    const handler = (
      disputeReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    await expect(
      handler({data: {reportId: "r1"}, auth: {uid: "u1"}}),
    ).rejects.toMatchObject({code: "already-exists"});
  });
});

describe("disputeReport — happy path", () => {
  beforeEach(() => {
    // resetAllMocks clears mockResolvedValueOnce queues; clearAllMocks does not.
    jest.resetAllMocks();
    mockDocFn.mockImplementation((path: string) => ({path}));
  });

  test("resolves with status, totalEffectiveVolume, and confidenceRatio", async () => {
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
      disputeReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    const result = await handler({data: {reportId: "r1"}, auth: {uid: "u1"}});
    expect(result).toHaveProperty("status");
    expect(result).toHaveProperty("totalEffectiveVolume");
    expect(result).toHaveProperty("confidenceRatio");
  });

  test("returns disputed status when D_eff/V >= 0.60 after vote", async () => {
    mockRunTransaction.mockImplementation(
      async (fn: (tx: unknown) => Promise<unknown>) => {
        const interactionSnap = {exists: false};
        // disputeCount=2 → after vote D_eff=3, C_eff=2, V=5, DR=0.6 → disputed
        const reportSnap = makeReportSnap({
          confirmCount: 2,
          disputeCount: 2,
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
      disputeReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    const result = await handler({data: {reportId: "r1"}, auth: {uid: "u1"}});
    expect(result.status).toBe("disputed");
  });

  test('writes an interaction document with type "dispute"', async () => {
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
      disputeReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    await handler({data: {reportId: "r1"}, auth: {uid: "u1"}});

    expect(mockSet).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({type: "dispute", token: expect.any(String)}),
    );
  });

  test("does not change status of a withdrawn report", async () => {
    mockRunTransaction.mockImplementation(
      async (fn: (tx: unknown) => Promise<unknown>) => {
        const interactionSnap = {exists: false};
        // 5 dispute votes on a withdrawn report should not change its status
        const reportSnap = makeReportSnap({
          status: "withdrawn",
          confirmCount: 0,
          disputeCount: 4,
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
      disputeReport as unknown as {
        run: (...args: unknown[]) => Promise<Record<string, unknown>>;
      }
    ).run;
    const result = await handler({data: {reportId: "r1"}, auth: {uid: "u1"}});
    expect(result.status).toBe("withdrawn");
  });
});
