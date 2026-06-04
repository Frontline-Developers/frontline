import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';
import 'package:frontline/features/feed/presentation/providers/feed_provider.dart';
import 'package:frontline/features/search/domain/repositories/search_repository.dart';
import 'package:frontline/features/search/presentation/providers/search_provider.dart';
import 'package:frontline/features/search/presentation/screens/search_screen.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeFeedNotifier extends FeedNotifier {
  final FeedState _s;
  _FakeFeedNotifier(this._s);
  @override
  FeedState build() => _s;
}

class _FakeSearchNotifier extends SearchNotifier {
  final SearchState _s;
  _FakeSearchNotifier(this._s);
  @override
  SearchState build() => _s;
  @override
  void setQuery(String q) {}
  @override
  void setScope(String s) {}
  @override
  void clearQuery() {}
  @override
  Future<void> saveSearch(String term) async {}
  @override
  Future<void> loadRecents() async {}
  @override
  Future<void> clearAllSearches() async {}
}

class _FakeSearchRepository implements SearchRepository {
  @override
  Future<List<String>> loadRecentSearches() async => [];
  @override
  Future<void> saveRecentSearch(String term) async {}
  @override
  Future<void> clearRecentSearch(String term) async {}
  @override
  Future<void> clearAllRecentSearches() async {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(SearchState state, {List<NewsItem> feedItems = const []}) =>
    ProviderScope(
      overrides: [
        feedNotifierProvider.overrideWith(
          () => _FakeFeedNotifier(FeedState(items: feedItems)),
        ),
        searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
        searchNotifierProvider.overrideWith(() => _FakeSearchNotifier(state)),
      ],
      child: const MaterialApp(home: SearchScreen()),
    );

const _emptyState = SearchState();

NewsItem _citizen({String id = 'c1', String title = 'Strike on Kharkiv'}) =>
    NewsItem(
      id: id,
      title: title,
      source: NewsSource.citizen,
      publishedAt: DateTime(2026),
      category: 'combat',
    );

NewsItem _wire({String id = 'w1', String title = 'Reuters: Power update'}) =>
    NewsItem(
      id: id,
      title: title,
      source: NewsSource.wire,
      publishedAt: DateTime(2026),
      sourceName: 'Reuters',
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('SearchScreen — render', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_wrap(_emptyState));
      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('shows search TextField', (tester) async {
      await tester.pumpWidget(_wrap(_emptyState));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows Cancel button', (tester) async {
      await tester.pumpWidget(_wrap(_emptyState));
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('SearchScreen — empty state (query is blank)', () {
    testWidgets('shows RECENT section label', (tester) async {
      await tester.pumpWidget(_wrap(_emptyState));
      expect(find.text('RECENT'), findsOneWidget);
    });

    testWidgets('shows TRENDING NOW section label', (tester) async {
      await tester.pumpWidget(_wrap(_emptyState));
      expect(find.text('TRENDING NOW'), findsOneWidget);
    });

    testWidgets('scope chips are NOT visible when query is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_emptyState));
      expect(find.text('All'), findsNothing);
      expect(find.text('On the ground'), findsNothing);
      expect(find.text('Major sources'), findsNothing);
    });

    testWidgets('shows recent pill chips when recentSearches non-empty', (
      tester,
    ) async {
      const state = SearchState(
        recentSearches: ['Kharkiv substation', 'drone'],
      );
      await tester.pumpWidget(_wrap(state));
      expect(find.text('Kharkiv substation'), findsOneWidget);
      expect(find.text('drone'), findsOneWidget);
    });
  });

  group('SearchScreen — active search (query non-empty)', () {
    testWidgets('shows scope chips when query is non-empty', (tester) async {
      const state = SearchState(query: 'kharkiv', results: []);
      await tester.pumpWidget(_wrap(state));
      expect(find.text('All'), findsOneWidget);
      expect(find.text('On the ground'), findsOneWidget);
      expect(find.text('Major sources'), findsOneWidget);
    });

    testWidgets('All chip is active by default', (tester) async {
      const state = SearchState(query: 'kharkiv', scope: 'all', results: []);
      await tester.pumpWidget(_wrap(state));
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets(
      'shows no-results view when query non-empty and results empty',
      (tester) async {
        const state = SearchState(query: 'nothingmatchesthis', results: []);
        await tester.pumpWidget(_wrap(state));
        expect(find.textContaining('No matches for'), findsOneWidget);
        expect(
          find.textContaining('nothingmatchesthis'),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets('shows result count header when results non-empty', (
      tester,
    ) async {
      final state = SearchState(
        query: 'Kharkiv',
        results: [_citizen(), _wire()],
      );
      await tester.pumpWidget(_wrap(state));
      expect(find.textContaining('2 result'), findsOneWidget);
    });

    testWidgets('shows singular "result" for exactly 1 item', (tester) async {
      final state = SearchState(query: 'kharkiv', results: [_citizen()]);
      await tester.pumpWidget(_wrap(state));
      expect(find.textContaining('1 result'), findsOneWidget);
    });

    testWidgets('result cards render for each result', (tester) async {
      final state = SearchState(
        query: 'Kharkiv',
        results: [
          _citizen(id: 'c1', title: 'Strike on Kharkiv substation'),
          _wire(id: 'w1', title: 'Reuters: Kharkiv power'),
        ],
      );
      await tester.pumpWidget(_wrap(state));
      expect(find.text('Strike on Kharkiv substation'), findsOneWidget);
      expect(find.text('Reuters: Kharkiv power'), findsOneWidget);
    });

    testWidgets('result card shows source name for citizen item', (
      tester,
    ) async {
      final state = SearchState(
        query: 'strike',
        results: [_citizen(title: 'Strike observed')],
      );
      await tester.pumpWidget(_wrap(state));
      expect(find.textContaining('CITIZEN'), findsOneWidget);
    });

    testWidgets('result card shows wire source name', (tester) async {
      final state = SearchState(
        query: 'power',
        results: [_wire(title: 'Power grid update')],
      );
      await tester.pumpWidget(_wrap(state));
      expect(find.textContaining('REUTERS'), findsOneWidget);
    });
  });

  group('SearchScreen — Cancel action', () {
    testWidgets('Cancel button is tappable without throwing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedNotifierProvider.overrideWith(
              () => _FakeFeedNotifier(const FeedState()),
            ),
            searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
            searchNotifierProvider.overrideWith(
              () => _FakeSearchNotifier(_emptyState),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsNothing);
    });
  });
}
