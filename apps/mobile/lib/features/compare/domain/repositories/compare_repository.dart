import '../../../feed/domain/entities/news_item.dart';
import '../entities/event_cluster.dart';

abstract class CompareRepository {
  Stream<List<EventCluster>> watchClusters();
  Future<NewsItem> fetchReport(String reportId);
  Future<List<NewsItem>> fetchWireNewsByLocations(List<String> locations);
  Future<List<NewsItem>> fetchWireNewsByCategory(String category);
  Future<List<NewsItem>> fetchRecentWireNews();
}
