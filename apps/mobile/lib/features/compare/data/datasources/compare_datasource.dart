import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../feed/data/models/news_item_model.dart';
import '../../../feed/domain/entities/news_item.dart';

const _ukraineLocations = [
  'kyiv',
  'kharkiv',
  'odesa',
  'zaporizhzhia',
  'lviv',
  'mariupol',
  'donetsk',
  'luhansk',
  'kherson',
  'mykolaiv',
  'dnipro',
  'sumy',
  'chernihiv',
  'kramatorsk',
  'bakhmut',
  'avdiivka',
  'bucha',
  'irpin',
  'melitopol',
  'crimea',
  'donbas',
  'ukraine',
];

abstract class CompareDatasource {
  Future<NewsItem> fetchReport(String reportId);
  Future<List<NewsItem>> fetchRelatedWireNews({
    required String description,
    required String category,
  });
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
  Future<List<NewsItem>> fetchRelatedWireNews({
    required String description,
    required String category,
  }) async {
    // 1. Try location match — find wire articles mentioning same Ukraine locations
    final locations = _extractLocations(description).take(10).toList();
    if (locations.isNotEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection('wire_news')
          .where('locations', arrayContainsAny: locations)
          .orderBy('publishedAt', descending: true)
          .limit(10)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) => NewsItemModel.fromJson(d.id, d.data()).toEntity())
            .toList();
      }
    }

    // 2. Try theme match — same category as the citizen report
    if (category != 'other') {
      final snap = await FirebaseFirestore.instance
          .collection('wire_news')
          .where('themes', arrayContains: category)
          .orderBy('publishedAt', descending: true)
          .limit(10)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) => NewsItemModel.fromJson(d.id, d.data()).toEntity())
            .toList();
      }
    }

    // 3. Fall back to most recent wire news
    final snap = await FirebaseFirestore.instance
        .collection('wire_news')
        .orderBy('publishedAt', descending: true)
        .limit(10)
        .get();
    return snap.docs
        .map((d) => NewsItemModel.fromJson(d.id, d.data()).toEntity())
        .toList();
  }

  List<String> _extractLocations(String text) {
    final lower = text.toLowerCase();
    return _ukraineLocations.where((loc) => lower.contains(loc)).toList();
  }
}
