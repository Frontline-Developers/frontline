class MapReport {
  final String id;
  final double lat;
  final double lng;
  final String category;
  final String title;
  final DateTime createdAt;

  const MapReport({
    required this.id,
    required this.lat,
    required this.lng,
    required this.category,
    required this.title,
    required this.createdAt,
  });
}
