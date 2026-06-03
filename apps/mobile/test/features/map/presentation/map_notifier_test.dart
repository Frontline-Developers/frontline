import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/map/domain/entities/map_report.dart';
import 'package:frontline/features/map/presentation/providers/map_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('MapNotifier — initial state', () {
    test('starts with empty reports, no selection, default filters', () {
      final state = container.read(mapNotifierProvider);
      expect(state.reports, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.selectedReport, isNull);
      expect(state.showFiltersPanel, isFalse);
      expect(state.userLocation, isNull);
      expect(state.showCityLabels, isFalse);
      expect(state.filters, const MapFilters());
    });
  });

  group('MapNotifier.selectPin', () {
    test('sets selectedReport', () {
      final report = _makeReport('r1');
      container.read(mapNotifierProvider.notifier).selectPin(report);
      expect(container.read(mapNotifierProvider).selectedReport, report);
    });

    test('replaces previously selected report', () {
      final r1 = _makeReport('r1');
      final r2 = _makeReport('r2');
      container.read(mapNotifierProvider.notifier).selectPin(r1);
      container.read(mapNotifierProvider.notifier).selectPin(r2);
      expect(container.read(mapNotifierProvider).selectedReport, r2);
    });
  });

  group('MapNotifier.deselectPin', () {
    test('clears selectedReport', () {
      container.read(mapNotifierProvider.notifier).selectPin(_makeReport('r1'));
      container.read(mapNotifierProvider.notifier).deselectPin();
      expect(container.read(mapNotifierProvider).selectedReport, isNull);
    });

    test('is idempotent when nothing is selected', () {
      container.read(mapNotifierProvider.notifier).deselectPin();
      expect(container.read(mapNotifierProvider).selectedReport, isNull);
    });
  });

  group('MapNotifier.toggleFiltersPanel', () {
    test('opens panel when closed', () {
      container.read(mapNotifierProvider.notifier).toggleFiltersPanel();
      expect(container.read(mapNotifierProvider).showFiltersPanel, isTrue);
    });

    test('closes panel when open', () {
      container.read(mapNotifierProvider.notifier).toggleFiltersPanel();
      container.read(mapNotifierProvider.notifier).toggleFiltersPanel();
      expect(container.read(mapNotifierProvider).showFiltersPanel, isFalse);
    });
  });

  group('MapNotifier.updateFilters', () {
    test('updates time range', () {
      container.read(mapNotifierProvider.notifier).updateFilters(
        const MapFilters(timeRange: MapTimeRange.hour),
      );
      expect(
        container.read(mapNotifierProvider).filters.timeRange,
        MapTimeRange.hour,
      );
    });

    test('updates category', () {
      container.read(mapNotifierProvider.notifier).updateFilters(
        const MapFilters(category: MapCategory.combat),
      );
      expect(
        container.read(mapNotifierProvider).filters.category,
        MapCategory.combat,
      );
    });

    test('preserves other filter fields when updating one', () {
      container.read(mapNotifierProvider.notifier).updateFilters(
        const MapFilters(
          timeRange: MapTimeRange.day,
          category: MapCategory.aid,
        ),
      );
      final filters = container.read(mapNotifierProvider).filters;
      expect(filters.timeRange, MapTimeRange.day);
      expect(filters.category, MapCategory.aid);
    });
  });

  group('MapNotifier.resetFilters', () {
    test('restores default filters after a change', () {
      container.read(mapNotifierProvider.notifier).updateFilters(
        const MapFilters(
          timeRange: MapTimeRange.hour,
          category: MapCategory.combat,
        ),
      );
      container.read(mapNotifierProvider.notifier).resetFilters();
      expect(container.read(mapNotifierProvider).filters, const MapFilters());
    });
  });

  group('MapNotifier.toggleCityLabels', () {
    test('enables city labels', () {
      container.read(mapNotifierProvider.notifier).toggleCityLabels();
      expect(container.read(mapNotifierProvider).showCityLabels, isTrue);
    });

    test('disables city labels when already on', () {
      container.read(mapNotifierProvider.notifier).toggleCityLabels();
      container.read(mapNotifierProvider.notifier).toggleCityLabels();
      expect(container.read(mapNotifierProvider).showCityLabels, isFalse);
    });
  });
}

MapReport _makeReport(String id) => MapReport(
  id: id,
  lat: 50.45,
  lng: 30.52,
  category: 'combat',
  title: 'Test report $id',
  locationLabel: 'Kyiv',
  status: 'pending',
  createdAt: DateTime(2026, 1, 1),
);
