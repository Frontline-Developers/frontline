import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../data/datasources/map_datasource.dart';
import '../../data/repositories/map_repository_impl.dart';
import '../../domain/entities/map_filters.dart';
import '../../domain/entities/map_report.dart';

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
  final bool showCityLabels;

  const MapState({
    this.reports = const [],
    this.isLoading = false,
    this.error,
    this.selectedReport,
    this.filters = const MapFilters(),
    this.showFiltersPanel = false,
    this.userLocation,
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
      showCityLabels: showCityLabels ?? this.showCityLabels,
    );
  }
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// DI
// ---------------------------------------------------------------------------

final _mapDatasourceProvider = Provider((_) => MapDatasourceImpl());
final _mapRepositoryProvider = Provider(
  (ref) => MapRepositoryImpl(ref.watch(_mapDatasourceProvider)),
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
    ref
        .read(_mapRepositoryProvider)
        .watchReportsNear(lat, lng, radiusKm)
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

  void resetFilters() =>
      state = state.copyWith(filters: const MapFilters());

  void toggleCityLabels() =>
      state = state.copyWith(showCityLabels: !state.showCityLabels);
}
