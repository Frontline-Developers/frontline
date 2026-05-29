import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/map_datasource.dart';
import '../../data/repositories/map_repository_impl.dart';
import '../../domain/entities/map_report.dart';

class MapState {
  final List<MapReport> reports;
  final bool isLoading;
  final String? error;
  const MapState({this.reports = const [], this.isLoading = false, this.error});

  MapState copyWith({List<MapReport>? reports, bool? isLoading, Object? error = _sentinel}) {
    return MapState(
      reports: reports ?? this.reports,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

final _mapDatasourceProvider = Provider((_) => MapDatasourceImpl());
final _mapRepositoryProvider = Provider(
  (ref) => MapRepositoryImpl(ref.watch(_mapDatasourceProvider)),
);

final mapNotifierProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);

class MapNotifier extends Notifier<MapState> {
  @override
  MapState build() => const MapState();

  void watchArea(double lat, double lng, double radiusKm) {
    state = state.copyWith(isLoading: true);
    ref.watch(_mapRepositoryProvider).watchReportsNear(lat, lng, radiusKm).listen(
      (reports) => state = state.copyWith(reports: reports, isLoading: false),
      onError: (e) => state = state.copyWith(isLoading: false, error: e.toString()),
    );
  }
}
