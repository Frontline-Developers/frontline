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
}
