import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../../domain/entities/map_filters.dart';
import '../../domain/entities/map_report.dart';
import '../models/map_report_model.dart';

abstract class MapDatasource {
  Stream<List<MapReport>> watchReportsNear(
    double lat,
    double lng,
    double radiusKm, {
    MapFilters filters,
  });
}

class MapDatasourceImpl implements MapDatasource {
  final FirebaseFirestore _firestore;

  MapDatasourceImpl([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<MapReport>> watchReportsNear(
    double lat,
    double lng,
    double radiusKm, {
    MapFilters filters = const MapFilters(),
  }) {
    final collectionRef = _firestore.collection('reports');
    return GeoCollectionReference<Map<String, dynamic>>(collectionRef)
        .subscribeWithin(
          center: GeoFirePoint(GeoPoint(lat, lng)),
          radiusInKm: radiusKm,
          // Reports store geohash as a nested map {geohash: string, geopoint: GeoPoint}.
          // geoflutterfire_plus range-queries on this path for the hash string.
          field: 'geohash.geohash',
          geopointFrom: (data) {
            final geo = data['geohash'];
            if (geo is Map<String, dynamic>) return geo['geopoint'] as GeoPoint;
            return data['location'] as GeoPoint;
          },
          strictMode: true,
        )
        .map(
          (snapshots) => snapshots
              .where((s) => s.data() != null)
              .map((s) => MapReportModel.fromJson(s.id, s.data()!).toEntity())
              .where((r) => _matchesFilters(r, filters))
              .toList(),
        );
  }

  bool _matchesFilters(MapReport report, MapFilters filters) {
    if (filters.category != MapCategory.all) {
      if (report.category != filters.category.name) return false;
    }
    if (filters.timeRange != MapTimeRange.all) {
      final cutoff = DateTime.now().subtract(_durationFor(filters.timeRange));
      if (report.createdAt.isBefore(cutoff)) return false;
    }
    return true;
  }

  Duration _durationFor(MapTimeRange range) => switch (range) {
    MapTimeRange.hour => const Duration(hours: 1),
    MapTimeRange.sixHours => const Duration(hours: 6),
    MapTimeRange.day => const Duration(hours: 24),
    MapTimeRange.all => Duration.zero,
  };
}
