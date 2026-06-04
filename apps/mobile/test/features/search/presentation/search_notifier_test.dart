import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';
import 'package:frontline/features/feed/presentation/providers/feed_provider.dart';
import 'package:frontline/features/search/domain/repositories/search_repository.dart';
import 'package:frontline/features/search/presentation/providers/search_provider.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeFeedNotifier extends FeedNotifier {
  final FeedState _s;
  _FakeFeedNotifier(this._s);
  @override
  FeedState build() => _s;
}

class _FakeSearchRepository implements SearchRepository {
  final List<String> saved = [];
  final List<String> cleared = [];

  @override
  Future<List<String>> loadRecentSearches() async => ['old-term'];

  @override
  Future<void> saveRecentSearch(String term) async => saved.add(term);

  @override
  Future<void> clearRecentSearch(String term) async => cleared.add(term);
}

ProviderContainer _container({
  List<NewsItem> feedItems = const [],
  _FakeSearchRepository? repo,
}) {
  final fakeRepo = repo ?? _FakeSearchRepository();
  return ProviderContainer(
    overrides: [
      feedNotifierProvider.overrideWith(
        () => _FakeFeedNotifier(FeedState(items: feedItems)),
      ),
      searchRepositoryProvider.overrideWithValue(fakeRepo),
    ],
  );
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

NewsItem _citizen({
  String id = 'c1',
  String title = 'Strike on Kharkiv substation',
  String? body,
  List<String> locations = const [],
  String? category = 'combat',
}) => NewsItem(
  id: id,
  title: title,
  body: body,
  locations: locations,
  category: category,
  source: NewsSource.citizen,
  publishedAt: DateTime(2026),
);

NewsItem _wire({
  String id = 'w1',
  String title = 'Reuters: Power grid update',
  String? sourceName = 'Reuters',
}) => NewsItem(
  id: id,
  title: title,
  sourceName: sourceName,
  source: NewsSource.wire,
  publishedAt: DateTime(2026),
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('SearchNotifier — initial state', () {
    test('query is empty, scope is all, results are empty', () {
      final c = _container();
      addTearDown(c.dispose);

      final state = c.read(searchNotifierProvider);
      expect(state.query, '');
      expect(state.scope, 'all');
      expect(state.results, isEmpty);
    });

    test('recentSearches loaded from repository on build', () async {
      final c = _container();
      addTearDown(c.dispose);

      c.read(searchNotifierProvider);
      // Two nested async hops: microtask → loadRecents → repo.loadRecentSearches
      await Future.delayed(Duration.zero);

      final state = c.read(searchNotifierProvider);
      expect(state.recentSearches, contains('old-term'));
    });
  });

  group('SearchNotifier.setQuery', () {
    test('matching query returns filtered results', () async {
      final c = _container(feedItems: [_citizen(title: 'Strike on Kharkiv')]);
      addTearDown(c.dispose);

      c.read(searchNotifierProvider.notifier).setQuery('Kharkiv');
      await Future.microtask(() {});

      expect(c.read(searchNotifierProvider).results, hasLength(1));
    });

    test('non-matching query returns empty results', () async {
      final c = _container(feedItems: [_citizen(title: 'Aid convoy Odesa')]);
      addTearDown(c.dispose);

      c.read(searchNotifierProvider.notifier).setQuery('kharkiv');
      await Future.microtask(() {});

      expect(c.read(searchNotifierProvider).results, isEmpty);
    });

    test('multi-word AND — both words required', () async {
      final c = _container(
        feedItems: [
          _citizen(id: 'c1', title: 'Kharkiv power grid'),
          _citizen(id: 'c2', title: 'Kharkiv residential strike'),
        ],
      );
      addTearDown(c.dispose);

      c.read(searchNotifierProvider.notifier).setQuery('kharkiv power');
      await Future.microtask(() {});

      final results = c.read(searchNotifierProvider).results;
      expect(results, hasLength(1));
      expect(results.first.id, 'c1');
    });

    test('empty query clears results', () async {
      final c = _container(feedItems: [_citizen()]);
      addTearDown(c.dispose);

      final notifier = c.read(searchNotifierProvider.notifier);
      notifier.setQuery('kharkiv');
      await Future.microtask(() {});
      notifier.setQuery('');
      await Future.microtask(() {});

      expect(c.read(searchNotifierProvider).results, isEmpty);
    });

    test('updates query field on state', () async {
      final c = _container();
      addTearDown(c.dispose);

      c.read(searchNotifierProvider.notifier).setQuery('drone');
      await Future.microtask(() {});

      expect(c.read(searchNotifierProvider).query, 'drone');
    });
  });

  group('SearchNotifier.setScope', () {
    test('citizen scope excludes wire items', () async {
      final c = _container(
        feedItems: [
          _citizen(title: 'ground report'),
          _wire(title: 'ground news'),
        ],
      );
      addTearDown(c.dispose);

      final notifier = c.read(searchNotifierProvider.notifier);
      notifier.setQuery('ground');
      await Future.microtask(() {});
      notifier.setScope('citizen');
      await Future.microtask(() {});

      final results = c.read(searchNotifierProvider).results;
      expect(results.every((i) => i.source == NewsSource.citizen), isTrue);
    });

    test('sources scope excludes citizen items', () async {
      final c = _container(
        feedItems: [
          _citizen(title: 'ground report'),
          _wire(title: 'ground news'),
        ],
      );
      addTearDown(c.dispose);

      final notifier = c.read(searchNotifierProvider.notifier);
      notifier.setQuery('ground');
      await Future.microtask(() {});
      notifier.setScope('sources');
      await Future.microtask(() {});

      final results = c.read(searchNotifierProvider).results;
      expect(results.every((i) => i.source == NewsSource.wire), isTrue);
    });

    test('updates scope field on state', () async {
      final c = _container();
      addTearDown(c.dispose);

      c.read(searchNotifierProvider.notifier).setScope('citizen');
      await Future.microtask(() {});

      expect(c.read(searchNotifierProvider).scope, 'citizen');
    });
  });

  group('SearchNotifier.clearQuery', () {
    test('resets query to empty and clears results', () async {
      final c = _container(feedItems: [_citizen()]);
      addTearDown(c.dispose);

      final notifier = c.read(searchNotifierProvider.notifier);
      notifier.setQuery('kharkiv');
      await Future.microtask(() {});
      notifier.clearQuery();
      await Future.microtask(() {});

      final state = c.read(searchNotifierProvider);
      expect(state.query, '');
      expect(state.results, isEmpty);
    });
  });

  group('SearchNotifier.saveSearch', () {
    test('delegates to repository', () async {
      final repo = _FakeSearchRepository();
      final c = _container(repo: repo);
      addTearDown(c.dispose);

      await c.read(searchNotifierProvider.notifier).saveSearch('drone strike');

      expect(repo.saved, contains('drone strike'));
    });
  });
}
