import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/map/domain/entities/map_report.dart';
import 'package:frontline/features/map/presentation/providers/map_provider.dart';
import 'package:frontline/features/map/presentation/screens/map_screen.dart';

// ---------------------------------------------------------------------------
// Fake notifier — extends real MapNotifier so DI wiring stays intact
// ---------------------------------------------------------------------------

class _FakeMapNotifier extends MapNotifier {
  final MapState initialState;
  _FakeMapNotifier({this.initialState = const MapState()});

  @override
  MapState build() => initialState;

  @override
  void selectPin(MapReport report) =>
      state = state.copyWith(selectedReport: report);

  @override
  void deselectPin() => state = state.copyWith(selectedReport: null);

  @override
  void toggleFiltersPanel() =>
      state = state.copyWith(showFiltersPanel: !state.showFiltersPanel);

  @override
  void updateFilters(MapFilters filters) =>
      state = state.copyWith(filters: filters);

  @override
  void resetFilters() => state = state.copyWith(filters: const MapFilters());

  @override
  void toggleCityLabels() =>
      state = state.copyWith(showCityLabels: !state.showCityLabels);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(MapState s) => _wrapWith(_FakeMapNotifier(initialState: s));

Widget _wrapWith(_FakeMapNotifier fake) => ProviderScope(
  overrides: [mapNotifierProvider.overrideWith(() => fake)],
  child: const MaterialApp(home: MapScreen()),
);

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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MapScreen — render', () {
    testWidgets('shows "Live map" title in AppBar', (tester) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.text('Live map'), findsOneWidget);
    });

    testWidgets('shows crosshair icon button in AppBar', (tester) async {
      await tester.pumpWidget(_wrap(const MapState()));
      // gps_not_fixed when marker hidden, gps_fixed when showing
      expect(find.byIcon(Icons.gps_not_fixed), findsOneWidget);
    });

    testWidgets('shows filter icon button in AppBar', (tester) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });
  });

  group('MapScreen — loading state', () {
    testWidgets('shows loading indicator when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const MapState(isLoading: true)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('does not show loading indicator in idle state', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('MapScreen — error state', () {
    testWidgets('shows error message when error is set', (tester) async {
      await tester.pumpWidget(
        _wrap(const MapState(error: 'Failed to load map data')),
      );
      expect(find.text('Failed to load map data'), findsOneWidget);
    });
  });

  group('MapScreen — category chips', () {
    testWidgets('shows All chip', (tester) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('shows Combat / strike chip', (tester) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.text('Combat / strike'), findsOneWidget);
    });

    testWidgets('shows Humanitarian aid chip', (tester) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.text('Humanitarian aid'), findsOneWidget);
    });

    testWidgets('shows Air alert / siren chip', (tester) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.text('Air alert / siren'), findsOneWidget);
    });

    testWidgets('shows Displaced persons chip', (tester) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.text('Displaced persons'), findsOneWidget);
    });

    testWidgets('shows Infrastructure chip', (tester) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.text('Infrastructure'), findsOneWidget);
    });

    testWidgets('shows Other chip', (tester) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('tapping a category chip calls updateFilters', (tester) async {
      final fake = _FakeMapNotifier();
      await tester.pumpWidget(_wrapWith(fake));
      await tester.tap(find.text('Combat / strike'));
      await tester.pump();
      expect(fake.state.filters.category, MapCategory.combat);
    });

    testWidgets('tapping All chip resets category to all', (tester) async {
      final fake = _FakeMapNotifier(
        initialState: const MapState(
          filters: MapFilters(category: MapCategory.combat),
        ),
      );
      await tester.pumpWidget(_wrapWith(fake));
      await tester.tap(find.text('All'));
      await tester.pump();
      expect(fake.state.filters.category, MapCategory.all);
    });
  });

  group('MapScreen — filters panel', () {
    testWidgets('filter panel is hidden by default', (tester) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.text('Last hour'), findsNothing);
    });

    testWidgets('filter panel shows when showFiltersPanel is true', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const MapState(showFiltersPanel: true)));
      expect(find.text('Last hour'), findsOneWidget);
    });

    testWidgets('filter panel shows 6 hours option', (tester) async {
      await tester.pumpWidget(_wrap(const MapState(showFiltersPanel: true)));
      expect(find.text('6 hours'), findsOneWidget);
    });

    testWidgets('filter panel shows 24 hours option', (tester) async {
      await tester.pumpWidget(_wrap(const MapState(showFiltersPanel: true)));
      expect(find.text('24 hours'), findsOneWidget);
    });

    testWidgets('filter panel shows All time option', (tester) async {
      await tester.pumpWidget(_wrap(const MapState(showFiltersPanel: true)));
      expect(find.text('All time'), findsOneWidget);
    });

    testWidgets('filter panel shows Reset button', (tester) async {
      await tester.pumpWidget(_wrap(const MapState(showFiltersPanel: true)));
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('tapping filter icon opens filter panel', (tester) async {
      final fake = _FakeMapNotifier();
      await tester.pumpWidget(_wrapWith(fake));
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pump();
      expect(fake.state.showFiltersPanel, isTrue);
    });

    testWidgets('tapping Reset calls resetFilters', (tester) async {
      final fake = _FakeMapNotifier(
        initialState: const MapState(
          showFiltersPanel: true,
          filters: MapFilters(timeRange: MapTimeRange.hour),
        ),
      );
      await tester.pumpWidget(_wrapWith(fake));
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(fake.state.filters, const MapFilters());
    });

    testWidgets('no filter badge shown (badge removed from design)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.byKey(const Key('filter_active_badge')), findsNothing);
    });
  });

  group('MapScreen — recent activity (no pin selected)', () {
    testWidgets('shows "RECENT ACTIVITY" header when no pin selected', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const MapState()));
      expect(find.text('RECENT ACTIVITY'), findsOneWidget);
    });

    testWidgets('hides "RECENT ACTIVITY" when a pin is selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(MapState(selectedReport: _makeReport('r1'))),
      );
      expect(find.text('RECENT ACTIVITY'), findsNothing);
    });
  });

  group('MapScreen — pin details card', () {
    testWidgets('shows pin details card when report selected', (tester) async {
      await tester.pumpWidget(
        _wrap(MapState(selectedReport: _makeReport('r1'))),
      );
      expect(find.text('Test report r1'), findsOneWidget);
    });

    testWidgets('shows location label in pin details card', (tester) async {
      await tester.pumpWidget(
        _wrap(MapState(selectedReport: _makeReport('r1'))),
      );
      expect(find.text('Kyiv'), findsOneWidget);
    });

    testWidgets('shows See all button in pin details card', (tester) async {
      await tester.pumpWidget(
        _wrap(MapState(selectedReport: _makeReport('r1'))),
      );
      expect(find.text('See all'), findsOneWidget);
    });

    testWidgets('shows Set alert button in pin details card', (tester) async {
      await tester.pumpWidget(
        _wrap(MapState(selectedReport: _makeReport('r1'))),
      );
      expect(find.text('Set alert'), findsOneWidget);
    });

    testWidgets('close button calls deselectPin', (tester) async {
      final fake = _FakeMapNotifier(
        initialState: MapState(selectedReport: _makeReport('r1')),
      );
      await tester.pumpWidget(_wrapWith(fake));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(fake.state.selectedReport, isNull);
    });
  });
}
