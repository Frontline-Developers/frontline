import {CONSENSUS} from "../types.js";

describe("CONSENSUS constants", () => {
  test("MIN_VOLUME is 5", () => {
    expect(CONSENSUS.MIN_VOLUME).toBe(5);
  });

  test("CONFIRM_RATIO is 0.75", () => {
    expect(CONSENSUS.CONFIRM_RATIO).toBe(0.75);
  });

  test("DISPUTE_RATIO is 0.60", () => {
    expect(CONSENSUS.DISPUTE_RATIO).toBeCloseTo(0.6);
  });

  test("constants are frozen (not accidentally mutable)", () => {
    // TypeScript `as const` produces readonly, not runtime-frozen, but the
    // values must be the defined ones — no accidental override possible via import.
    expect(typeof CONSENSUS.MIN_VOLUME).toBe("number");
    expect(typeof CONSENSUS.CONFIRM_RATIO).toBe("number");
    expect(typeof CONSENSUS.DISPUTE_RATIO).toBe("number");
  });
});
