/// Pure Dart — zero Flutter/Firebase imports.
class AlertSubscription {
  final String id;
  final String userId;
  final String locationLabel;
  final double lat;
  final double lng;
  final double radiusKm;
  final List<String> categories;
  final DateTime createdAt;

  const AlertSubscription({
    required this.id,
    required this.userId,
    required this.locationLabel,
    required this.lat,
    required this.lng,
    required this.radiusKm,
    required this.categories,
    required this.createdAt,
  });
}
