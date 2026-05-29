import '../../domain/entities/map_report.dart';

abstract class MapDatasource {
  Stream<List<MapReport>> watchReportsNear(
    double lat,
    double lng,
    double radiusKm,
  );
}

// TODO: implement using geoflutterfire_plus + Firestore `reports` collection
class MapDatasourceImpl implements MapDatasource {
  @override
  Stream<List<MapReport>> watchReportsNear(
    double lat,
    double lng,
    double radiusKm,
  ) {
    return Stream.value([]);
  }
}
