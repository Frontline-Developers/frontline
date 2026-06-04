import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/compare/domain/repositories/compare_repository.dart';
import 'package:frontline/features/compare/presentation/providers/compare_provider.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';

final _fakeReport = NewsItem(
  id: 'r1',
  title: 'Strike near Kyiv',
  source: NewsSource.citizen,
  publishedAt: DateTime(2026, 1, 1),
  category: 'combat',
);

final _fakeWire = NewsItem(
  id: 'w1',
  title: 'Wire coverage',
  source: NewsSource.wire,
  publishedAt: DateTime(2026, 1, 2),
);

class _FakeRepo implements CompareRepository {
  NewsItem? stubbedReport;
  List<NewsItem> stubbedWire = [];
  bool throwOnFetch = false;

  @override
  Future<NewsItem> fetchReport(String reportId) async {
    if (throwOnFetch) throw StateError('not found');
    return stubbedReport!;
  }

  @override
  Future<List<NewsItem>> fetchWireNewsByLocations(
    List<String> locations,
  ) async => stubbedWire;

  @override
  Future<List<NewsItem>> fetchWireNewsByCategory(String category) async =>
      stubbedWire;

  @override
  Future<List<NewsItem>> fetchRecentWireNews() async => stubbedWire;
}

ProviderContainer _container(_FakeRepo repo) => ProviderContainer(
  overrides: [compareRepositoryProvider.overrideWithValue(repo)],
);

void main() {
  group('CompareNotifier', () {
    test(
      'initial state: no report, empty wire news, not loading, no error',
      () {
        final c = _container(_FakeRepo());
        addTearDown(c.dispose);
        final state = c.read(compareNotifierProvider);
        expect(state.report, isNull);
        expect(state.wireNews, isEmpty);
        expect(state.isLoading, false);
        expect(state.error, isNull);
      },
    );

    test('load: success path populates report and wire news', () async {
      final repo = _FakeRepo()
        ..stubbedReport = _fakeReport
        ..stubbedWire = [_fakeWire];
      final c = _container(repo);
      addTearDown(c.dispose);

      await c.read(compareNotifierProvider.notifier).load('r1');
      final state = c.read(compareNotifierProvider);

      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.report?.id, 'r1');
      expect(state.wireNews, hasLength(1));
    });

    test('load: sets error state on repository failure', () async {
      final repo = _FakeRepo()..throwOnFetch = true;
      final c = _container(repo);
      addTearDown(c.dispose);

      await c.read(compareNotifierProvider.notifier).load('bad-id');
      final state = c.read(compareNotifierProvider);

      expect(state.isLoading, false);
      expect(state.error, isNotNull);
      expect(state.report, isNull);
    });

    test(
      'error message is user-friendly, not a raw exception string',
      () async {
        final repo = _FakeRepo()..throwOnFetch = true;
        final c = _container(repo);
        addTearDown(c.dispose);

        await c.read(compareNotifierProvider.notifier).load('bad-id');
        final error = c.read(compareNotifierProvider).error!;

        expect(error, isNot(contains('StateError')));
        expect(error, isNot(contains('Exception')));
      },
    );
  });
}
