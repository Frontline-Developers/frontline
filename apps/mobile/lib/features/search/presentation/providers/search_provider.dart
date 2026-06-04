import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/feed/domain/entities/news_item.dart';
import '../../../../features/feed/presentation/providers/feed_provider.dart';
import '../../data/datasources/search_datasource.dart';
import '../../domain/repositories/search_repository.dart';
import '../../domain/usecases/search_items.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class SearchState {
  final String query;
  final String scope;
  final List<NewsItem> results;
  final List<String> recentSearches;

  const SearchState({
    this.query = '',
    this.scope = 'all',
    this.results = const [],
    this.recentSearches = const [],
  });

  SearchState copyWith({
    String? query,
    String? scope,
    List<NewsItem>? results,
    List<String>? recentSearches,
  }) => SearchState(
    query: query ?? this.query,
    scope: scope ?? this.scope,
    results: results ?? this.results,
    recentSearches: recentSearches ?? this.recentSearches,
  );
}

// ── DI ────────────────────────────────────────────────────────────────────────

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  throw UnimplementedError('override in main or tests');
});

// ── Notifier ──────────────────────────────────────────────────────────────────

final searchNotifierProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() {
    Future.microtask(loadRecents);
    return const SearchState();
  }

  List<NewsItem> _currentFeedItems() => ref.read(feedNotifierProvider).items;

  List<NewsItem> _filter(String query, String scope) {
    if (query.trim().isEmpty) return [];
    return _currentFeedItems()
        .where((item) => searchMatches(item, query, scope))
        .toList();
  }

  void setQuery(String q) {
    state = state.copyWith(query: q, results: _filter(q, state.scope));
  }

  void setScope(String s) {
    state = state.copyWith(scope: s, results: _filter(state.query, s));
  }

  void clearQuery() {
    state = state.copyWith(query: '', results: []);
  }

  Future<void> saveSearch(String term) async {
    await ref.read(searchRepositoryProvider).saveRecentSearch(term);
    final recents = await ref
        .read(searchRepositoryProvider)
        .loadRecentSearches();
    state = state.copyWith(recentSearches: recents.take(4).toList());
  }

  Future<void> loadRecents() async {
    final recents = await ref
        .read(searchRepositoryProvider)
        .loadRecentSearches();
    state = state.copyWith(recentSearches: recents.take(4).toList());
  }
}

// ── Async provider helper for main.dart ──────────────────────────────────────

final searchRepositoryImplProvider = FutureProvider<SearchRepository>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return SearchDatasourceImpl(prefs);
});
