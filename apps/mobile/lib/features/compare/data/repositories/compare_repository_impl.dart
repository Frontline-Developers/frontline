import '../../../feed/domain/entities/news_item.dart';
import '../../domain/repositories/compare_repository.dart';
import '../datasources/compare_datasource.dart';

class CompareRepositoryImpl implements CompareRepository {
  final CompareDatasource _datasource;
  CompareRepositoryImpl(this._datasource);

  @override
  Future<NewsItem> fetchReport(String reportId) =>
      _datasource.fetchReport(reportId);

  @override
  Future<List<NewsItem>> fetchWireNewsByLocations(List<String> locations) =>
      _datasource.fetchWireNewsByLocations(locations);

  @override
  Future<List<NewsItem>> fetchWireNewsByCategory(String category) =>
      _datasource.fetchWireNewsByCategory(category);

  @override
  Future<List<NewsItem>> fetchRecentWireNews() =>
      _datasource.fetchRecentWireNews();
}
