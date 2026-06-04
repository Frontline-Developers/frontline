import '../../domain/entities/map_filters.dart';
import '../../domain/entities/map_report.dart';
import '../../domain/repositories/map_repository.dart';
import '../datasources/map_datasource.dart';

class MapRepositoryImpl implements MapRepository {
  final MapDatasource _datasource;
  MapRepositoryImpl(this._datasource);

  @override
  Stream<List<MapReport>> watchReportsNear(
    double lat,
    double lng,
    double radiusKm, {
    MapFilters filters = const MapFilters(),
  }) => _datasource.watchReportsNear(lat, lng, radiusKm, filters: filters);
}
