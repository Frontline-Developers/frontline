import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../feed/data/models/news_item_model.dart';
import '../../../feed/domain/entities/news_item.dart';

abstract class CompareDatasource {
  Future<NewsItem> fetchReport(String reportId);
  Future<List<NewsItem>> fetchWireNewsByLocations(List<String> locations);
  Future<List<NewsItem>> fetchWireNewsByCategory(String category);
  Future<List<NewsItem>> fetchRecentWireNews();
}

class CompareDatasourceImpl implements CompareDatasource {
  @override
  Future<NewsItem> fetchReport(String reportId) async {
    // Use a list query (covered by allow list) rather than a direct .doc().get()
    // (which requires allow get, restricted to the owner for privacy).
    final snap = await FirebaseFirestore.instance
        .collection('reports')
        .where(FieldPath.documentId, isEqualTo: reportId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) throw Exception('Report not found');
    return ReportFeedModel.fromFirestore(snap.docs.first).toEntity();
  }

  @override
  Future<List<NewsItem>> fetchWireNewsByLocations(
    List<String> locations,
  ) async {
    // Firestore arrayContainsAny max is 30; cap here as a hard boundary.
    final capped = locations.take(30).toList();
    final snap = await FirebaseFirestore.instance
        .collection('wire_news')
        .where('locations', arrayContainsAny: capped)
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
}
