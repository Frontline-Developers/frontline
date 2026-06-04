import '../../../feed/domain/entities/news_item.dart';

abstract class CompareRepository {
  Future<NewsItem> fetchReport(String reportId);
  Future<List<NewsItem>> fetchWireNewsByLocations(List<String> locations);
  Future<List<NewsItem>> fetchWireNewsByCategory(String category);
  Future<List<NewsItem>> fetchRecentWireNews();
}
