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
      source: (json['source'] as String) == 'wire'
          ? NewsSource.wire
          : NewsSource.citizen,
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
