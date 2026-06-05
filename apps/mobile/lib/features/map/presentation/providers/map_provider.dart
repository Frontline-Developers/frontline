import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../data/datasources/map_datasource.dart';
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
  final bool isSearching;
  final String? searchError;
  final LatLng? searchedLocation;

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
    this.isSearching = false,
    this.searchError,
    this.searchedLocation,
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
    bool? isSearching,
    Object? searchError = _sentinel,
    Object? searchedLocation = _sentinel,
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
      isSearching: isSearching ?? this.isSearching,
      searchError: searchError == _sentinel
          ? this.searchError
          : searchError as String?,
      searchedLocation: searchedLocation == _sentinel
          ? this.searchedLocation
          : searchedLocation as LatLng?,
    );
  }
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// DI
// ---------------------------------------------------------------------------

final _mapDatasourceProvider = Provider<MapDatasource>(
  (_) => MapDatasourceImpl(),
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
  StreamSubscription<List<MapReport>>? _areaSub;

  @override
  MapState build() {
    ref.onDispose(() => _areaSub?.cancel());
    return const MapState();
  }

  void watchArea(double lat, double lng, double radiusKm) {
    _areaSub?.cancel();
    state = state.copyWith(isLoading: true, error: null);
    // Fetch all data; filtering is applied client-side so filter changes are instant.
    _areaSub = ref
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

  /// Forward-geocodes [address] and sets [searchedLocation] on success.
  /// The map screen reacts to [searchedLocation] to move the camera and
  /// reload reports for the new area.
  Future<void> searchLocation(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(isSearching: true, searchError: null);
    try {
      final location = await ref
          .read(locationServiceProvider)
          .searchLocation(trimmed);
      if (location == null) {
        state = state.copyWith(
          isSearching: false,
          searchError: 'Location not found. Try a different search.',
        );
        return;
      }
      state = state.copyWith(isSearching: false, searchedLocation: location);
    } catch (_) {
      state = state.copyWith(
        isSearching: false,
        searchError: 'Search failed. Please try again.',
      );
    }
  }

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

    final svc = ref.read(locationServiceProvider);
    final location = await svc.getCurrentLocation();
    if (location == null) return;

    // Reverse-geocode to a real city name — works worldwide.
    final rawCity = await svc.getCityName(
      location.latitude,
      location.longitude,
    );
    final city = (rawCity?.isNotEmpty == true) ? rawCity! : 'Your location';

    state = state.copyWith(
      userLocation: location,
      showUserMarker: true,
      locationCity: city,
    );
  }
}
