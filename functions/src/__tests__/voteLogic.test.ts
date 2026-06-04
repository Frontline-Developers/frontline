import {calculateConsensusStatus} from "../voteHelper.js";

// calculateConsensusStatus is a pure function that encapsulates the threshold math.
// It must be exported from voteHelper.ts for testability.

function status(
  confirmCount: number,
  disputeCount: number,
  systemConfirms = 0,
  systemDisputes = 0,
  currentStatus = "pending",
) {
  return calculateConsensusStatus({
    confirmCount,
    disputeCount,
    systemConfirms,
    systemDisputes,
    currentStatus,
  });
}

describe("calculateConsensusStatus — quorum gate", () => {
  test("stays pending when V is 0", () => {
    expect(status(0, 0).status).toBe("pending");
  });

  test("stays pending when V = 4 (below MIN_VOLUME)", () => {
    // C_eff=4, D_eff=0, V=4
    expect(status(4, 0).status).toBe("pending");
  });

  test("can transition when V = 5 (at MIN_VOLUME)", () => {
    // C_eff=4, D_eff=1, V=5, R=0.8 → confirmed
    expect(status(4, 1).status).toBe("confirmed");
  });
});

describe("calculateConsensusStatus — confirmed threshold", () => {
  test("becomes confirmed when R = 0.75 exactly (5 votes: 15 C + 5 D → needs renorm)", () => {
    // C_eff=15, D_eff=5, V=20, R=0.75 → confirmed
    expect(status(15, 5).status).toBe("confirmed");
  });

  test("becomes confirmed when R > 0.75", () => {
    // C_eff=5, D_eff=0, V=5, R=1.0
    expect(status(5, 0).status).toBe("confirmed");
  });

  test("does NOT confirm when R < 0.75", () => {
    // C_eff=3, D_eff=2, V=5, R=0.6
    const r = status(3, 2);
    expect(r.status).not.toBe("confirmed");
  });
});

describe("calculateConsensusStatus — disputed threshold", () => {
  test("becomes disputed when D_eff/V = 0.60 exactly (3 of 5 disputes)", () => {
    // C_eff=2, D_eff=3, V=5, DR=0.6
    expect(status(2, 3).status).toBe("disputed");
  });

  test("becomes disputed when D_eff/V > 0.60", () => {
    // C_eff=1, D_eff=4, V=5, DR=0.8
    expect(status(1, 4).status).toBe("disputed");
  });

  test("does NOT dispute when DR < 0.60", () => {
    // C_eff=3, D_eff=2, V=5, DR=0.4
    const r = status(3, 2);
    expect(r.status).not.toBe("disputed");
  });
});

describe("calculateConsensusStatus — system votes", () => {
  test("systemConfirms add to C_eff", () => {
    // confirmCount=1, systemConfirms=3 → C_eff=4
    const r = status(1, 1, 3, 0);
    expect(r.cEff).toBe(4);
    expect(r.dEff).toBe(1);
  });

  test("systemDisputes add to D_eff", () => {
    // disputeCount=0, systemDisputes=5 → D_eff=5
    const r = status(2, 0, 0, 5);
    expect(r.dEff).toBe(5);
  });

  test("systemConfirms can push a report over the confirmed threshold", () => {
    // confirmCount=1, systemConfirms=3, disputeCount=1 → C_eff=4, D_eff=1, V=5, R=0.8
    expect(status(1, 1, 3, 0).status).toBe("confirmed");
  });

  test("systemDisputes can push a report over the disputed threshold", () => {
    // confirmCount=2, systemDisputes=5 → C_eff=2, D_eff=5, V=7, DR≈0.71
    expect(status(2, 0, 0, 5).status).toBe("disputed");
  });

  test("impossible-travel +5 systemDisputes on a fresh report marks it disputed once human votes arrive", () => {
    // After 1 human confirm + 5 systemDisputes: C_eff=1, D_eff=5, V=6, DR≈0.83
    expect(status(1, 0, 0, 5).status).toBe("disputed");
  });
});

describe("calculateConsensusStatus — withdrawn guard", () => {
  test("never changes status of a withdrawn report even with confirming votes", () => {
    // 5 confirms should confirm a normal report — but withdrawn stays withdrawn
    const r = status(5, 0, 0, 0, "withdrawn");
    expect(r.status).toBe("withdrawn");
  });

  test("never changes status of a withdrawn report even with disputing votes", () => {
    const r = status(0, 5, 0, 0, "withdrawn");
    expect(r.status).toBe("withdrawn");
  });
});

describe("calculateConsensusStatus — return shape", () => {
  test("returns cEff, dEff, V, R, and status", () => {
    const r = status(3, 2);
    expect(typeof r.cEff).toBe("number");
    expect(typeof r.dEff).toBe("number");
    expect(typeof r.V).toBe("number");
    expect(typeof r.R).toBe("number");
    expect(typeof r.status).toBe("string");
  });

  test("V equals cEff + dEff", () => {
    const r = status(3, 2);
    expect(r.V).toBe(r.cEff + r.dEff);
  });

  test("R equals cEff / V when V > 0", () => {
    const r = status(4, 1);
    expect(r.R).toBeCloseTo(r.cEff / r.V);
  });

  test("R is 0 when V is 0", () => {
    const r = status(0, 0);
    expect(r.R).toBe(0);
    expect(Number.isNaN(r.R)).toBe(false);
  });
});
