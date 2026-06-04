import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/news_item_model.dart';
import '../../domain/entities/news_item.dart';

abstract class FeedDatasource {
  Stream<List<NewsItem>> watchFeed();
}

class FeedDatasourceImpl implements FeedDatasource {
  @override
  Stream<List<NewsItem>> watchFeed() {
    List<NewsItem> reports = [];
    List<NewsItem> wire = [];
    StreamSubscription? s1, s2;

    late final StreamController<List<NewsItem>> ctrl;

    void emit() {
      if (ctrl.isClosed) return;
      final merged = [...reports, ...wire]
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      ctrl.add(merged);
    }

    ctrl = StreamController<List<NewsItem>>(
      // Firestore listeners only start when someone actually subscribes.
      onListen: () {
        s1 = FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots()
            .map(
              (snap) => snap.docs
                  .where((d) => (d.data()['status'] as String?) != 'rejected')
                  .map(ReportFeedModel.fromFirestore)
                  .map((m) => m.toEntity())
                  .toList(),
            )
            .listen((items) {
              reports = items;
              emit();
            }, onError: ctrl.addError);

        s2 = FirebaseFirestore.instance
            .collection('wire_news')
            .orderBy('publishedAt', descending: true)
            .limit(100)
            .snapshots()
            .map(
              (snap) => _deduplicateWire(
                snap.docs
                    .map(
                      (d) => NewsItemModel.fromJson(d.id, d.data()).toEntity(),
                    )
                    .toList(),
              ),
            )
            .listen((items) {
              wire = items;
              emit();
            }, onError: ctrl.addError);
      },
      onCancel: () {
        s1?.cancel();
        s2?.cancel();
      },
    );

    return ctrl.stream;
  }
}

// Client-side safety net: deduplicate wire items by normalized title and
// by imageUrl. Handles anything that slips through server-side dedup (e.g.
// same story from different GDELT fetch windows, stale seed data).
// Input is assumed to be sorted newest-first; the first occurrence is kept.
List<NewsItem> _deduplicateWire(List<NewsItem> items) {
  final seenTitles = <String>{};
  final seenImages = <String>{};
  final result = <NewsItem>[];
  for (final item in items) {
    final titleKey = item.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (!seenTitles.add(titleKey)) continue;
    final img = item.imageUrl;
    if (img != null && !seenImages.add(img)) continue;
    result.add(item);
  }
  return result;
}
