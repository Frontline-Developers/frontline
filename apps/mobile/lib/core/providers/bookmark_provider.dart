import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/feed/domain/entities/news_item.dart';

final bookmarkNotifierProvider =
    NotifierProvider<BookmarkNotifier, List<NewsItem>>(BookmarkNotifier.new);

class BookmarkNotifier extends Notifier<List<NewsItem>> {
  static const _key = 'bookmarked_items_v2';

  @override
  List<NewsItem> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    state = list.map(_fromJson).toList();
  }

  bool isBookmarked(String id) => state.any((item) => item.id == id);

  Future<void> toggle(NewsItem item) async {
    final next = List<NewsItem>.of(state);
    if (next.any((i) => i.id == item.id)) {
      next.removeWhere((i) => i.id == item.id);
    } else {
      next.insert(0, item);
    }
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next.map(_toJson).toList()));
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _toJson(NewsItem item) => {
    'id': item.id,
    'title': item.title,
    'body': item.body,
    'url': item.url,
    'source': item.source.name,
    'publishedAt': item.publishedAt.millisecondsSinceEpoch,
    'category': item.category,
    'status': item.status?.name,
    'mediaUrls': item.mediaUrls,
    'confirmCount': item.confirmCount,
    'disputeCount': item.disputeCount,
    'sourceName': item.sourceName,
    'imageUrl': item.imageUrl,
    'locations': item.locations,
    'themes': item.themes,
    'tone': item.tone,
  };

  static NewsItem _fromJson(Map<String, dynamic> j) => NewsItem(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String?,
    url: j['url'] as String?,
    source: NewsSource.values.firstWhere((s) => s.name == j['source']),
    publishedAt: DateTime.fromMillisecondsSinceEpoch(j['publishedAt'] as int),
    category: j['category'] as String?,
    status: j['status'] != null
        ? ItemStatus.values.firstWhere((s) => s.name == j['status'])
        : null,
    mediaUrls: (j['mediaUrls'] as List?)?.cast<String>() ?? [],
    confirmCount: (j['confirmCount'] as num?)?.toInt() ?? 0,
    disputeCount: (j['disputeCount'] as num?)?.toInt() ?? 0,
    sourceName: j['sourceName'] as String?,
    imageUrl: j['imageUrl'] as String?,
    locations: (j['locations'] as List?)?.cast<String>() ?? [],
    themes: (j['themes'] as List?)?.cast<String>() ?? [],
    tone: (j['tone'] as num?)?.toInt() ?? 0,
  );
}
