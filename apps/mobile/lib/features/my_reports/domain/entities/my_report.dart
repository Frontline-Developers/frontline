class MyReport {
  final String id;
  final String title;
  final String body;
  final String snippet;
  final String category;
  final String location;
  final List<String> photos;
  final String status;
  final int confirms;
  final int flags;
  final int views;
  final String token;
  final DateTime submittedAt;
  final int commentCount;
  // Discussion preview — latest comment shown in detail screen
  final String? previewCommentToken;
  final String? previewCommentContent;
  final DateTime? previewCommentAt;

  const MyReport({
    required this.id,
    required this.title,
    required this.body,
    String? snippet,
    required this.category,
    required this.location,
    this.photos = const [],
    required this.status,
    this.confirms = 0,
    this.flags = 0,
    this.views = 0,
    required this.token,
    required this.submittedAt,
    this.commentCount = 0,
    this.previewCommentToken,
    this.previewCommentContent,
    this.previewCommentAt,
  }) : snippet = snippet ?? body;

  String? get photo => photos.isNotEmpty ? photos.first : null;

  String get tokenPreview =>
      token.length > 9 ? '${token.substring(0, 9)} …' : token;
}
