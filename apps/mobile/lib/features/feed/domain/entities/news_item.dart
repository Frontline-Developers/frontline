enum NewsSource { citizen, wire }

enum ItemStatus { pending, verified, disputed }

class NewsItem {
  final String id;
  final String title;
  final String? body;
  final String? url;
  final NewsSource source;
  final DateTime publishedAt;
  final String? category;
  final ItemStatus? status;
  final List<String> mediaUrls;
  final int confirmCount;
  final int disputeCount;

  const NewsItem({
    required this.id,
    required this.title,
    this.body,
    this.url,
    required this.source,
    required this.publishedAt,
    this.category,
    this.status,
    this.mediaUrls = const [],
    this.confirmCount = 0,
    this.disputeCount = 0,
  });
}
