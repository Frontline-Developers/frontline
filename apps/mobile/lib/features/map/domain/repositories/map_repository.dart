import '../entities/map_report.dart';

abstract class MapRepository {
  Stream<List<MapReport>> watchReportsNear(double lat, double lng, double radiusKm);
}
