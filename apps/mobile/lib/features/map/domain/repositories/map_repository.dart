import '../entities/map_filters.dart';
import '../entities/map_report.dart';

abstract class MapRepository {
  Stream<List<MapReport>> watchReportsNear(
    double lat,
    double lng,
    double radiusKm, {
    MapFilters filters,
  });
}
