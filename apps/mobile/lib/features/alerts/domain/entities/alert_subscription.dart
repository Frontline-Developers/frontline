/// Thrown when saving an alert subscription fails for a known reason.
/// Carries a user-readable message so the presentation layer never needs
/// to inspect Firebase error codes directly.
class AlertSaveException implements Exception {
  final String message;
  const AlertSaveException(this.message);

  @override
  String toString() => message;
}

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
