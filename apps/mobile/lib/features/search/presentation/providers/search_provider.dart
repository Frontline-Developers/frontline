import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/feed/domain/entities/news_item.dart';
import '../../../../features/feed/presentation/providers/feed_provider.dart';
import '../../domain/repositories/search_repository.dart';
import '../../domain/usecases/search_items.dart';

// ── Trending country ──────────────────────────────────────────────────────────

class TrendingCountry {
  final String name;
  final int count;
  const TrendingCountry({required this.name, required this.count});
}

// City / region → canonical country name
const _kCityToCountry = <String, String>{
  // Ukraine
  'ukraine': 'Ukraine',
  'kyiv': 'Ukraine', 'kiev': 'Ukraine',
  'kharkiv': 'Ukraine', 'kharkov': 'Ukraine',
  'mariupol': 'Ukraine',
  'zaporizhzhia': 'Ukraine', 'zaporizhzhe': 'Ukraine', 'zaporozhye': 'Ukraine',
  'odesa': 'Ukraine', 'odessa': 'Ukraine',
  'lviv': 'Ukraine', 'lvov': 'Ukraine',
  'kherson': 'Ukraine',
  'mykolaiv': 'Ukraine', 'nikolaev': 'Ukraine',
  'donetsk': 'Ukraine',
  'luhansk': 'Ukraine', 'lugansk': 'Ukraine',
  'dnipro': 'Ukraine', 'dnipropetrovsk': 'Ukraine',
  'sumy': 'Ukraine',
  'poltava': 'Ukraine',
  'chernihiv': 'Ukraine', 'chernigov': 'Ukraine',
  'vinnytsia': 'Ukraine', 'vinnitsa': 'Ukraine',
  'bakhmut': 'Ukraine',
  'avdiivka': 'Ukraine',
  'kramatorsk': 'Ukraine',
  'sloviansk': 'Ukraine',
  'severodonetsk': 'Ukraine',
  'lysychansk': 'Ukraine',
  'melitopol': 'Ukraine',
  'izium': 'Ukraine', 'izyum': 'Ukraine',
  'donbas': 'Ukraine', 'donbass': 'Ukraine',
  'kharkiv oblast': 'Ukraine',
  'zaporizhzhia oblast': 'Ukraine',
  'kherson oblast': 'Ukraine',
  // Russia
  'russia': 'Russia',
  'moscow': 'Russia', 'moskva': 'Russia',
  'saint petersburg': 'Russia', 'st petersburg': 'Russia',
  'st. petersburg': 'Russia',
  'belgorod': 'Russia',
  'bryansk': 'Russia',
  'kursk': 'Russia',
  'voronezh': 'Russia',
  'rostov': 'Russia', 'rostov-on-don': 'Russia',
  'crimea': 'Russia',
  'sevastopol': 'Russia',
  'simferopol': 'Russia',
  // Belarus
  'belarus': 'Belarus',
  'minsk': 'Belarus',
  'gomel': 'Belarus',
  // Poland
  'poland': 'Poland',
  'warsaw': 'Poland',
  'krakow': 'Poland', 'kraków': 'Poland',
  'rzeszow': 'Poland', 'rzeszów': 'Poland',
  // Germany
  'germany': 'Germany',
  'berlin': 'Germany',
  'munich': 'Germany', 'münchen': 'Germany',
  // France
  'france': 'France',
  'paris': 'France',
  // United Kingdom
  'united kingdom': 'United Kingdom',
  'uk': 'United Kingdom',
  'london': 'United Kingdom',
  // United States
  'united states': 'United States',
  'usa': 'United States',
  'washington': 'United States', 'washington dc': 'United States',
  'new york': 'United States',
  // Turkey
  'turkey': 'Turkey',
  'ankara': 'Turkey',
  'istanbul': 'Turkey',
  // Moldova
  'moldova': 'Moldova',
  'chisinau': 'Moldova', 'chișinău': 'Moldova',
  // Romania
  'romania': 'Romania',
  'bucharest': 'Romania',
  // Hungary
  'hungary': 'Hungary',
  'budapest': 'Hungary',
  // Israel
  'israel': 'Israel',
  'tel aviv': 'Israel',
  'jerusalem': 'Israel',
  // China
  'china': 'China',
  'beijing': 'China',
  'shanghai': 'China',
  // Georgia
  'georgia': 'Georgia',
  'tbilisi': 'Georgia',
  // Azerbaijan
  'azerbaijan': 'Azerbaijan',
  'baku': 'Azerbaijan',
  // Armenia
  'armenia': 'Armenia',
  'yerevan': 'Armenia',
};

List<TrendingCountry> computeTrendingCountries(
  List<NewsItem> items,
  bool includeDisputed,
) {
  final counts = <String, int>{};

  for (final item in items) {
    if (item.status == ItemStatus.disputed && !includeDisputed) continue;

    final countries = <String>{};
    for (final loc in item.locations) {
      final key = loc.toLowerCase().trim();
      final country = _kCityToCountry[key];
      if (country != null) countries.add(country);
    }

    for (final c in countries) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
  }

  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted
      .take(5)
      .map((e) => TrendingCountry(name: e.key, count: e.value))
      .toList();
}

// ── State ─────────────────────────────────────────────────────────────────────

class SearchState {
  final String query;
  final String scope;
  final List<NewsItem> results;
  final List<String> recentSearches;
  final List<TrendingCountry> trendingCountries;
  final bool includeDisputed;

  const SearchState({
    this.query = '',
    this.scope = 'all',
    this.results = const [],
    this.recentSearches = const [],
    this.trendingCountries = const [],
    this.includeDisputed = false,
  });

  SearchState copyWith({
    String? query,
    String? scope,
    List<NewsItem>? results,
    List<String>? recentSearches,
    List<TrendingCountry>? trendingCountries,
    bool? includeDisputed,
  }) => SearchState(
    query: query ?? this.query,
    scope: scope ?? this.scope,
    results: results ?? this.results,
    recentSearches: recentSearches ?? this.recentSearches,
    trendingCountries: trendingCountries ?? this.trendingCountries,
    includeDisputed: includeDisputed ?? this.includeDisputed,
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

  void toggleIncludeDisputed() {
    final next = !state.includeDisputed;
    state = state.copyWith(
      includeDisputed: next,
      trendingCountries: computeTrendingCountries(_currentFeedItems(), next),
    );
  }

  Future<void> saveSearch(String term) async {
    await ref.read(searchRepositoryProvider).saveRecentSearch(term);
    final recents = await ref
        .read(searchRepositoryProvider)
        .loadRecentSearches();
    state = state.copyWith(recentSearches: recents.take(5).toList());
  }

  Future<void> loadRecents() async {
    final recents = await ref
        .read(searchRepositoryProvider)
        .loadRecentSearches();
    state = state.copyWith(
      recentSearches: recents.take(5).toList(),
      trendingCountries: computeTrendingCountries(
        _currentFeedItems(),
        state.includeDisputed,
      ),
    );
  }

  Future<void> removeSearch(String term) async {
    await ref.read(searchRepositoryProvider).clearRecentSearch(term);
    final recents = await ref
        .read(searchRepositoryProvider)
        .loadRecentSearches();
    state = state.copyWith(recentSearches: recents.take(5).toList());
  }

  Future<void> clearAllSearches() async {
    await ref.read(searchRepositoryProvider).clearAllRecentSearches();
    state = state.copyWith(recentSearches: []);
  }
}
