import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/map/domain/entities/map_filters.dart';

void main() {
  group('MapFilters — defaults', () {
    test('default timeRange is all', () {
      const filters = MapFilters();
      expect(filters.timeRange, MapTimeRange.all);
    });

    test('default category is all', () {
      const filters = MapFilters();
      expect(filters.category, MapCategory.all);
    });
  });

  group('MapFilters.isDefault', () {
    test('returns true for default construction', () {
      const filters = MapFilters();
      expect(filters.isDefault, isTrue);
    });

    test('returns false when timeRange is non-default', () {
      const filters = MapFilters(timeRange: MapTimeRange.hour);
      expect(filters.isDefault, isFalse);
    });

    test('returns false when category is non-default', () {
      const filters = MapFilters(category: MapCategory.combat);
      expect(filters.isDefault, isFalse);
    });

    test('returns false when both are non-default', () {
      const filters = MapFilters(
        timeRange: MapTimeRange.day,
        category: MapCategory.aid,
      );
      expect(filters.isDefault, isFalse);
    });

    test('returns true when explicitly set to default values', () {
      const filters = MapFilters(
        timeRange: MapTimeRange.all,
        category: MapCategory.all,
      );
      expect(filters.isDefault, isTrue);
    });
  });

  group('MapFilters.copyWith', () {
    test('copyWith with no args returns equivalent object', () {
      const original = MapFilters();
      final copy = original.copyWith();
      expect(copy, original);
    });

    test('copyWith changes timeRange only', () {
      const original = MapFilters(category: MapCategory.combat);
      final copy = original.copyWith(timeRange: MapTimeRange.hour);
      expect(copy.timeRange, MapTimeRange.hour);
      expect(copy.category, MapCategory.combat);
    });

    test('copyWith changes category only', () {
      const original = MapFilters(timeRange: MapTimeRange.day);
      final copy = original.copyWith(category: MapCategory.aid);
      expect(copy.category, MapCategory.aid);
      expect(copy.timeRange, MapTimeRange.day);
    });

    test('copyWith changes both fields', () {
      const original = MapFilters();
      final copy = original.copyWith(
        timeRange: MapTimeRange.hour,
        category: MapCategory.infra,
      );
      expect(copy.timeRange, MapTimeRange.hour);
      expect(copy.category, MapCategory.infra);
    });
  });

  group('MapFilters — value equality', () {
    test('two default instances are equal', () {
      const a = MapFilters();
      const b = MapFilters();
      expect(a, equals(b));
    });

    test('instances with same non-default values are equal', () {
      const a = MapFilters(
        timeRange: MapTimeRange.hour,
        category: MapCategory.combat,
      );
      const b = MapFilters(
        timeRange: MapTimeRange.hour,
        category: MapCategory.combat,
      );
      expect(a, equals(b));
    });

    test('instances with different timeRange are not equal', () {
      const a = MapFilters(timeRange: MapTimeRange.hour);
      const b = MapFilters(timeRange: MapTimeRange.day);
      expect(a, isNot(equals(b)));
    });

    test('instances with different category are not equal', () {
      const a = MapFilters(category: MapCategory.combat);
      const b = MapFilters(category: MapCategory.aid);
      expect(a, isNot(equals(b)));
    });

    test('hashCode equals for equal instances', () {
      const a = MapFilters(
        timeRange: MapTimeRange.day,
        category: MapCategory.alert,
      );
      const b = MapFilters(
        timeRange: MapTimeRange.day,
        category: MapCategory.alert,
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('MapTimeRange — enum values', () {
    test('has exactly four values', () {
      expect(MapTimeRange.values, hasLength(4));
    });

    test('contains hour, sixHours, day, all', () {
      expect(
        MapTimeRange.values,
        containsAll([
          MapTimeRange.hour,
          MapTimeRange.sixHours,
          MapTimeRange.day,
          MapTimeRange.all,
        ]),
      );
    });
  });

  group('MapCategory — enum values', () {
    test('has exactly seven values', () {
      expect(MapCategory.values, hasLength(7));
    });

    test('contains all, combat, aid, alert, displaced, infra, other', () {
      expect(
        MapCategory.values,
        containsAll([
          MapCategory.all,
          MapCategory.combat,
          MapCategory.aid,
          MapCategory.alert,
          MapCategory.displaced,
          MapCategory.infra,
          MapCategory.other,
        ]),
      );
    });
  });
}
