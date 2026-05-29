enum NewsSource { citizen, wire }

class NewsItem {
  final String id;
  final String title;
  final String? body;
  final String? url;
  final NewsSource source;
  final DateTime publishedAt;

  const NewsItem({
    required this.id,
    required this.title,
    this.body,
    this.url,
    required this.source,
    required this.publishedAt,
  });
}
