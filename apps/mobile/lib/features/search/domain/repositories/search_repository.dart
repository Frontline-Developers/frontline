abstract class SearchRepository {
  Future<List<String>> loadRecentSearches();
  Future<void> saveRecentSearch(String term);
  Future<void> clearRecentSearch(String term);
  Future<void> clearAllRecentSearches();
}
