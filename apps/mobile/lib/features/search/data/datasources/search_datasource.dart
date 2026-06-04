import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/search_repository.dart';

class SearchDatasourceImpl implements SearchRepository {
  SearchDatasourceImpl(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'recent_searches';
  static const _maxRecents = 8;

  @override
  Future<List<String>> loadRecentSearches() async =>
      _prefs.getStringList(_key) ?? [];

  @override
  Future<void> saveRecentSearch(String term) async {
    final recents = _prefs.getStringList(_key) ?? [];
    recents.remove(term);
    recents.insert(0, term);
    if (recents.length > _maxRecents) recents.removeLast();
    await _prefs.setStringList(_key, recents);
  }

  @override
  Future<void> clearRecentSearch(String term) async {
    final recents = _prefs.getStringList(_key) ?? [];
    recents.remove(term);
    await _prefs.setStringList(_key, recents);
  }

  @override
  Future<void> clearAllRecentSearches() async {
    await _prefs.remove(_key);
  }
}
