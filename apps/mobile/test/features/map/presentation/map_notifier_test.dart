import 'dart:async';

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
      container
          .read(mapNotifierProvider.notifier)
          .updateFilters(const MapFilters(timeRange: MapTimeRange.hour));
      expect(
        container.read(mapNotifierProvider).filters.timeRange,
        MapTimeRange.hour,
      );
    });

    test('updates category', () {
      container
          .read(mapNotifierProvider.notifier)
          .updateFilters(const MapFilters(category: MapCategory.combat));
      expect(
        container.read(mapNotifierProvider).filters.category,
        MapCategory.combat,
      );
    });

    test('preserves other filter fields when updating one', () {
      container
          .read(mapNotifierProvider.notifier)
          .updateFilters(
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
      container
          .read(mapNotifierProvider.notifier)
          .updateFilters(
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

  group('MapNotifier.watchArea — state transitions', () {
    late _StreamableMapNotifier fake;
    late ProviderContainer container;

    setUp(() {
      fake = _StreamableMapNotifier();
      container = ProviderContainer(
        overrides: [mapNotifierProvider.overrideWith(() => fake)],
      );
    });
    tearDown(() => container.dispose());

    test('sets isLoading true immediately', () {
      container.read(mapNotifierProvider.notifier).watchArea(50.45, 30.52, 10);
      expect(container.read(mapNotifierProvider).isLoading, isTrue);
    });

    test('clears pre-existing error when called', () {
      container.read(
        mapNotifierProvider,
      ); // initialize notifier before seeding state
      fake.seedError('old error');
      container.read(mapNotifierProvider.notifier).watchArea(50.45, 30.52, 10);
      expect(container.read(mapNotifierProvider).error, isNull);
      expect(container.read(mapNotifierProvider).isLoading, isTrue);
    });

    test('updates reports and clears loading when data arrives', () async {
      container.read(mapNotifierProvider.notifier).watchArea(50.45, 30.52, 10);
      fake.push([_makeReport('r1')]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(mapNotifierProvider).reports, hasLength(1));
      expect(container.read(mapNotifierProvider).isLoading, isFalse);
    });

    test('sets error and clears loading when stream errors', () async {
      container.read(mapNotifierProvider.notifier).watchArea(50.45, 30.52, 10);
      fake.pushError(Exception('Firestore unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(mapNotifierProvider).error,
        contains('Firestore unavailable'),
      );
      expect(container.read(mapNotifierProvider).isLoading, isFalse);
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

class _StreamableMapNotifier extends MapNotifier {
  final _ctrl = StreamController<List<MapReport>>();

  @override
  MapState build() => const MapState();

  void seedError(String error) {
    state = state.copyWith(error: error);
  }

  @override
  void watchArea(double lat, double lng, double radiusKm) {
    state = state.copyWith(isLoading: true, error: null);
    _ctrl.stream.listen(
      (reports) => state = state.copyWith(reports: reports, isLoading: false),
      onError: (e) =>
          state = state.copyWith(isLoading: false, error: e.toString()),
    );
  }

  void push(List<MapReport> reports) => _ctrl.add(reports);
  void pushError(Object e) => _ctrl.addError(e);
}
