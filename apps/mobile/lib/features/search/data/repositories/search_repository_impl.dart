import '../../domain/repositories/search_repository.dart';
import '../datasources/search_datasource.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._datasource);

  final SearchDatasource _datasource;

  @override
  Future<List<String>> loadRecentSearches() =>
      _datasource.loadRecentSearches();

  @override
  Future<void> saveRecentSearch(String term) =>
      _datasource.saveRecentSearch(term);

  @override
  Future<void> clearRecentSearch(String term) =>
      _datasource.clearRecentSearch(term);

  @override
  Future<void> clearAllRecentSearches() =>
      _datasource.clearAllRecentSearches();
}
