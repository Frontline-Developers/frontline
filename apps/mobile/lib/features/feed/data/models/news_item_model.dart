import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/news_item.dart';

class NewsItemModel {
  final String id;
  final String title;
  final String? body;
  final String? url;
  final NewsSource source;
  final DateTime publishedAt;

  const NewsItemModel({
    required this.id,
    required this.title,
    this.body,
    this.url,
    required this.source,
    required this.publishedAt,
  });

  factory NewsItemModel.fromJson(String id, Map<String, dynamic> json) {
    final ts = json['publishedAt'] as Timestamp;
    return NewsItemModel(
      id: id,
      title: json['title'] as String,
      body: json['body'] as String?,
      url: json['url'] as String?,
      source: NewsSource.wire,
      publishedAt: ts.toDate(),
    );
  }

  NewsItem toEntity() => NewsItem(
    id: id,
    title: title,
    body: body,
    url: url,
    source: source,
    publishedAt: publishedAt,
  );
}

class ReportFeedModel {
  final String id;
  final String title;
  final String? body;
  final String category;
  final ItemStatus status;
  final List<String> mediaUrls;
  final int confirmCount;
  final int disputeCount;
  final DateTime publishedAt;

  const ReportFeedModel({
    required this.id,
    required this.title,
    this.body,
    required this.category,
    required this.status,
    required this.mediaUrls,
    required this.confirmCount,
    required this.disputeCount,
    required this.publishedAt,
  });

  factory ReportFeedModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final description = (data['description'] as String? ?? '').trim();
    final title = _splitTitle(description);
    final body = description.length > title.length
        ? description.substring(title.length).trim()
        : null;

    final ts = data['createdAt'];
    final publishedAt = ts is Timestamp ? ts.toDate() : DateTime.now();

    final rawStatus = data['status'] as String? ?? 'pending';
    final status = switch (rawStatus) {
      'reviewed' => ItemStatus.verified,
      'rejected' => ItemStatus.disputed,
      _ => ItemStatus.pending,
    };

    return ReportFeedModel(
      id: doc.id,
      title: title,
      body: body?.isEmpty == true ? null : body,
      category: data['category'] as String? ?? 'other',
      status: status,
      mediaUrls: List<String>.from(data['mediaUrls'] as List? ?? []),
      confirmCount: (data['confirmCount'] as num?)?.toInt() ?? 0,
      disputeCount: (data['disputeCount'] as num?)?.toInt() ?? 0,
      publishedAt: publishedAt,
    );
  }

  NewsItem toEntity() => NewsItem(
    id: id,
    title: title,
    body: body,
    source: NewsSource.citizen,
    publishedAt: publishedAt,
    category: category,
    status: status,
    mediaUrls: mediaUrls,
    confirmCount: confirmCount,
    disputeCount: disputeCount,
  );

  // Split description at a word boundary ≤90 chars for use as a card title.
  static String _splitTitle(String text) {
    if (text.length <= 90) return text;
    final cut = text.lastIndexOf(' ', 90);
    return cut > 0 ? text.substring(0, cut) : text.substring(0, 90);
  }
}
