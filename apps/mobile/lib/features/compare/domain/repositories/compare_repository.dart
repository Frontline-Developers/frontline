import '../../../feed/domain/entities/news_item.dart';

abstract class CompareRepository {
  Future<NewsItem> fetchReport(String reportId);
  Future<List<NewsItem>> fetchRelatedWireNews({
    required String description,
    required String category,
  });
}
