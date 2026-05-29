import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/map_report.dart';

class MapReportModel {
  final String id;
  final double lat;
  final double lng;
  final String category;
  final String title;
  final DateTime createdAt;

  const MapReportModel({
    required this.id,
    required this.lat,
    required this.lng,
    required this.category,
    required this.title,
    required this.createdAt,
  });

  factory MapReportModel.fromJson(String id, Map<String, dynamic> json) {
    final ts = json['createdAt'] as Timestamp;
    final gp = json['location'] as GeoPoint;
    return MapReportModel(
      id: id,
      lat: gp.latitude,
      lng: gp.longitude,
      category: json['category'] as String,
      title: json['title'] as String,
      createdAt: ts.toDate(),
    );
  }

  MapReport toEntity() => MapReport(
    id: id,
    lat: lat,
    lng: lng,
    category: category,
    title: title,
    createdAt: createdAt,
  );
}
