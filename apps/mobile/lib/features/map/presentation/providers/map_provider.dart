import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../data/datasources/map_datasource.dart';
import '../../data/datasources/mock_map_datasource.dart';
import '../../data/repositories/map_repository_impl.dart';
import '../../data/services/location_service.dart';
import '../../domain/entities/map_filters.dart';
import '../../domain/entities/map_report.dart';

export '../../data/services/location_service.dart' show LocationService;
export '../../domain/entities/map_filters.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class MapState {
  final List<MapReport> reports;
  final bool isLoading;
  final String? error;
  final MapReport? selectedReport;
  final MapFilters filters;
  final bool showFiltersPanel;
  final LatLng? userLocation;
  final bool showUserMarker;
  final String? locationCity;
  final bool showCityLabels;

  const MapState({
    this.reports = const [],
    this.isLoading = false,
    this.error,
    this.selectedReport,
    this.filters = const MapFilters(),
    this.showFiltersPanel = false,
    this.userLocation,
    this.showUserMarker = false,
    this.locationCity,
    this.showCityLabels = false,
  });

  MapState copyWith({
    List<MapReport>? reports,
    bool? isLoading,
    Object? error = _sentinel,
    Object? selectedReport = _sentinel,
    MapFilters? filters,
    bool? showFiltersPanel,
    Object? userLocation = _sentinel,
    bool? showUserMarker,
    Object? locationCity = _sentinel,
    bool? showCityLabels,
  }) {
    return MapState(
      reports: reports ?? this.reports,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
      selectedReport: selectedReport == _sentinel
          ? this.selectedReport
          : selectedReport as MapReport?,
      filters: filters ?? this.filters,
      showFiltersPanel: showFiltersPanel ?? this.showFiltersPanel,
      userLocation: userLocation == _sentinel
          ? this.userLocation
          : userLocation as LatLng?,
      showUserMarker: showUserMarker ?? this.showUserMarker,
      locationCity: locationCity == _sentinel
          ? this.locationCity
          : locationCity as String?,
      showCityLabels: showCityLabels ?? this.showCityLabels,
    );
  }
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// DI
// ---------------------------------------------------------------------------

// In debug builds, use mock data so the app runs without Firebase.
// Flip to MapDatasourceImpl() when the emulator / prod is ready.
final _mapDatasourceProvider = Provider<MapDatasource>(
  (_) => kDebugMode ? MockMapDatasource() : MapDatasourceImpl(),
);
final _mapRepositoryProvider = Provider(
  (ref) => MapRepositoryImpl(ref.watch(_mapDatasourceProvider)),
);

/// Exported so tests can override with a fake implementation.
final locationServiceProvider = Provider<LocationService>(
  (_) => const LocationServiceImpl(),
);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final mapNotifierProvider = NotifierProvider<MapNotifier, MapState>(
  MapNotifier.new,
);

class MapNotifier extends Notifier<MapState> {
  @override
  MapState build() => const MapState();

  void watchArea(double lat, double lng, double radiusKm) {
    state = state.copyWith(isLoading: true, error: null);
    // Fetch all data; filtering is applied client-side so filter changes are instant.
    ref
        .read(_mapRepositoryProvider)
        .watchReportsNear(
          lat,
          lng,
          radiusKm,
          filters: const MapFilters(timeRange: MapTimeRange.all),
        )
        .listen(
          (reports) =>
              state = state.copyWith(reports: reports, isLoading: false),
          onError: (e) =>
              state = state.copyWith(isLoading: false, error: e.toString()),
        );
  }

  void selectPin(MapReport report) =>
      state = state.copyWith(selectedReport: report);

  void deselectPin() => state = state.copyWith(selectedReport: null);

  void toggleFiltersPanel() =>
      state = state.copyWith(showFiltersPanel: !state.showFiltersPanel);

  void updateFilters(MapFilters filters) =>
      state = state.copyWith(filters: filters);

  void resetFilters() => state = state.copyWith(filters: const MapFilters());

  void toggleCityLabels() =>
      state = state.copyWith(showCityLabels: !state.showCityLabels);

  /// Toggles the "You are here" marker.
  ///
  /// First call: fetches GPS, centers map, shows marker.
  /// Second call: hides marker and clears location — coordinates never leave
  /// the device and are not written to Firestore.
  Future<void> locateMe() async {
    // Toggle off if already showing.
    if (state.showUserMarker) {
      state = state.copyWith(
        showUserMarker: false,
        userLocation: null,
        locationCity: null,
      );
      return;
    }

    final location = await ref
        .read(locationServiceProvider)
        .getCurrentLocation();
    if (location == null) return;

    final city = _nearestCity(location.latitude, location.longitude);
    state = state.copyWith(
      userLocation: location,
      showUserMarker: true,
      locationCity: city,
    );
  }

  /// Returns the name of the nearest known Ukrainian city to [lat]/[lng].
  static String _nearestCity(double lat, double lng) {
    const cities = [
      ('Kyiv', 50.45, 30.52),
      ('Kharkiv', 49.99, 36.23),
      ('Sumy', 50.91, 34.80),
      ('Bakhmut', 48.60, 38.00),
      ('Zaporizhzhia', 47.83, 35.16),
      ('Odesa', 46.48, 30.72),
      ('Mariupol', 47.10, 37.54),
      ('Dnipro', 48.46, 35.04),
      ('Kherson', 46.64, 32.62),
      ('Lviv', 49.84, 24.03),
    ];

    double minDist = double.infinity;
    String nearest = cities.first.$1;
    for (final (name, clat, clng) in cities) {
      final d = (lat - clat) * (lat - clat) + (lng - clng) * (lng - clng);
      if (d < minDist) {
        minDist = d;
        nearest = name;
      }
    }
    return nearest;
  }
}
