import 'dart:math';

// Randomize lat/lng within ±3km radius using uniform disk sampling.
// 1° lat ≈ 111km | 1° lng ≈ 111km * cos(lat_rad)
(double lat, double lng) fuzzLocation(double lat, double lng) {
  final rng = Random.secure();
  const radiusKm = 3.0;
  final u = rng.nextDouble();
  final v = rng.nextDouble();
  final w = radiusKm / 111.0 * sqrt(u);
  final t = 2 * pi * v;
  return (lat + w * cos(t), lng + w * sin(t) / cos(lat * pi / 180));
}
