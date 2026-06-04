import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../feed/data/models/news_item_model.dart';
import '../../../feed/domain/entities/news_item.dart';
import '../../domain/entities/event_cluster.dart';

abstract class CompareDatasource {
  Stream<List<EventCluster>> watchClusters();
  Future<NewsItem> fetchReport(String reportId);
  Future<List<NewsItem>> fetchWireNewsByLocations(List<String> locations);
  Future<List<NewsItem>> fetchWireNewsByCategory(String category);
  Future<List<NewsItem>> fetchRecentWireNews();
}

class CompareDatasourceImpl implements CompareDatasource {
  @override
  Stream<List<EventCluster>> watchClusters() {
    List<NewsItem> reports = [];
    List<NewsItem> wire = [];
    StreamSubscription? s1, s2;

    late final StreamController<List<EventCluster>> ctrl;

    void emit() {
      if (ctrl.isClosed) return;
      final all = [...reports, ...wire];
      ctrl.add(_cluster(all));
    }

    ctrl = StreamController<List<EventCluster>>(
      onListen: () {
        s1 = FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots()
            .map(
              (snap) => snap.docs
                  .where((d) => (d.data()['status'] as String?) != 'withdrawn')
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
            .limit(50)
            .snapshots()
            .map(
              (snap) => snap.docs
                  .map((d) => NewsItemModel.fromJson(d.id, d.data()).toEntity())
                  .toList(),
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

  @override
  Future<NewsItem> fetchReport(String reportId) async {
    final doc = await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .get();
    if (!doc.exists) throw Exception('Report not found');
    return ReportFeedModel.fromFirestore(doc).toEntity();
  }

  @override
  Future<List<NewsItem>> fetchWireNewsByLocations(
    List<String> locations,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection('wire_news')
        .where('locations', arrayContainsAny: locations)
        .orderBy('publishedAt', descending: true)
        .limit(10)
        .get();
    return snap.docs
        .map((d) => NewsItemModel.fromJson(d.id, d.data()).toEntity())
        .toList();
  }

  @override
  Future<List<NewsItem>> fetchWireNewsByCategory(String category) async {
    final snap = await FirebaseFirestore.instance
        .collection('wire_news')
        .where('themes', arrayContains: category)
        .orderBy('publishedAt', descending: true)
        .limit(10)
        .get();
    return snap.docs
        .map((d) => NewsItemModel.fromJson(d.id, d.data()).toEntity())
        .toList();
  }

  @override
  Future<List<NewsItem>> fetchRecentWireNews() async {
    final snap = await FirebaseFirestore.instance
        .collection('wire_news')
        .orderBy('publishedAt', descending: true)
        .limit(10)
        .get();
    return snap.docs
        .map((d) => NewsItemModel.fromJson(d.id, d.data()).toEntity())
        .toList();
  }

  static const _knownCategories = {
    'combat',
    'aid',
    'alert',
    'displaced',
    'infra',
  };

  static String _categoryForItem(NewsItem item) {
    if (item.category != null) return item.category!;
    for (final t in item.themes) {
      if (_knownCategories.contains(t)) return t;
    }
    return 'other';
  }

  static List<EventCluster> _cluster(List<NewsItem> items) {
    final Map<String, List<NewsItem>> buckets = {};

    for (final item in items) {
      final category = _categoryForItem(item);
      final utc = item.publishedAt.toUtc();
      final dateStr =
          '${utc.year}${utc.month.toString().padLeft(2, '0')}${utc.day.toString().padLeft(2, '0')}';
      final key = '${category}_$dateStr';
      buckets.putIfAbsent(key, () => []).add(item);
    }

    final clusters = <EventCluster>[];
    for (final entry in buckets.entries) {
      if (entry.value.length < 2) continue;

      final sorted = List<NewsItem>.from(entry.value)
        ..sort((a, b) => a.publishedAt.compareTo(b.publishedAt));

      final parts = entry.key.split('_');
      final category = parts.first;
      final date = _parseDate(parts.last);

      final clusterItems = sorted.map((item) {
        final eval = ClusterItem.evalFromVotes(
          item.confirmCount,
          item.disputeCount,
          item.source,
        );
        return ClusterItem(
          id: item.id,
          title: item.title,
          body: item.body,
          source: item.source,
          publishedAt: item.publishedAt,
          eval: eval,
          confirmCount: item.confirmCount,
          disputeCount: item.disputeCount,
        );
      }).toList();

      clusters.add(
        EventCluster(
          id: entry.key,
          category: category,
          date: date,
          items: clusterItems,
        ),
      );
    }

    clusters.sort((a, b) => b.date.compareTo(a.date));
    return clusters;
  }

  static DateTime _parseDate(String yyyyMMdd) {
    if (yyyyMMdd.length != 8) return DateTime.utc(1970);
    return DateTime.utc(
      int.parse(yyyyMMdd.substring(0, 4)),
      int.parse(yyyyMMdd.substring(4, 6)),
      int.parse(yyyyMMdd.substring(6, 8)),
    );
  }
}
