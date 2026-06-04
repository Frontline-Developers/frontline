import {haversineKm, speedKmh} from "../geo.js";

describe("haversineKm", () => {
  test("returns 0 for identical coordinates", () => {
    expect(haversineKm(48.8566, 2.3522, 48.8566, 2.3522)).toBe(0);
  });

  test("returns ~111 km per degree of latitude", () => {
    const km = haversineKm(0, 0, 1, 0);
    expect(km).toBeGreaterThan(110);
    expect(km).toBeLessThan(113);
  });

  test("returns ~3940 km from New York to Los Angeles", () => {
    const km = haversineKm(40.7128, -74.006, 34.0522, -118.2437);
    expect(km).toBeGreaterThan(3900);
    expect(km).toBeLessThan(4000);
  });

  test("is symmetric — distance A→B equals B→A", () => {
    const ab = haversineKm(13.7563, 100.5018, 1.3521, 103.8198);
    const ba = haversineKm(1.3521, 103.8198, 13.7563, 100.5018);
    expect(ab).toBeCloseTo(ba, 5);
  });

  test("handles antipodal points (~20015 km)", () => {
    const km = haversineKm(0, 0, 0, 180);
    expect(km).toBeGreaterThan(20000);
    expect(km).toBeLessThan(20030);
  });
});

describe("speedKmh", () => {
  test("returns correct speed for 100 km in 1 hour", () => {
    expect(speedKmh(100, 3_600_000)).toBe(100);
  });

  test("returns correct speed for 900 km in 1 hour", () => {
    expect(speedKmh(900, 3_600_000)).toBe(900);
  });

  test("returns Infinity for zero elapsed time", () => {
    expect(speedKmh(100, 0)).toBe(Infinity);
  });

  test("returns Infinity for negative elapsed time", () => {
    expect(speedKmh(100, -1000)).toBe(Infinity);
  });

  test("returns 0 for zero distance with positive time", () => {
    expect(speedKmh(0, 3_600_000)).toBe(0);
  });

  test("returns 0 for zero distance and zero time", () => {
    // 0/0 edge case — implementation must not return NaN
    const result = speedKmh(0, 0);
    expect(result === 0 || result === Infinity).toBe(true);
    expect(Number.isNaN(result)).toBe(false);
  });
});
