class Report {
  final String? id;
  final String category;
  final String description;
  final double lat;
  final double lng;
  final List<String> mediaUrls;
  final DateTime? createdAt;

  const Report({
    this.id,
    required this.category,
    required this.description,
    required this.lat,
    required this.lng,
    this.mediaUrls = const [],
    this.createdAt,
  });
}
