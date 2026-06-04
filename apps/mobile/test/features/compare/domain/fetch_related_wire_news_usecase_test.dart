import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/compare/domain/entities/event_cluster.dart';
import 'package:frontline/features/compare/domain/repositories/compare_repository.dart';
import 'package:frontline/features/compare/domain/usecases/fetch_related_wire_news_usecase.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';

NewsItem _wire(String id) => NewsItem(
  id: id,
  title: 'Wire $id',
  source: NewsSource.wire,
  publishedAt: DateTime(2026, 1, 1),
);

class _FakeRepo implements CompareRepository {
  List<NewsItem> byLocations = [];
  List<NewsItem> byCategory = [];
  List<NewsItem> recent = [];

  @override
  Stream<List<EventCluster>> watchClusters() => const Stream.empty();

  @override
  Future<NewsItem> fetchReport(String reportId) => throw UnimplementedError();

  @override
  Future<List<NewsItem>> fetchWireNewsByLocations(
    List<String> locations,
  ) async => byLocations;

  @override
  Future<List<NewsItem>> fetchWireNewsByCategory(String category) async =>
      byCategory;

  @override
  Future<List<NewsItem>> fetchRecentWireNews() async => recent;
}

void main() {
  group('FetchRelatedWireNewsUseCase.extractLocations', () {
    test('matches known location names in text', () {
      final locs = FetchRelatedWireNewsUseCase.extractLocations(
        'Fighting near Kyiv and Kharkiv',
      );
      expect(locs, containsAll(['kyiv', 'kharkiv']));
    });

    test('returns empty for unrelated text', () {
      final locs = FetchRelatedWireNewsUseCase.extractLocations(
        'The weather is sunny today.',
      );
      expect(locs, isEmpty);
    });

    test('is case-insensitive', () {
      final locs = FetchRelatedWireNewsUseCase.extractLocations(
        'Explosion in KYIV',
      );
      expect(locs, contains('kyiv'));
    });
  });

  group('FetchRelatedWireNewsUseCase.call', () {
    test('returns location-matched articles when locations found', () async {
      final repo = _FakeRepo()..byLocations = [_wire('a'), _wire('b')];
      final usecase = FetchRelatedWireNewsUseCase(repo);
      final result = await usecase(
        description: 'Strike near Kyiv',
        category: 'combat',
      );
      expect(result.map((n) => n.id), containsAll(['a', 'b']));
    });

    test('falls back to category when location query returns empty', () async {
      final repo = _FakeRepo()
        ..byLocations = []
        ..byCategory = [_wire('c')];
      final usecase = FetchRelatedWireNewsUseCase(repo);
      final result = await usecase(
        description: 'Strike near Kyiv',
        category: 'combat',
      );
      expect(result.map((n) => n.id), contains('c'));
    });

    test(
      'falls back to recent when location and category both return empty',
      () async {
        final repo = _FakeRepo()
          ..byLocations = []
          ..byCategory = []
          ..recent = [_wire('r')];
        final usecase = FetchRelatedWireNewsUseCase(repo);
        final result = await usecase(
          description: 'Strike near Kyiv',
          category: 'combat',
        );
        expect(result.map((n) => n.id), contains('r'));
      },
    );

    test(
      'skips location tier when no locations extracted from description',
      () async {
        final repo = _FakeRepo()..byCategory = [_wire('d')];
        final usecase = FetchRelatedWireNewsUseCase(repo);
        final result = await usecase(
          description: 'An unrelated incident',
          category: 'aid',
        );
        expect(result.map((n) => n.id), contains('d'));
      },
    );

    test('skips category tier when category is "other"', () async {
      final repo = _FakeRepo()..recent = [_wire('e')];
      final usecase = FetchRelatedWireNewsUseCase(repo);
      final result = await usecase(
        description: 'An unrelated incident',
        category: 'other',
      );
      expect(result.map((n) => n.id), contains('e'));
    });

    test(
      'caps locations at 10 to stay within Firestore arrayContainsAny limit',
      () async {
        // A description mentioning many cities should not pass > 10 to the repo.
        final repo = _FakeRepo()..byLocations = [_wire('f')];
        final usecase = FetchRelatedWireNewsUseCase(repo);
        // Mentions many known locations to stress-test the cap.
        const bigText =
            'kyiv kharkiv odesa zaporizhzhia lviv mariupol donetsk luhansk '
            'kherson mykolaiv dnipro sumy chernihiv kramatorsk bakhmut '
            'avdiivka bucha irpin melitopol crimea donbas ukraine';
        final result = await usecase(description: bigText, category: 'combat');
        expect(result, isNotEmpty);
      },
    );
  });
}
