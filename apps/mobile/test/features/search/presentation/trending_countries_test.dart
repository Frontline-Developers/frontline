import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';
import 'package:frontline/features/search/presentation/providers/search_provider.dart';

// Helpers -------------------------------------------------------------------

NewsItem _citizen({
  String id = 'c1',
  List<String> locations = const [],
  ItemStatus? status,
}) => NewsItem(
  id: id,
  title: 'report',
  source: NewsSource.citizen,
  publishedAt: DateTime(2026),
  locations: locations,
  status: status,
);

NewsItem _wire({String id = 'w1', List<String> locations = const []}) =>
    NewsItem(
      id: id,
      title: 'news',
      source: NewsSource.wire,
      publishedAt: DateTime(2026),
      locations: locations,
    );

// ---------------------------------------------------------------------------

void main() {
  group('computeTrendingCountries — citizen reports via locationLabel', () {
    test('extracts country from "City, Country" locationLabel', () {
      final items = [
        _citizen(locations: ['Bangkok, Thailand']),
      ];
      final result = computeTrendingCountries(items, true);
      expect(result.map((e) => e.name), contains('Thailand'));
    });

    test(
      'accumulates count when multiple citizen reports share the same country',
      () {
        final items = [
          _citizen(id: 'c1', locations: ['Bangkok, Thailand']),
          _citizen(id: 'c2', locations: ['Chiang Mai, Thailand']),
          _citizen(id: 'c3', locations: ['Kyiv, Ukraine']),
        ];
        final result = computeTrendingCountries(items, true);
        final thailand = result.firstWhere((e) => e.name == 'Thailand');
        expect(thailand.count, 2);
      },
    );

    test('skips citizen report with empty locations (empty locationLabel)', () {
      final items = [_citizen(locations: [])];
      final result = computeTrendingCountries(items, true);
      expect(result, isEmpty);
    });

    test(
      'handles locationLabel with no comma — uses whole value as country',
      () {
        final items = [
          _citizen(locations: ['Afghanistan']),
        ];
        final result = computeTrendingCountries(items, true);
        expect(result.map((e) => e.name), contains('Afghanistan'));
      },
    );

    test('trims whitespace from extracted country name', () {
      final items = [
        _citizen(locations: ['Kabul,  Afghanistan ']),
      ];
      final result = computeTrendingCountries(items, true);
      expect(result.map((e) => e.name), contains('Afghanistan'));
      expect(result.map((e) => e.name), isNot(contains('Afghanistan ')));
    });
  });

  group('computeTrendingCountries — wire news via _kCityToCountry dict', () {
    test('maps known city to country for wire news', () {
      final items = [
        _wire(locations: ['kyiv']),
      ];
      final result = computeTrendingCountries(items, true);
      expect(result.map((e) => e.name), contains('Ukraine'));
    });

    test('wire news city not in dict is ignored', () {
      final items = [
        _wire(locations: ['unknowncity']),
      ];
      final result = computeTrendingCountries(items, true);
      expect(result, isEmpty);
    });
  });

  group(
    'computeTrendingCountries — no double-count between wire and citizen',
    () {
      test('wire and citizen each counted once even if same country', () {
        final items = [
          _wire(locations: ['kyiv']), // → Ukraine via dict
          _citizen(locations: ['Kyiv, Ukraine']), // → Ukraine via locationLabel
        ];
        final result = computeTrendingCountries(items, true);
        final ukraine = result.firstWhere((e) => e.name == 'Ukraine');
        expect(ukraine.count, 2); // one per item, not double
      });

      test('wire does not use locationLabel path', () {
        // wire item with a "City, Country"-style string in locations
        // should NOT be counted if the city part is not in the dict
        final items = [
          _wire(
            locations: ['Bangkok, Thailand'],
          ), // "bangkok, thailand" not in dict
        ];
        final result = computeTrendingCountries(items, true);
        expect(result, isEmpty);
      });
    },
  );

  group('computeTrendingCountries — disputed filter', () {
    test('excludes disputed items when includeDisputed is false', () {
      final items = [
        _citizen(locations: ['Bangkok, Thailand'], status: ItemStatus.disputed),
      ];
      final result = computeTrendingCountries(items, false);
      expect(result, isEmpty);
    });

    test('includes disputed items when includeDisputed is true', () {
      final items = [
        _citizen(locations: ['Bangkok, Thailand'], status: ItemStatus.disputed),
      ];
      final result = computeTrendingCountries(items, true);
      expect(result.map((e) => e.name), contains('Thailand'));
    });
  });

  group('computeTrendingCountries — top 5 limit', () {
    test('returns at most 5 countries', () {
      final items = [
        _citizen(id: 'c1', locations: ['A, CountryA']),
        _citizen(id: 'c2', locations: ['B, CountryB']),
        _citizen(id: 'c3', locations: ['C, CountryC']),
        _citizen(id: 'c4', locations: ['D, CountryD']),
        _citizen(id: 'c5', locations: ['E, CountryE']),
        _citizen(id: 'c6', locations: ['F, CountryF']),
      ];
      final result = computeTrendingCountries(items, true);
      expect(result.length, lessThanOrEqualTo(5));
    });
  });
}
